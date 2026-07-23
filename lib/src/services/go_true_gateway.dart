import 'package:supabase_flutter/supabase_flutter.dart'
    show OtpType, Supabase, SupabaseClient, UserAttributes;

/// The subset of `GoTrueClient` (Supabase's auth client) operations the
/// account-upgrade feature needs: current session identity, anonymous
/// sign-in, the email-upgrade/verify/password steps, password sign-in,
/// password-reset, and sign-out.
///
/// Wrapped as its own seam, rather than [AuthService] calling
/// `Supabase.instance.client.auth` directly, so [AuthService]'s
/// flow-ordering and error-mapping logic can be unit-tested against a fake
/// with no network and no real [SupabaseClient] - the same pattern as
/// `SyncPostgrest` in `sync/supabase_sync_transport.dart` and `ProofInvoker`
/// in `supabase_proof_verifier.dart`. [SupabaseGoTrueGateway] is the only
/// production implementation, and resolves the real client lazily (only
/// inside each call, never at construction time), so merely constructing it
/// is safe even before `Supabase.initialize()` has run.
///
/// Every method here surfaces the SDK's own exceptions unchanged (typically
/// `AuthException` and its subclasses from `package:gotrue`); mapping those
/// to a typed [AccountError] happens one layer up, in [AuthService] - see
/// `account_error.dart`.
abstract class GoTrueGateway {
  /// The current session's user id, or null when there is no session.
  String? get currentUserId;

  /// The current session's user email, or null when there is no session, or
  /// the session has no email identity yet (a plain anonymous user).
  String? get currentEmail;

  /// True iff a session exists and the SDK's own `is_anonymous` JWT claim is
  /// set: an anonymous user that has not (yet) completed the email upgrade.
  /// False both when there is no session at all and when the session
  /// belongs to a real (non-anonymous) account.
  bool get currentIsAnonymous;

  /// Creates a new anonymous session. No-op contract enforcement here (the
  /// caller decides whether to call this only when there's no session yet);
  /// mirrors `GoTrueClient.signInAnonymously`.
  Future<void> signInAnonymously();

  /// Starts attaching [email] to the current session. With confirm-email on
  /// (this project's setting) this sends a 6-digit OTP to [email] and does
  /// NOT attach it yet - [verifyOtp] with `OtpType.emailChange` finishes the
  /// job.
  Future<void> updateEmail(String email);

  /// Verifies a 6-digit OTP [token] sent to [email] for the given [type]
  /// (`OtpType.emailChange` for the email-upgrade flow, `OtpType.recovery`
  /// for the password-reset flow).
  Future<void> verifyOtp({
    required String email,
    required String token,
    required OtpType type,
  });

  /// Sets the current session's password. Per Supabase's own docs this is
  /// only meaningful once the account's email is verified (an anonymous
  /// user's identity isn't "real" until then); this method itself doesn't
  /// enforce that ordering - see `AccountService`, which does.
  Future<void> updatePassword(String password);

  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  /// Sends a password-reset OTP to [email].
  Future<void> resetPasswordForEmail(String email);

  /// Signs out the current session. Note: `GoTrueClient.signOut` clears the
  /// local session *before* attempting the (best-effort) server-side token
  /// revoke, so the local session is gone even if this throws (e.g.
  /// offline) - see `AuthService.signOut`, which relies on exactly that.
  Future<void> signOut();
}

/// Wraps a real [SupabaseClient] (resolved lazily via [_clientOverride] or
/// `Supabase.instance.client`, never at construction time) to satisfy
/// [GoTrueGateway]. [client] is a test-only override; production code should
/// use the default constructor.
class SupabaseGoTrueGateway implements GoTrueGateway {
  final SupabaseClient? _clientOverride;

  SupabaseGoTrueGateway({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  @override
  String? get currentUserId => _client.auth.currentSession?.user.id;

  @override
  String? get currentEmail => _client.auth.currentSession?.user.email;

  @override
  bool get currentIsAnonymous =>
      _client.auth.currentSession?.user.isAnonymous ?? false;

  @override
  Future<void> signInAnonymously() async {
    await _client.auth.signInAnonymously();
  }

  @override
  Future<void> updateEmail(String email) async {
    await _client.auth.updateUser(UserAttributes(email: email));
  }

  @override
  Future<void> verifyOtp({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    await _client.auth.verifyOTP(email: email, token: token, type: type);
  }

  @override
  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
