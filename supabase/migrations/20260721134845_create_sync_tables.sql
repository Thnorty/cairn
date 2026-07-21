-- Phase 4b: Postgres tables mirroring the local drift schema for the
-- hand-rolled delta sync (see lib/src/sync/). Every table is per-user via
-- RLS (user_id = auth.uid()), carries updated_at (epoch millis) for
-- last-write-wins, and deleted_at tombstones (rows are NEVER hard-deleted).
--
-- The client-only `dirty` column is deliberately NOT mirrored here: it means
-- "this device has an unpushed local change", which is meaningless server-side.
--
-- No foreign key from completions/verification_attempts to tasks: the delta
-- sync can push a completion before its task, and last-write-wins gives no
-- ordering guarantee, so referential integrity is enforced client-side (the
-- repositories) rather than by a server constraint that a sync race could trip.
--
-- Anonymous sign-ins (Phase 2b) carry the `authenticated` role with a stable
-- user_id, so all grants/policies target `authenticated`.

-- ============================ tasks ============================
create table public.tasks (
  id uuid primary key,
  title text not null,
  description text,
  recurrence_type text not null,
  weekly_days text,
  monthly_mode text,
  month_day integer,
  month_nth integer,
  month_weekday integer,
  due_date text,
  due_times text not null default '[]',
  start_date text not null,
  end_date text,
  archived boolean not null default false,
  user_id uuid not null default auth.uid(),
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint
);

-- ============================ completions ============================
create table public.completions (
  id uuid primary key,
  task_id uuid not null,
  occurrence_date text not null,
  slot integer not null default 0,
  completed_at bigint not null,
  -- A device-local file path: it syncs as a plain string but the file itself
  -- does not (cloud photo backup is premium and post-MVP), so another device
  -- sees the record without the photo.
  proof_photo_path text,
  proof_source text,
  photo_taken_at bigint,
  verification_status text not null default 'none',
  verification_meta text,
  points_awarded integer not null default 0,
  user_id uuid not null default auth.uid(),
  updated_at bigint not null,
  deleted_at bigint
);

-- One live proof per (task, date, slot): a partial unique index over
-- non-tombstoned rows only, mirroring the local `completions_slot_unique`, so
-- a tombstoned completion frees the slot for re-completion.
create unique index completions_slot_unique
  on public.completions (task_id, occurrence_date, slot)
  where deleted_at is null;

-- ============================ verification_attempts ============================
create table public.verification_attempts (
  id uuid primary key,
  task_id uuid not null,
  occurrence_date text not null,
  slot integer not null default 0,
  attempted_at bigint not null,
  verdict_meta text,
  user_id uuid not null default auth.uid(),
  updated_at bigint not null,
  deleted_at bigint
);

-- Cursor-pull indexes: the delta sync pulls the caller's rows with
-- updated_at > cursor.
create index tasks_user_updated_idx on public.tasks (user_id, updated_at);
create index completions_user_updated_idx on public.completions (user_id, updated_at);
create index verification_attempts_user_updated_idx on public.verification_attempts (user_id, updated_at);

-- ============================ row-level security ============================
-- Enable RLS, grant the authenticated role SELECT/INSERT/UPDATE (NOT DELETE:
-- rows are tombstoned via deleted_at, never hard-deleted), and restrict every
-- row to its owner on read and write.

alter table public.tasks enable row level security;
alter table public.completions enable row level security;
alter table public.verification_attempts enable row level security;

grant select, insert, update on public.tasks to authenticated;
grant select, insert, update on public.completions to authenticated;
grant select, insert, update on public.verification_attempts to authenticated;

-- tasks
create policy tasks_select_own on public.tasks
  for select to authenticated using (user_id = auth.uid());
create policy tasks_insert_own on public.tasks
  for insert to authenticated with check (user_id = auth.uid());
create policy tasks_update_own on public.tasks
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- completions
create policy completions_select_own on public.completions
  for select to authenticated using (user_id = auth.uid());
create policy completions_insert_own on public.completions
  for insert to authenticated with check (user_id = auth.uid());
create policy completions_update_own on public.completions
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- verification_attempts
create policy verification_attempts_select_own on public.verification_attempts
  for select to authenticated using (user_id = auth.uid());
create policy verification_attempts_insert_own on public.verification_attempts
  for insert to authenticated with check (user_id = auth.uid());
create policy verification_attempts_update_own on public.verification_attempts
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
