-- Server-side last-write-wins guard for the delta sync: an UPDATE (including
-- the ON CONFLICT DO UPDATE of a sync push) that carries an older updated_at
-- than the stored row is silently kept as-is, so an out-of-order or racing
-- push can never overwrite newer data. Tombstones ride the same rule, since
-- deleting a row bumps its updated_at.
create or replace function public.sync_lww_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.updated_at < old.updated_at then
    return old;
  end if;
  return new;
end;
$$;

create trigger tasks_lww_guard before update on public.tasks
  for each row execute function public.sync_lww_guard();
create trigger completions_lww_guard before update on public.completions
  for each row execute function public.sync_lww_guard();
create trigger verification_attempts_lww_guard before update on public.verification_attempts
  for each row execute function public.sync_lww_guard();
