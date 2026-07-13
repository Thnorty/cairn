import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, SupabaseClient;

/// Anonymous-first auth, moved up from Phase 4 to Phase 2b because the
/// verify-proof Edge Function needs a caller JWT, and anonymous auth is
/// what supplies one. Assigning `user_id` from this first session means
/// Phase 4's optional email/password upgrade can preserve it (same id, more
/// history) instead of starting a new identity.
///
/// Kept behind an interface so the data layer (the repositories'
/// `currentUserId` getter) only ever depends on [currentUserId], never on
/// the Supabase SDK directly.
abstract class AuthService {
  /// The signed-in user's id, or null when there is no session yet: no
  /// sign-in has been attempted, the device was offline on first launch, or
  /// [ensureSignedIn] otherwise failed. Rows written while this is null are
  /// exactly the ones a later successful backfill (see the repositories'
  /// `backfillUserId`) stamps once a session does arrive.
  String? get currentUserId;

  /// Ensures a session exists: signs in anonymously if there is none yet.
  ///
  /// Never throws. Auth failure (offline first launch, an unreachable
  /// Supabase project, anything) must not break the app: the local-first
  /// pipeline keeps working with a null user id, and this is safe to call
  /// again on a later launch (or a later point in this one) to pick up a
  /// session once connectivity returns.
  Future<void> ensureSignedIn();
}

/// [AuthService] backed by Supabase anonymous auth.
///
/// Deliberately never touches [Supabase.instance] at construction time,
/// only inside [currentUserId] and [ensureSignedIn], and every access there
/// is wrapped in a try/catch: a caller that runs before
/// `Supabase.initialize()` has completed (or a test harness that never
/// calls it at all) must see a plain null id, not a crash. [client] is an
/// optional override for tests that do have a real (or fake) SupabaseClient
/// to hand; production code should use the default constructor, which
/// resolves `Supabase.instance.client` lazily.
class SupabaseAuthService implements AuthService {
  final SupabaseClient? _clientOverride;

  SupabaseAuthService({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  @override
  String? get currentUserId {
    try {
      return _client.auth.currentSession?.user.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> ensureSignedIn() async {
    try {
      final client = _client;
      if (client.auth.currentSession != null) return;
      await client.auth.signInAnonymously();
    } catch (_) {
      // Offline first launch, an unreachable Supabase project, or Supabase
      // never having been initialised at all: the local-first pipeline
      // keeps working with a null user id either way, and this can simply
      // be tried again later.
    }
  }
}
