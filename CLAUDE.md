# Cairn — architecture rules

Cairn is a Flutter habit-tracking app where every task completion is proven with an AI-verified photo. Users "climb" by earning metres per completion and progress through ranks.

## UI designs are canonical — do not invent UI

The `design/` folder contains the canonical UI designs as `.dc.html` files (Today/Home, camera capture & verify flow, Trail, New Habit variants, Stats, Profile, Premium, onboarding, empty states, failure states, daily limit). **All real screens must be implemented from those files** — palette, typography (Zilla Slab + Work Sans), pebble shapes, and exact copy come from them. No screen designs may be invented. The only exception is the Phase 1 debug screen, which is deliberately ugly/minimal and does not use the designs.

## Phase plan (plan of record — update this file when a phase completes or the plan changes)

Full rationale for every decision below lives in `docs/GUIDELINE.md`. That document is the source of truth; this is the sequencing. Phases may be re-planned — if you change them, rewrite this section so future sessions inherit the current map. Mark phases complete as you finish them, and record any decisions made along the way.

- **Phase 1 — Data foundation. ✅ COMPLETE.** drift database, occurrence generation, streaks, metres/rank, repositories, `LocalDate`/`Clock` abstractions, minimal debug screen. 55 tests green. Not yet run on a physical device.

- **Phase 2 — Proof pipeline.** Camera *and* gallery capture via `image_picker` (both are always available for every task — there is no per-task restriction). Compress to ~150 KB for the wire. `photo_manager` recency pre-filter on the photo's capture time. A **Supabase Edge Function** holds the Gemini API key (never in the app binary), verifies the caller's anon JWT, rate-limits, and returns structured JSON: `task_shown`, `confidence`, `is_screenshot_or_screen`, `reason`. Model: **Gemini 3.1 Flash-Lite**, minimal thinking. Enforce **5 successful proofs/day** and **3 attempts/task/day** (rejections do NOT burn the daily cap). Offline → `verification_status = 'pending'`, retry on reconnect. Every completion is AI-verified — there is no honor-system fallback.
  ⚠️ **Requires the human:** Gemini API key, `supabase functions deploy` + secrets, real-device camera test.

- **Phase 3 — Real UI** from `design/`. Implement every screen from the canonical `.dc.html` files. Screens are largely independent, so this phase parallelizes well across subagents (one per screen).

- **Phase 4 — Auth + sync.** Anonymous auth on first launch (assign `user_id`); optional email/password upgrade that **preserves the same `user_id`** so history carries over. Postgres tables mirroring the local schema, with **row-level security** per user. **Hand-rolled delta sync**: cursor pull on `updated_at` + dirty push on foreground; honor `deleted_at` tombstones; last-write-wins. No PowerSync, no realtime. **Record sync is free**; cloud photo backup is premium and post-MVP.
  ⚠️ **Requires the human:** Supabase project config, RLS review.

### Standing constraints (all phases)

- The schema is **sync-ready from day one**: client-generated UUID v7 PKs, nullable `user_id`, `updated_at` epoch-millis for last-write-wins, `deleted_at` tombstones (never hard-delete).
- A Supabase MCP server is connected for **inspecting** the remote project. **Migrations go through the Supabase CLI** (`npx supabase migration new` / `db push`) — MCP cannot manage migration files. Do not create remote tables until Phase 4.
- Anything marked ⚠️ cannot be completed by an agent alone. Stop and hand back rather than stubbing it out.

## Stack

- Flutter; **Riverpod** for state; **drift** (SQLite) for the local DB.
- **rrule** package for weekly and monthly-nth-weekday recurrence *only*. Monthly day-of-month is hand-rolled (see below).
- `uuid` for UUID v7 IDs; `timezone` package where an explicit zone is needed (tests).

## Domain rules (do not violate)

- **Local calendar dates everywhere.** `occurrence_date`, streaks, and day boundaries use the user's *local* calendar date (day flips at local midnight). Never UTC dates for these. The `LocalDate` value type in `lib/src/models/local_date.dart` and the `Clock` abstraction (`lib/src/clock.dart`) exist for this — always get "today" from a `Clock`, never `DateTime.now()` directly in domain logic.
- **An occurrence is `(task, localDate, slot)`.** `due_times` is a JSON list of `"HH:mm"` strings; its index is the slot. Empty list = one untimed slot 0.
- **Monthly `day_of_month` clamps, never skips.** `day = min(month_day, lastDayOfMonth)`. A task on the 31st fires Feb 28 (29 in leap years). Standard RRULE `BYMONTHDAY` skips short months, which is why this generator is hand-rolled and must never be replaced with rrule.
- **Monthly `nth_weekday`** uses rrule `FREQ=MONTHLY;BYDAY=3FR` style; `month_nth = -1` means "Last" (`BYDAY=-1FR`).
- **No back-filling.** Completions may only be created for occurrences whose `occurrence_date == today` (local). Enforced in the repository layer.
- **One proof per slot per day:** `UNIQUE(task_id, occurrence_date, slot)` on completions.
- **Streaks are derived, never stored.** Computed on read by walking scheduled dates backward from today. A date counts iff *every* slot that date is complete (all-or-nothing). Today-pending doesn't break the streak; only a fully-elapsed incomplete scheduled date does. Non-scheduled dates are skipped, not misses. No midnight jobs, no stored counters.
- **Metres (`points_awarded`)** are computed at completion-insert time: base 10 m; + per-task streak bonus (+1 m per consecutive prior day, capped +10 m); + perfect-day bonus (+15 m attached to the day's final scheduled occurrence across all tasks). Total altitude = `SUM(points_awarded)` over non-tombstoned completions.
- **Rank tiers** (cumulative metres): Pebble 0 · Cairn 150 · Ridge 450 · Crag 1,100 · Bluff 2,400 · Peak 5,000 · Summit 8,849.
- In Phase 1 completions are inserted via a debug action with `verification_status = 'verified'`.

## Layout

- `lib/src/db/` — drift tables + `AppDatabase` (codegen via `dart run build_runner build`)
- `lib/src/models/` — `LocalDate`, `Occurrence`, enums
- `lib/src/services/` — occurrence generator, streaks, points/rank
- `lib/src/repo/` — task + completion repositories (all writes go through here)
- `lib/src/debug/` — Phase 1 debug screen
- `test/` — unit tests are the acceptance criteria; run `flutter test` after every change.

## Git

- **Never run `git commit`, `git add`, `git push`, or any other state-changing git command.** The human owns all commits.
- After completing a phase or a meaningful step, **print a suggested commit message** in a code block for the human to copy. Use conventional-commit style (`feat:`, `fix:`, `test:`, `chore:`), a concise subject line, and a short body listing what changed and why.
- Read-only git commands (`git status`, `git diff`, `git log`) are fine.

## About "—"

Do not ever use the character "—". Use another fitting character.
