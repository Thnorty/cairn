-- Tidy the pre-existing public.rls_auto_enable() helper's ACL. It carried
-- Supabase's default EXECUTE grant to anon / authenticated / PUBLIC. That
-- grant is unexploitable: the function returns event_trigger, so Postgres
-- refuses any direct invocation regardless of EXECUTE, and the ensure_rls
-- event trigger (ddl_command_end) that legitimately drives it runs it as its
-- owner, not as the calling role. But an ACL/advisor audit reads it as a
-- SECURITY DEFINER function exposed to anon, so revoke it and leave EXECUTE
-- with only postgres and service_role. The auto-RLS behaviour is unaffected.
revoke execute on function public.rls_auto_enable() from anon, authenticated, public;
