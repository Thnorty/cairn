// Cairn's in-app account deletion Edge Function.
// Permanently deletes the calling user's account and all of their synced cloud data.
// Deployed as a Supabase Edge Function (Deno).
//
// Auth & Security:
// supabase/config.toml sets `[functions.delete-account].verify_jwt = true`,
// so the Supabase gateway rejects any request without a valid JWT with 401
// before this code ever runs.
//
// The caller's identity MUST come from their own JWT, never from a request body
// or parameter. This function resolves the caller ID by constructing an anon-key
// Supabase client forwarding the caller's `Authorization` header and calling
// `auth.getUser()`. If token verification fails or no user is returned, a 401
// is returned immediately.
//
// Service-Role Privileges & Justification:
// Unlike `verify-proof` (which holds no service-role access), `delete-account`
// constructs a second Supabase client using `SUPABASE_SERVICE_ROLE_KEY`.
// This elevated access is required for two reasons:
// 1. Deleting an `auth.users` row requires the Supabase admin API (`auth.admin.deleteUser`).
// 2. The public sync tables (`tasks`, `completions`, `verification_attempts`) grant
//    authenticated clients SELECT, INSERT, and UPDATE permissions only (RLS by design).
//    Clients cannot execute DELETE queries directly.
//
// Crucially, the service-role client is instantiated and used ONLY AFTER the caller's
// identity (`userId`) has been authenticated and established from their JWT via
// `auth.getUser()`. Every single SQL deletion query and administrative call executed
// by the service-role client is strictly scoped to that one resolved `userId`.
//
// Deletion Order (No Cascades on Sync Tables):
// The sync tables (`completions`, `verification_attempts`, `tasks`) have `user_id`
// columns with no foreign key relationship to `auth.users` and no `ON DELETE CASCADE`.
// To avoid orphaned database rows, data is hard-deleted explicitly in the following order:
// 1. Delete rows from `public.completions` where `user_id = userId`.
// 2. Delete rows from `public.verification_attempts` where `user_id = userId`.
// 3. Delete rows from `public.tasks` where `user_id = userId`.
// 4. Delete rows from `public.verify_quota_counters` where `bucket = 'user:' || userId`.
// 5. Delete the auth user via `auth.admin.deleteUser(userId)`.
//
// Deleting sync rows before the auth user ensures that if any table deletion fails,
// the operation fails part-way with the account still usable and retryable.
// A 200 status is returned only when all steps succeed cleanly.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

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

  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error(
      'delete-account misconfigured: SUPABASE_URL, SUPABASE_ANON_KEY, or SUPABASE_SERVICE_ROLE_KEY not set',
    );
    return jsonResponse({ error: 'server misconfigured' }, 500);
  }

  // Forward caller's JWT to resolve identity with anon client.
  const supabaseUserClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await supabaseUserClient.auth.getUser();
  if (userError || !userData?.user) {
    return jsonResponse({ error: 'invalid or expired token' }, 401);
  }

  const userId = userData.user.id;

  // Construct service-role admin client ONLY after identity is resolved.
  const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 1. Hard-delete completions for caller
  const { error: completionsError } = await supabaseAdmin
    .from('completions')
    .delete()
    .eq('user_id', userId);

  if (completionsError) {
    console.error('delete-account: failed to delete completions:', completionsError);
    return jsonResponse({ error: 'failed to delete user data' }, 500);
  }

  // 2. Hard-delete verification attempts for caller
  const { error: attemptsError } = await supabaseAdmin
    .from('verification_attempts')
    .delete()
    .eq('user_id', userId);

  if (attemptsError) {
    console.error('delete-account: failed to delete verification_attempts:', attemptsError);
    return jsonResponse({ error: 'failed to delete user data' }, 500);
  }

  // 3. Hard-delete tasks for caller
  const { error: tasksError } = await supabaseAdmin
    .from('tasks')
    .delete()
    .eq('user_id', userId);

  if (tasksError) {
    console.error('delete-account: failed to delete tasks:', tasksError);
    return jsonResponse({ error: 'failed to delete user data' }, 500);
  }

  // 4. Hard-delete verify quota counter bucket for caller
  const { error: quotaError } = await supabaseAdmin
    .from('verify_quota_counters')
    .delete()
    .eq('bucket', `user:${userId}`);

  if (quotaError) {
    console.error('delete-account: failed to delete verify_quota_counters:', quotaError);
    return jsonResponse({ error: 'failed to delete user data' }, 500);
  }

  // 5. Delete auth user last
  const { error: authError } = await supabaseAdmin.auth.admin.deleteUser(userId);

  if (authError) {
    console.error('delete-account: failed to delete auth user:', authError);
    return jsonResponse({ error: 'failed to delete user account' }, 500);
  }

  return jsonResponse({ success: true }, 200);
});
