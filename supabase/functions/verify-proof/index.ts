// Cairn's Phase 2b proof verifier. Judges whether a submitted photo shows a
// given task being done, using Gemini. Deployed as a Supabase Edge Function
// (Deno) so the Gemini API key never ships in the app binary: it is read
// only from an environment secret here, via Deno.env.get, and it is never
// logged and never returned to the caller.
//
// The image is never persisted: its bytes pass through this function
// (base64 in the request body) and are discarded once the Gemini call
// returns. Nothing here writes to any database table (Phase 2b adds none;
// Phase 4 owns the Postgres schema).
//
// Auth: supabase/config.toml sets `[functions.verify-proof].verify_jwt =
// true`, so the Supabase gateway rejects any request without a valid JWT
// with 401 before this code ever runs. Anonymous users are legitimate
// callers (that is the whole point of Phase 2b's anonymous auth): what
// matters is a *valid* session JWT, not a non-anonymous one. This handler
// additionally calls `auth.getUser()` itself, both as defense in depth and
// to recover the caller's user id for rate limiting below.
//
// Rate limiting: best-effort, in-memory, per Supabase Function *instance*.
// This is NOT durable - it resets on cold start, is not shared across
// concurrently warm instances, and is lost entirely on a redeploy. It is a
// soft speed bump against a single client hammering this endpoint, not a
// real limit. Phase 4 replaces it with a table-backed limiter once Postgres
// tables exist (Phase 2b deliberately creates none).

import { createClient } from 'jsr:@supabase/supabase-js@2';

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');
const GEMINI_MODEL = Deno.env.get('GEMINI_MODEL') ?? 'gemini-3.1-flash-lite';
const GEMINI_ENDPOINT =
  Deno.env.get('GEMINI_ENDPOINT') ??
  'https://generativelanguage.googleapis.com/v1beta/interactions';

// Used only to construct a client that forwards the caller's own JWT, so
// `auth.getUser()` resolves against the *caller's* session, not this
// function's own privileges. Not the service-role key: this function never
// needs (and must never hold) elevated database access.
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

// --- best-effort, per-instance rate limit (see file header) ---------------
const RATE_LIMIT_MAX_PER_WINDOW = 20;
const RATE_LIMIT_WINDOW_MS = 60_000;
const rateLimitState = new Map<string, number[]>();

function isRateLimited(userId: string): boolean {
  const now = Date.now();
  const recent = (rateLimitState.get(userId) ?? []).filter(
    (t) => now - t < RATE_LIMIT_WINDOW_MS,
  );
  if (recent.length >= RATE_LIMIT_MAX_PER_WINDOW) {
    rateLimitState.set(userId, recent);
    return true;
  }
  recent.push(now);
  rateLimitState.set(userId, recent);
  return false;
}

// --- CORS ------------------------------------------------------------------
const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

// A few KB is plenty to diagnose a Gemini response shape mismatch without
// risking a flooded log. Only ever applied to the Gemini *response* body
// (error text or JSON), never to the outgoing request, so it can never
// contain the submitted image or GEMINI_API_KEY - neither of which appears
// in a Gemini response in the first place.
const MAX_LOGGED_RESPONSE_CHARS = 4000;

function truncateForLogging(text: string): string {
  return text.length > MAX_LOGGED_RESPONSE_CHARS
    ? `${text.slice(0, MAX_LOGGED_RESPONSE_CHARS)}... [truncated, ${text.length} chars total]`
    : text;
}

// ============================================================================
// PROMPT - human review requested before this ships (see the work order).
// Keep this text and the comment above it together so a reviewer sees both.
// Instructs Gemini to judge whether the photo shows the task done, report a
// confidence, flag screenshots/photos-of-screens, and - the key anti-cheat
// design point - judge from the task text alone whether a screen is the
// *natural* evidence for this specific task (a step counter, a
// language-learning app), so tasks whose natural evidence lives on a screen
// stay verifiable while a screenshotted old photo doesn't.
// ============================================================================
const SYSTEM_PROMPT = `You are a strict but fair verifier for a habit-tracking app called Cairn. Every time a user completes a personal task, they submit one photo as proof, and you decide whether that photo is genuine evidence the task was actually done.

You will receive:
- The task's title and (optional) description.
- One photo the user just submitted.

Respond with ONLY a JSON object matching the required schema. Do not include any commentary, markdown, or text outside the JSON object.

Fill in these fields:

- task_shown (boolean): true if the photo plausibly shows the described task being done, or its direct, freshly-produced result (e.g. a made bed for "make my bed", a plate of food for "cook dinner", a sink full of clean dishes for "do the dishes"). false if the photo is unrelated to the task, shows a different activity, or shows no evidence the task was done.

- confidence (number, 0.0 to 1.0): how confident you are in your task_shown judgment. Use the full range; do not default to extreme values.

- is_screenshot_or_screen (boolean): true if the image is a screenshot, or a photograph of a screen, monitor, phone, or TV displaying content, rather than a photo of the physical world.

- screen_is_plausible_proof (boolean): only meaningful when is_screenshot_or_screen is true (set it to false whenever is_screenshot_or_screen is false). Judge, from the task's title and description alone, whether a screen is the NATURAL, expected form of evidence for this specific task. Set true for tasks like a step count or workout summary for a walking/running/exercise task, a lesson-complete screen for a language-learning task, a meditation app's session summary for a meditation task, or a banking/budgeting app screenshot for a "check my balance" or "pay a bill" task. Set false for tasks whose natural evidence is something physical in the real world (e.g. "clean my room", "go to the gym", "cook dinner"), even if the submitted photo happens to be a screenshot: a screenshot is not credible evidence for those.

- reason (string, one sentence): a short, human-readable explanation of your task_shown and is_screenshot_or_screen judgments. Write it so it could be shown directly to the user if their proof is rejected.

Be fair and not overly strict: most submissions are honest attempts, and an imperfect photo (bad lighting, an odd angle, a partial view) that still plausibly shows the task done should pass. Reserve a low confidence or task_shown: false for photos that are genuinely unrelated to the task, show no evidence at all, or use a screen where a screen is not plausible evidence for that task.`;

function buildPrompt(taskTitle: string, taskDescription: string | null): string {
  return `${SYSTEM_PROMPT}

Task title: ${taskTitle}
Task description: ${taskDescription ?? '(none provided)'}`;
}

// --- verdict shape + schema --------------------------------------------------
interface Verdict {
  task_shown: boolean;
  confidence: number;
  is_screenshot_or_screen: boolean;
  screen_is_plausible_proof: boolean;
  reason: string;
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    task_shown: { type: 'boolean' },
    confidence: { type: 'number' },
    is_screenshot_or_screen: { type: 'boolean' },
    screen_is_plausible_proof: { type: 'boolean' },
    reason: { type: 'string' },
  },
  required: [
    'task_shown',
    'confidence',
    'is_screenshot_or_screen',
    'screen_is_plausible_proof',
    'reason',
  ],
};

function isVerdictShape(value: unknown): value is Verdict {
  if (typeof value !== 'object' || value === null) return false;
  const v = value as Record<string, unknown>;
  return (
    typeof v.task_shown === 'boolean' &&
    typeof v.confidence === 'number' &&
    typeof v.is_screenshot_or_screen === 'boolean' &&
    typeof v.screen_is_plausible_proof === 'boolean' &&
    typeof v.reason === 'string'
  );
}

/// Strips a surrounding markdown code fence (```json ... ``` or ``` ... ```)
/// from a text blob, if present. Gemini is instructed via response_format to
/// return bare JSON, but a text part may still arrive fenced, so this runs
/// ahead of every JSON.parse attempt below.
function stripCodeFence(text: string): string {
  const trimmed = text.trim();
  const fenceMatch = trimmed.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  return fenceMatch ? fenceMatch[1].trim() : trimmed;
}

/// Parses a text blob as the verdict JSON, tolerating a surrounding code
/// fence. Returns null (never throws) on anything that isn't valid JSON
/// matching the verdict shape.
function tryParseVerdictText(text: string): Verdict | null {
  try {
    const parsed = JSON.parse(stripCodeFence(text));
    return isVerdictShape(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

/// Shape 1: the `interactions` API this function was originally written
/// against: `{ steps: [ { type: "model_output", content: [ { type: "text",
/// text: "<json string>" } ] } ] }`.
function extractFromInteractionsShape(geminiJson: unknown): Verdict | null {
  if (typeof geminiJson !== 'object' || geminiJson === null) return null;
  const steps = (geminiJson as Record<string, unknown>).steps;
  if (!Array.isArray(steps)) return null;

  for (const step of steps) {
    if (typeof step !== 'object' || step === null) continue;
    if ((step as Record<string, unknown>).type !== 'model_output') continue;

    const content = (step as Record<string, unknown>).content;
    if (!Array.isArray(content)) continue;

    for (const part of content) {
      if (typeof part !== 'object' || part === null) continue;
      const p = part as Record<string, unknown>;
      if (p.type !== 'text' || typeof p.text !== 'string') continue;
      const verdict = tryParseVerdictText(p.text);
      if (verdict) return verdict;
    }
  }
  return null;
}

/// Shape 2: a top-level convenience field (e.g. `output_text`) holding the
/// verdict JSON as a string, offered by some Gemini API surfaces.
function extractFromOutputTextField(geminiJson: unknown): Verdict | null {
  if (typeof geminiJson !== 'object' || geminiJson === null) return null;
  const outputText = (geminiJson as Record<string, unknown>).output_text;
  if (typeof outputText !== 'string') return null;
  return tryParseVerdictText(outputText);
}

/// Shape 3: the classic `generateContent` shape,
/// `candidates[0].content.parts[*].text`. This is the one that matters most:
/// GEMINI_ENDPOINT is an env override, and this makes pointing it at
/// `.../v1beta/models/<model>:generateContent` actually work instead of
/// silently 502-ing.
function extractFromGenerateContentShape(geminiJson: unknown): Verdict | null {
  if (typeof geminiJson !== 'object' || geminiJson === null) return null;
  const candidates = (geminiJson as Record<string, unknown>).candidates;
  if (!Array.isArray(candidates)) return null;

  for (const candidate of candidates) {
    if (typeof candidate !== 'object' || candidate === null) continue;
    const content = (candidate as Record<string, unknown>).content;
    if (typeof content !== 'object' || content === null) continue;
    const parts = (content as Record<string, unknown>).parts;
    if (!Array.isArray(parts)) continue;

    for (const part of parts) {
      if (typeof part !== 'object' || part === null) continue;
      const text = (part as Record<string, unknown>).text;
      if (typeof text !== 'string') continue;
      const verdict = tryParseVerdictText(text);
      if (verdict) return verdict;
    }
  }
  return null;
}

/// Last resort: walk the whole response recursively, looking for either an
/// object that already satisfies the verdict shape directly, or a string
/// that parses into one. Bounded by a visited-node cap so a pathological
/// response can't run away; cycle-guarded via `seen` even though JSON
/// responses can't normally contain cycles.
function extractByRecursiveWalk(geminiJson: unknown): Verdict | null {
  const seen = new Set<unknown>();
  const MAX_VISITED_NODES = 5000;
  let visitedNodes = 0;

  function walk(value: unknown): Verdict | null {
    if (visitedNodes++ > MAX_VISITED_NODES) return null;
    if (value === null || value === undefined) return null;

    if (typeof value === 'string') return tryParseVerdictText(value);
    if (typeof value !== 'object') return null;
    if (seen.has(value)) return null;
    seen.add(value);

    if (isVerdictShape(value)) return value;

    if (Array.isArray(value)) {
      for (const item of value) {
        const found = walk(item);
        if (found) return found;
      }
      return null;
    }

    for (const key of Object.keys(value as Record<string, unknown>)) {
      const found = walk((value as Record<string, unknown>)[key]);
      if (found) return found;
    }
    return null;
  }

  return walk(geminiJson);
}

/// Pulls the verdict JSON out of a Gemini response, trying the plausible
/// response shapes in order and returning the first one that yields a valid
/// verdict. This function is about to be exercised against a live API for
/// the first time, so it degrades informatively across shape variance
/// instead of uniformly 502-ing the moment a field name differs:
///   1. The `interactions` shape this function was originally written for.
///   2. A top-level convenience string field (e.g. `output_text`).
///   3. The classic `generateContent` shape (`candidates[].content.parts[]`).
///   4. A recursive walk for any string or object that satisfies the
///      verdict shape.
/// Returns null on total failure, which the caller maps to a 502
/// (VerifierUnavailable on the client). A verdict is never fabricated.
function extractVerdict(geminiJson: unknown): Verdict | null {
  return (
    extractFromInteractionsShape(geminiJson) ??
    extractFromOutputTextField(geminiJson) ??
    extractFromGenerateContentShape(geminiJson) ??
    extractByRecursiveWalk(geminiJson)
  );
}

// --- request body -------------------------------------------------------
interface VerifyRequestBody {
  task_title?: unknown;
  task_description?: unknown;
  image_base64?: unknown;
  mime_type?: unknown;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'method not allowed' }, 405);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'missing Authorization header' }, 401);
  }

  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    console.error(
      'verify-proof misconfigured: SUPABASE_URL/SUPABASE_ANON_KEY not set',
    );
    return jsonResponse({ error: 'server misconfigured' }, 500);
  }

  // Forwards the caller's own JWT so getUser() resolves against *their*
  // session (see the SUPABASE_ANON_KEY comment above).
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user) {
    return jsonResponse({ error: 'invalid or expired token' }, 401);
  }
  const userId = userData.user.id;

  if (isRateLimited(userId)) {
    return jsonResponse({ error: 'rate limit exceeded, try again shortly' }, 429);
  }

  if (!GEMINI_API_KEY) {
    console.error('verify-proof misconfigured: GEMINI_API_KEY not set');
    return jsonResponse({ error: 'server misconfigured' }, 500);
  }

  let body: VerifyRequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'invalid JSON body' }, 400);
  }

  const taskTitle = typeof body.task_title === 'string' ? body.task_title : null;
  const taskDescription =
    typeof body.task_description === 'string' ? body.task_description : null;
  const imageBase64 =
    typeof body.image_base64 === 'string' ? body.image_base64 : null;
  const mimeType =
    typeof body.mime_type === 'string' ? body.mime_type : 'image/jpeg';

  if (!taskTitle || !imageBase64) {
    return jsonResponse(
      { error: 'task_title and image_base64 are required' },
      400,
    );
  }

  const geminiRequestBody = {
    model: GEMINI_MODEL,
    input: [
      { type: 'text', text: buildPrompt(taskTitle, taskDescription) },
      { type: 'image', mime_type: mimeType, data: imageBase64 },
    ],
    response_format: {
      type: 'text',
      mime_type: 'application/json',
      schema: VERDICT_SCHEMA,
    },
    generation_config: { thinking_level: 'minimal' },
  };

  let geminiResponse: Response;
  try {
    geminiResponse = await fetch(GEMINI_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': GEMINI_API_KEY,
      },
      body: JSON.stringify(geminiRequestBody),
    });
  } catch (err) {
    console.error('verify-proof: network error calling Gemini:', err);
    return jsonResponse({ error: 'verifier unavailable' }, 502);
  }

  if (!geminiResponse.ok) {
    const errorBody = await geminiResponse.text().catch(() => '<unreadable body>');
    console.error(
      `verify-proof: Gemini returned ${geminiResponse.status}: ${truncateForLogging(errorBody)}`,
    );
    return jsonResponse({ error: 'verifier unavailable' }, 502);
  }

  let geminiJson: unknown;
  try {
    geminiJson = await geminiResponse.json();
  } catch (err) {
    console.error('verify-proof: Gemini response body was not valid JSON:', err);
    return jsonResponse({ error: 'verifier unavailable' }, 502);
  }

  const verdict = extractVerdict(geminiJson);
  if (!verdict) {
    console.error(
      'verify-proof: could not extract a verdict from the Gemini response:',
      truncateForLogging(JSON.stringify(geminiJson)),
    );
    return jsonResponse({ error: 'verifier unavailable' }, 502);
  }

  return jsonResponse(verdict, 200);
});
