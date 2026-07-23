-- Durable per-user and global rate limiting for proof verification.
-- Enforces per-user daily quotas and a global daily ceiling to protect
-- Gemini API budget and prevent abuse. Counting is performed inside a
-- SECURITY DEFINER function invoked with the caller's JWT, keeping the
-- Edge Function free of service-role access.

-- Counter table tracking daily verifications per user and globally.
create table public.verify_quota_counters (
  bucket text not null,
  day date not null,
  count integer not null default 0,
  primary key (bucket, day)
);

-- Enable RLS with no policies to prevent direct access by anon/authenticated.
alter table public.verify_quota_counters enable row level security;
revoke all on table public.verify_quota_counters from anon, authenticated;

-- Atomically checks and increments rate limit counters for today (UTC).
-- Bumps per-user quota first; if within user cap, bumps global quota.
-- Returns true if allowed, false if cap exceeded or unauthenticated.
create or replace function public.check_and_bump_verify_quota(
  p_user_cap integer,
  p_global_cap integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_today date;
  v_user_count integer;
  v_global_count integer;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return false;
  end if;

  v_today := ((now() at time zone 'utc')::date);

  -- Per-user check and bump
  insert into public.verify_quota_counters (bucket, day, count)
  values ('user:' || v_user_id::text, v_today, 1)
  on conflict (bucket, day) do update
    set count = verify_quota_counters.count + 1
  returning count into v_user_count;

  if v_user_count > p_user_cap then
    return false;
  end if;

  -- Global check and bump (only reached if user is under their per-user cap)
  insert into public.verify_quota_counters (bucket, day, count)
  values ('global', v_today, 1)
  on conflict (bucket, day) do update
    set count = verify_quota_counters.count + 1
  returning count into v_global_count;

  if v_global_count > p_global_cap then
    return false;
  end if;

  return true;
end;
$$;

revoke all on function public.check_and_bump_verify_quota(integer, integer) from public;
grant execute on function public.check_and_bump_verify_quota(integer, integer) to anon, authenticated;
