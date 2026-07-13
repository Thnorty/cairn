# Proof-of-Completion Todo App — Build Guideline (Flutter)

A mobile app where every task completion is backed by a photo — captured live **or** picked from the gallery — and verified via the **Gemini API**. The proof mechanic is the differentiator, so most of the design effort goes there.

Stack decision: **Flutter** (you have experience, and its camera stack is smoother out of the box). Verification: **Gemini API**. Storage: **local-first**, cloud optional later.

---

## 1. Framework: Flutter

Confirmed. Flutter's `camera` plugin and rendering are smooth out of the box, Dart is pleasant for a greenfield build, and you already know it. The one thing you lose vs. React Native is `react-native-vision-camera`'s real-time on-device frame processors — but since you're doing verification through the **cloud Gemini API** rather than on-device ML, that advantage doesn't apply to your design. Flutter is the right pick.

---

## 2. Data model

Store the recurrence **rule** once; generate occurrences on the fly for the visible window; persist only **completions**. Never materialize future occurrences into rows.

### `tasks`
| field | notes |
|---|---|
| `id` | uuid |
| `title` | |
| `description` | nullable |
| `recurrence_type` | `once` \| `daily` \| `weekly` \| `monthly` |
| `weekly_days` | for `weekly` — chosen weekdays, e.g. `[MO, WE, FR]` |
| `monthly_mode` | `day_of_month` \| `nth_weekday` |
| `month_day` | for `day_of_month` — e.g. 15 |
| `month_nth` / `month_weekday` | for `nth_weekday` — e.g. 3rd + Friday |
| `due_times` | ordered list of times-of-day = the task's **slots**; `[]` untimed, `["08:00"]` single, `["08:00","20:00"]` twice-daily |
| `due_date` | for `once` tasks |
| `start_date` / `end_date` | recurrence bounds (`end_date` nullable) |
| `user_id` | owner = `auth.uid()` (anon or permanent); drives RLS + sync |
| `archived` | user-facing archive (hide without deleting) |
| `deleted_at` | **sync tombstone** (nullable) — so deletes propagate across devices |
| `created_at` / `updated_at` | `updated_at` drives last-write-wins |

### `completions` (one row per proven occurrence)
| field | notes |
|---|---|
| `id` | uuid |
| `task_id` | FK |
| `occurrence_date` | date this completion satisfies |
| `completed_at` | device ts (+ server ts if online) |
| `proof_photo_path` | local path or cloud URL |
| `proof_source` | `camera` \| `gallery` |
| `photo_taken_at` | from asset metadata — for the recency check |
| `verification_status` | `none` \| `pending` \| `verified` \| `rejected` |
| `verification_meta` | JSON from Gemini (confidence, screenshot flag, reason) |
| `slot` | index into the task's `due_times`; `0` for single/untimed tasks |
| `points_awarded` | **metres** earned by this completion (base 10 m + bonuses); rank/altitude = `SUM` of this — see §10 |
| `user_id` | owner = `auth.uid()`; RLS + sync |
| `updated_at` / `deleted_at` | `updated_at` for LWW; `deleted_at` tombstone |
| **unique** | `(task_id, occurrence_date, slot)` |

### Recurrence semantics (confirmed) → RRULE mapping
Use the Dart [`rrule`](https://pub.dev/packages/rrule) package (RFC 5545). Your three recurring types map cleanly:

- **Weekly** — user picks the weekday(s) it repeats on:
  `FREQ=WEEKLY;BYDAY=MO,WE,FR`
- **Monthly · "repeat on the Xth"** — clamp to the last day when the month is shorter (30th → Feb 28/29):
  ⚠️ **This is *not* standard RRULE.** `FREQ=MONTHLY;BYMONTHDAY=30` *skips* February entirely instead of clamping to the 28th. To get your clamping behavior, generate this case yourself: for each month, `day = min(targetDay, lastDayOfMonth)`. In Dart, `DateTime(y, m + 1, 0).day` gives the last day of month `m`. Keep the `rrule` package for weekly and monthly-nth-weekday; hand-roll only monthly-by-day.
- **Monthly · "repeat on the Xth Friday/Saturday…"**:
  `FREQ=MONTHLY;BYDAY=3FR` (3rd Friday) — use `-1FR` for "last Friday."

An occurrence is "done" iff a `completions` row exists for the occurrence.

**No back-filling (confirmed):** a task can only be completed on its own day. This simplifies streak logic — a missed day is just a gap — and the "Today" list shows only today's occurrences with no catch-up affordance. (Guard this on the server too, so a manipulated device clock can't post to a past date.)

**Multiple times per day (native, in MVP):** a task carries an ordered list of `due_times` — its **slots**. Each scheduled date expands into one occurrence per slot, and a completion is keyed `(task_id, occurrence_date, slot)`. This unifies every case on one code path: an untimed task is one slot, a single-timed task is one slot with a time, a twice-daily task is two slots. No "create two tasks" workaround — single-time is just the length-1 case.

### Streaks & multi-slot days
The streak unit is the **day**, not the slot. A scheduled date is **fully complete** iff *every* slot for that date has a completion. So — answering the design question directly — a twice-daily task advances the streak **once** for the day, and only when both slots are done. Doing 1 of 2 slots does **not** count and breaks the streak (all-or-nothing).

Two things to get right:

- **Derive, don't mutate.** Don't increment a stored counter at midnight — mobile OSes throttle/skip background work, so a missed midnight would corrupt the count. Instead compute the streak on read: walk backward over the task's **scheduled dates** (from the recurrence rule), and for each apply the "fully complete?" predicate. Stop at the first incomplete scheduled date. This is stateless, survives the app being closed, and "longest streak" falls out of the same walk.
- **Today is pending, not a miss.** When walking back, the current day doesn't break the streak until it actually ends — even if its slots aren't all done yet. And **non-scheduled dates are skipped, not misses** (a Mon/Wed/Fri task isn't broken by Tuesday). Use the user's **local** date for `occurrence_date` and day boundaries, or streaks will drift by a day across timezones.

Optional later: partial-credit or per-slot streaks if all-or-nothing feels too harsh (did 1 of 2, still lost the streak). All-or-nothing is the simpler, more motivating default for MVP.

---

## 3. The proof feature (camera + gallery + Gemini)

### Capture flow
1. Tap an occurrence → **Complete with proof.**
2. Offer **camera** or **gallery** — both are always available for every task.
3. Read the photo's **capture time** from asset metadata.
4. Compress → save locally → record `proof_source` and `photo_taken_at`.
5. Run the **recency pre-filter**, then **Gemini verification**.
6. Set `verification_status`, write the completion, update streak.

### Layer A — Recency pre-filter (cheap, no API cost)
Reject/flag anything whose capture time is older than a window (e.g. **15 min** before the completion tap; compare against **server time** if online). For gallery picks, read the photo-library asset's `createDateTime` via **`photo_manager`** rather than trusting in-file EXIF — the library's own timestamp is harder to forge casually and less likely to be stripped than EXIF `DateTimeOriginal`.

**Honest limitation:** recency alone can't distinguish "genuinely new photo" from "screenshot I just took of an old image" — both have a recent timestamp. So this layer only cheaply filters obvious stale re-uploads. The real judgment is Layer B.

### Layer B — Gemini verification (the differentiator)
Send the image + task text to Gemini and have it return **structured JSON** in one call, e.g.:

```
{
  "task_shown": true/false,
  "confidence": 0.0–1.0,
  "is_screenshot_or_screen": true/false,   // recorded metadata; does NOT reject on its own
  "reason": "short explanation"
}
```

Map that to `verification_status`: `verified` if `task_shown && confidence ≥ threshold` (default threshold 0.6), else `rejected` (with the reason surfaced to the user).

**Screens: decided 2026-07-14, they never reject on their own.** `is_screenshot_or_screen` is still returned and stored (it is useful signal, and Phase 3 may surface it), but it does not affect the verdict. An earlier design had Gemini also judge whether a screen was the *natural* evidence for the task (a step counter for "walk 10,000 steps", a language-app streak, a bank-transfer confirmation) and reject screens only when it wasn't. That was dropped: it asks the model to guess which proof methods are legitimate for a task, and users have valid ways to prove things via a screen that nobody anticipated. Rejecting an honest proof is worse than accepting a dishonest one here. The accepted cost is a known bypass: screenshot an old photo and its capture time looks fresh, so Layer A's recency filter passes it. That is consistent with this document's own position (see the Reality check below): the goal is friction, not a perfect lock, and no system stops a determined cheater who is willing to stage the shot anyway.

**Security — important:** do **not** embed the Gemini API key in the app binary; it's extractable. Since you already run **Supabase**, put the key in a **Supabase Edge Function** (Deno/TypeScript) that holds the secret, checks the caller's Supabase Auth session, rate-limits, and forwards the image to Gemini — returning only the JSON verdict. The Flutter app never sees the key. Nothing is persisted server-side — the bytes pass through for verification and are discarded.

**Downscale the image you send to Gemini (~150 KB).** Gemini doesn't need full resolution to judge "does this show the task," and the image leaving the Edge Function for Gemini counts as **Supabase egress** — the main meter against your free-tier 5 GB/month. At ~400 KB/image you'd hit that around ~12k verifications/month (~100 daily-active users); at ~150 KB you get 2–3× the headroom, and pay fewer Gemini tokens too. This egress — not photos — is what eventually pushes you to Pro.

**Model:** use **Gemini 3.1 Flash-Lite** — natively multimodal (accepts images), current-gen, and cheap ($0.25 / $1.50 per 1M input/output tokens as of 2026). Avoid Gemini 2.0 Flash/Flash-Lite (shut down June 2026). Set `thinking_level` to minimal/low — this is a classification task, not a reasoning one, so you skip paying for unneeded thinking tokens and cut latency. Cost lands well under $0.001 per verification (~1k input tokens + tiny JSON out), so even a heavy user is cents/month — which is what makes the subscription margins in §9 work.

### Rejections & retries (decided)
Gemini will reject sometimes — false rejections happen, and you're deliberately catching screenshots — so the **rejection state is a required screen** (calm, not alarming; muted clay seal, the AI's reason, the cairn shown unchanged with a ghost outline where the stone would go, a "Retake photo" action). Two rules keep it fair without being gameable:
- **A rejected verification does not consume the free daily cap** — only a *successful* verification counts against the 5/day. Users shouldn't lose budget to the AI's mistakes.
- **Each task allows 3 verification attempts per day (decided).** This bounds Gemini cost from retries and prevents brute-forcing a pass. After the 3rd failed attempt, the task waits until tomorrow ("Attempts reset at midnight"). Premium gets generous headroom here rather than a hard 3 (see §9).

Retries add a few extra Gemini calls beyond the "5 completions" baseline, but at ~150 KB downscaled images the cost is negligible; just note it eats a little more of the free-tier egress headroom.

### Reality check
Every task allows **camera or gallery** — there is no per-task restriction. So the anti-cheat load falls entirely on recency + Gemini for all completions: recency filters lazy reuse of old photos, and Gemini catches semantic mismatch (the photo simply not showing the task). Screens are flagged but never rejected on that basis alone (see Layer B), so screenshotting an old photo to refresh its timestamp is a known, accepted bypass. No system stops a fully determined cheater (staging the shot), and that's fine — the goal is friction, not a perfect lock.

### Storage & privacy — do you back photos up? (decided: no, for MVP)
The photo's only essential job is to pass Gemini verification; what must survive is the **result** (`verification_status` + `verification_meta`), not the image. Keeping the image is only worth it for secondary reasons:
- **Proof journal** (scroll back through your photos) → needs photos kept *locally* only.
- **Cross-device** (same account, two phones) → needs *cloud*.
- **Social / accountability** (a friend views your proof) → needs *cloud*.

**MVP decision: local-only, not synced.** Photos never touch Supabase — sent **transiently** to the Edge Function (which forwards to Gemini and discards), and otherwise kept on-device only. This keeps you on the **free tier**: only the tiny text records sync, which sit well inside the free DB (500 MB) and egress (5 GB) limits. Delete the photo after verification if you don't want the local journal; otherwise keep it on-device.

**Consequence (accepted):** records sync across devices but photos don't — so the journal shows image **placeholders** on any device other than the one that captured them, and a reinstall/new phone loses the images (not the records). Fine for now; the cross-device photo journal is a post-MVP, on-Pro feature.

Regardless: compress to ~1–2 MP, add a retention policy, and make the "photos are sent to Gemini for verification" consent explicit. Local-default is also the strongest privacy posture — these are pictures of someone's home and life.

**If you later put photos in the cloud (post-MVP, on Pro) — what it costs.** Storage is cheap; **egress (bandwidth when photos are viewed/synced) is the real meter.** On Supabase Pro ($25/mo) you get 100 GB storage + 250 GB egress included, then ~$0.021/GB storage and ~$0.09/GB egress. A ~1 MP proof photo is ~300–500 KB, so a user completing ~4/day accumulates ~50 MB/month. Rough scaling: **hundreds of users → ~$25/mo (inside the included quotas); ~1,000 → ~$25–40; ~10,000 → ~$150–250, egress-dominated.** Photos are effectively free once you're on Pro and only matter in the thousands. Keep it down with WebP + thumbnails (full-res on tap); if egress ever dominates, **Cloudflare R2 (zero egress fees, ~$0.015/GB storage)** is a big win, trading Supabase RLS for signed URLs from the Edge Function.

---

## 4. Scheduling & notifications
`flutter_local_notifications` + `timezone` for reminders: per-occurrence for timed one-offs, a daily nudge for recurring tasks.
**iOS gotcha:** iOS caps pending local notifications at **64**. Schedule a rolling window (next 7–14 days) and reschedule on app open — build this in from day one.

---

## 5. Recommended stack (Flutter)

| concern | pick | notes |
|---|---|---|
| Camera capture | `image_picker` (MVP) → `camera` | `image_picker` gives camera **and** gallery in one API; `camera` when you want a custom capture UI/overlay |
| Gallery + asset metadata | `photo_manager` | reliable `createDateTime` for the recency check |
| EXIF (fallback) | `native_exif` / `exif` | if you need in-file `DateTimeOriginal` |
| Local DB | **drift** (SQLite ORM) | typed, relational — fits the completions model; `Isar` if you prefer NoSQL/speed |
| Sync | **hand-rolled delta sync** (pull-changed + push-dirty on foreground) | enough for single-user LWW; PowerSync only if you later need robust offline/multi-user/realtime |
| Recurrence | `rrule` | RFC 5545; handles weekly-by-day and monthly nth-weekday |
| Gemini | called from a **Supabase Edge Function** | never ship the key in-app; the app talks to the function, not Gemini |
| Notifications | `flutter_local_notifications` + `timezone` | rolling-window scheduling |
| State | **Riverpod** | `bloc` if you prefer that structure |
| Image compression | `flutter_image_compress` | on capture/import; WebP + thumbnails to cut egress |
| Backend | **Supabase** (`supabase_flutter`) | anonymous **and** email/password auth, Postgres + RLS for sync, Edge Function for Gemini; Storage only if you back photos up |

---

## 6. Architecture
**Local-first with cross-device sync (in MVP).** Local SQLite is the source of truth on-device; the app is fully usable offline and while anonymous. A background sync mirrors data to Supabase Postgres so a signed-in user sees the same tasks/completions on every device. Network dependencies at MVP: the Edge Function for Gemini verification, plus sync.

**Sync engine — start simple.** For this app a **hand-rolled delta sync** is the right MVP call: on foreground (and periodically), pull rows where `updated_at >` your last-sync cursor, honor `deleted_at` tombstones, and push local dirty rows. It's ~a couple hundred lines you own, no extra vendor, and it's plenty because the data is single-user, tiny, and last-write-wins. Make it *incremental* (a cursor), not a full re-download each open.

**Don't reach for PowerSync yet.** It's excellent but built for a harder problem — offline writes with server-side conflict resolution — and for apps that don't need that it's overhead: you still implement the upload function and conflict handling, plus it's another dependency with its own bill (free up to ~2 GB synced/month, then ~$49/mo, or a free self-hosted Open Edition that's ops work). Adopt it later only if you add multi-user/shared data or want instant cross-device reactivity without maintaining sync code.

**No realtime.** Two devices are rarely active at once for a personal app — foreground/periodic sync is enough. Live change streams add cost and complexity for no felt benefit.

**Conflict resolution:** last-write-wins on server `updated_at`. Adequate here because it's single-user — concurrent edits are rare and completions are append-once.

**What sync forces (reflected in the schema):**
- **`user_id` on every synced row** + Postgres **RLS** so each user reads/writes only their own rows. Without this, one shared DB leaks everyone's data — non-negotiable.
- **Tombstones** (`deleted_at`), not hard deletes, so deletions propagate to other devices.
- **Client-generated UUIDs** (v7 preferred) so offline inserts never collide.
- Verification runs **once** on the capturing device; the result syncs. Other devices trust `verification_status` and don't (can't) re-verify.
- Keep the **local and Postgres schemas in lockstep** — migrations on both sides together.
- Realtime is overkill; sync on foreground/periodic. Still enforce "no back-fill" and completion-uniqueness server-side.

### Accounts: anonymous by default, account unlocks sync
Anonymous auth on first launch (no login screen, no PII) — the app runs fully local/offline this way, and it also gates the Gemini Edge Function against cost abuse. **Signing up (email/password) is what turns on cross-device sync**, because anonymous identity is per-install. Assign `user_id = auth.uid()` from the very first anonymous session; Supabase **preserves that id when you upgrade the anonymous user to permanent**, so existing local rows already carry the right owner and the upgrade needs no re-owning.

One merge case to decide: if someone used the app anonymously on device B, then signs into an account created on device A, device B already holds local anon data. Simplest MVP rule — a fresh install has nothing to merge (just pull A's data down); if local data exists at sign-in, either merge (push then pull) or prompt keep/discard. Social features stay future.

### Staying on the Supabase free tier (the MVP target)
Free tier = 500 MB DB, 1 GB file storage, 5 GB egress, 50k MAUs — enough for development and a small tester group with this config: **records sync, photos stay local (not uploaded), no Storage, no realtime.** Two caveats make free tier a dev/small-test tier, not a launch tier: projects **pause after ~1 week of inactivity**, and exceeding a quota (e.g. egress) makes the service **return 402 until you upgrade or the cycle resets**. Your main free-tier meter is Edge Function egress from the Gemini round-trip — downscale the verification image (~150 KB, see §3). Move to **Pro ($25/mo)** when you have real users; only then is photo sync / the cross-device journal worth turning on (nearly free within Pro's included quotas).

---

## 7. Scope
**MVP:** task CRUD; four recurrence types with the confirmed weekly/monthly UX; multi-slot (multi-time) tasks; camera **and** gallery proof; recency pre-filter; Gemini verification via proxy; local storage; Today view; reminders; day-level streaks; per-task cairns + trail-of-cairns history; **cumulative rank/points (§10)**; **anonymous use with optional email/password account; cross-device sync of records (photos stay local)**.
**Post-MVP:** cloud photo backup (premium, §9); advanced insights, widgets + cosmetics (premium, §9); **competitive weekly leagues (§10)**; accountability/social layer.

---

## 8. Suggested build order
1. Schema (with `user_id`, `updated_at`, `deleted_at`, UUID PKs) + occurrence generation — from the recurrence rule get scheduled dates, then expand each into one occurrence **per slot** (`due_times`). Verify Today renders daily/weekly/monthly(both modes)/once and multi-slot correctly. drift over SQLite.
2. Task CRUD UI incl. the weekly-day picker, monthly mode toggle ("Xth" vs "Xth weekday"), and a times-of-day editor (add/remove slots).
3. Proof capture: camera + gallery via `image_picker`, read `photo_taken_at`, compress, save, write completion for the chosen `(date, slot)`.
4. Recency pre-filter.
5. Gemini proxy + structured-JSON verification; wire `verification_status`.
6. Local notifications with rolling window (one per slot).
7. Streaks (derived: walk back over scheduled dates, a date counts only if all slots done) + Today polish.
8. Auth + sync: anonymous session on launch (assign `user_id`), Postgres tables + RLS, hand-rolled delta sync (cursor pull + dirty push on foreground), email/password sign-up with anonymous→permanent upgrade. Test edit/delete propagation and the second-device merge case.

---

## 9. Monetization
Marginal cost is tiny and concentrated in the AI verification (~cents/user/month), so the natural fit is **freemium subscription**, with the paywall drawn around your differentiator-and-cost: AI verification, plus sync and the cloud journal.

**Free** — one coherent limiter, no task cap:
- **Unlimited tasks** (any recurrence, multi-slot). Task count costs nothing to store, so there's no reason to cap it — capping both tasks and verifications is what creates the "5 tasks but 3 checks" contradiction.
- **5 AI-verified completions/day (decided)**, shared across all tasks (each completion = 1, so a twice-daily task uses 2). **Every completion is AI-verified — there is no honor-system fallback**, so this cap is also the hard ceiling on how many tasks a free user can complete in a day. Only *successful* verifications count against the 5; a rejected check doesn't burn the budget, but each task allows **3 attempts/day** (see §3).
- **Full trail, all past stones, streaks, rank ladder — forever.** Plus basic stats, reminders, all recurrence types, and **record sync** (tasks/completions/streaks/rank follow you to a new phone; only the photo archive is premium).
- Basic streaks, local-only, single device, anonymous (no account).

**Premium (~$3.99/mo or ~$27.99/yr, 7-day trial).** Governing principle: **charge for capacity and additions, never for access to what the user already built.**

1. **Unlimited AI proofs.** The honest gate — the only thing with a real per-use cost (the Gemini call). Everything below is gravy.
2. **Cloud photo backup.** The expensive half of sync — ~400 KB/proof × 5/day ≈ ~50 MB/user/month, so storage+egress is real money at scale. Gating it is cost-justified, not artificial. Premium users get their whole proof archive backed up and restorable on a new phone.
3. **Advanced insights.** *New* views, not restored access: consistency curves, best/worst time-of-day, per-habit comparison, rank projections, "your strongest month."
4. **Extra retries.** Free gets 3 attempts/task/day; premium gets generous headroom — this is the exact moment a committed user feels friction.
5. **Home-screen widgets.** Your cairn on the home screen, tap-to-prove. Cheap to build, high perceived value, and genuinely useful as a daily nudge.
6. **Cosmetics.** Stone textures, cairn styles, alt app icons, themes. Zero marginal cost, pure margin, and thematically natural with the rank ladder (unlock slate, granite, basalt…).

**Never gate:** habit count, existing history, streaks, rank, basic stats, or **record sync**. Record sync (tasks, completions, streaks, rank) is tiny text rows — pennies — so it stays **free**: a free user's stones and rank follow them to a new phone, only the *photo archive* is the premium safety net. Keeping record sync free also means **no local-only mode to build**, removing the one gate that carried real engineering cost. Gating history or streaks would turn the "build your cairn" metaphor into a hostage situation — the fastest way to poison word of mouth for an app whose whole hook is emotional investment in a stack of stones.

**Not a paywall anchor: a watch app.** Cairn's core action is taking a photo, and the Apple Watch has no camera — a watch app fundamentally cannot perform the central action, while costing a separate native platform build (Flutter's watch story is weak). High cost, weak value. Build it someday as a flex if you like, but don't hang the subscription on it; widgets are the better cheap/high-value gate.

**Consequence to watch:** with history free, the 5/day cap is the *only* thing free users feel, so it carries all the conversion weight. That makes it the highest-leverage number in the business. Start generous, watch where people actually hit the wall, tighten later — it's far easier to reduce a limit quietly than to claw back a feature you already gave away.

**Why 5/day (and the trade-off):** a casual user with 3–5 daily habits is covered; a power user (6+ habits) hits the wall daily, which drives conversion. With no honor-system fallback the cap bites harder — a 5-habit user has no slack for a twice-daily task or a new one — so treat 5 as the aggressive end of the dial and nudge up (6–8) if you want breathing room. Cost-wise it's cheap either way: a maxed free user is ~22 MB egress/month + ~$0.08 Gemini, so ~5/day supports roughly **~200 maxed free users** before egress pushes you to Pro.

Setup notes:
- **RevenueCat** (Flutter SDK) to manage IAP/subscriptions, receipt validation, entitlements, paywalls — don't hand-roll it.
- **Platform cut:** Apple/Google take 30%, or 15% via their small-business programs (under ~$1M/yr). Price with that in mind.
- **7-day free trial** of premium; lead with **annual** (discounted) for LTV.
- Secondary options: a one-time "unlock" IAP for **cosmetics only** (stone textures, cairn styles, alt icons) as a non-subscriber path, keeping AI/sync/insights on subscription; or **rewarded ads** ("watch an ad for +1 proof today"). Keep subscription primary — a pure one-time purchase is risky when AI and sync are ongoing costs. Don't put stats or history behind either.
- **Rank fairness** (see §10): every completion is AI-verified, and premium users can complete more per day than the free cap allows — fine for personal cumulative rank, but for competitive weekly leagues cap weekly league points at a free-reachable level (or separate free/premium leagues) so rank isn't pay-to-win.

---

## 10. Progression & rank
"Duolingo-like" bundles two systems; split them by phase, both running on one points score.

**Points = metres (the score).** Separate from the stone count — stones stay the per-task streak visual; **metres** are the global progression currency, so you can reward more than raw completion count. Every completion is AI-verified (no honor-system), and each earns: a flat **base of 10 m**, a **per-task streak bonus** (escalating with *that task's* current streak, capped — this rewards keeping several habits alive at once rather than funnelling everything into one), and a **perfect-day bonus** when all of a day's scheduled tasks are done. Store the total on the completion (`points_awarded`, in metres); this keeps it auditable, syncing for free, and consistent with "derive, don't mutate."

**Cumulative rank (MVP).** **Points *are* metres** — there's no conversion layer, no second number to drift. `points_awarded` literally means metres climbed, and rank = `SUM(points_awarded)` across the user's completions, displayed as altitude gained ("1,240 m gained"). Tiers climb the trail:

| Tier | Altitude |
|---|---|
| Pebble | 0 m |
| Cairn | 150 m |
| Ridge | 450 m |
| Crag | 1,100 m |
| Bluff | 2,400 m |
| Peak | 5,000 m |
| Summit | 8,849 m |

Summit is Everest — a real-world ceiling people recognise, and it keeps the metaphor honest. At the 10 m base rate and ~3 habits/day (~1,000 m/month), Summit is roughly a year of consistent use: a genuine long climb, which is what a lifetime rank should be. Rank **never decreases** — kind and motivating. Works locally for a single/anonymous user from day one. Tune the thresholds once you see real earning rates.

**Weekly leagues (post-MVP).** Duolingo's competitive layer: place users in cohorts, rank by **this week's** points (`SUM(points_awarded)` where `completed_at` in the current week), promote/demote weekly. This is a *social* feature — needs a backend, matchmaking, and enough real users (empty leagues feel dead), so it waits until there's a user base. Leagues supply the recency pressure that cumulative rank deliberately omits.

**Guardrails.** Every completion is AI-verified, so the free daily cap is also the ceiling on completions (and thus daily points) for free users — no honor-system fallback. Premium users can complete more per day: fine for personal cumulative rank, but for competitive weekly leagues cap weekly points at a free-reachable level (or separate free/premium leagues) so rank isn't pay-to-win. For premium/unlimited users, also add a soft daily points cap or diminishing returns so nobody farms rank by spamming trivial tasks.

---

## Key risks
- **Gallery + recency is weak alone** — Gemini (with screenshot detection) carries verification; recency is just a cheap pre-filter.
- **API key leakage** — Gemini key lives in the Supabase Edge Function, never in the app.
- **Photo storage bloat** — compression + retention from day one.
- **Privacy** — personal images sent to Gemini; explicit consent, local-default storage.
- **iOS 64-notification cap** — rolling window, not bulk scheduling.
- **Monthly clamping is custom** — `rrule` won't clamp `BYMONTHDAY=30` to Feb 28 (it skips the month); generate monthly-by-day yourself with `min(day, lastDayOfMonth)`.
- **Missing RLS = data leak** — every synced table needs `user_id` + row-level security before it holds real users' data.
- **Hard deletes don't sync** — use `deleted_at` tombstones so deletions propagate.
- **Synced records without synced photos** — cross-device journal shows image placeholders unless you add Storage; decide deliberately.
