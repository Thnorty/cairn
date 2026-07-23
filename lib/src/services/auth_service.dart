import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

import 'account_error.dart';
import 'go_true_gateway.dart';

/// Anonymous-first auth, moved up from Phase 4 to Phase 2b because the
/// verify-proof Edge Function needs a caller JWT, and anonymous auth is
/// what supplies one. Assigning `user_id` from this first session means
/// Phase 4's optional email/password upgrade can preserve it (same id, more
/// history) instead of starting a new identity.
///
/// Kept behind an interface so the data layer (the repositories'
/// `currentUserId` getter) only ever depends on [currentUserId], never on
/// the Supabase SDK directly.
///
/// Phase 4b account upgrade (WO-A): the interface grows the email/password
/// upgrade, sign-in-to-an-existing-account, password-reset, and sign-out
/// flows. Every mutating method here can throw [AccountException] (see
/// `account_error.dart`); [currentUserId]/[ensureSignedIn] keep their
/// original never-throw contract exactly (the repos and app bootstrap
/// depend on it), and so do the new read-only [isAnonymous]/[email]
/// getters.
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

  /// True iff a session exists but has no email identity yet (a plain
  /// anonymous user, pre-upgrade). False when there is no session at all,
  /// and false once the email upgrade completes. Never throws (mirrors
  /// [currentUserId]'s contract): resolves to false on any error, same as
  /// "no session".
  bool get isAnonymous;

  /// The current session's email, or null (no session, or an anonymous
  /// session that hasn't upgraded yet). Never throws.
  String? get email;

  /// Create-account flow, step 1: starts attaching [email] to the current
  /// (anonymous) session. With confirm-email on (this project's setting)
  /// this sends a 6-digit OTP to [email] and does not attach it yet -
  /// [verifyEmailCode] finishes the job. Throws [AccountException] with
  /// [AccountError.emailInUse] if [email] is already registered to a
  /// different account.
  Future<void> startEmailUpgrade(String email);

  /// Create-account flow, step 2: verifies the 6-digit [code] sent by
  /// [startEmailUpgrade], attaching that email to the session. Must be
  /// called after a successful [startEmailUpgrade] for the same email; throws
  /// [AccountException] with [AccountError.invalidCode] for a wrong or
  /// expired code.
  Future<void> verifyEmailCode(String code);

  /// Create-account flow, step 3 (and the final step of the password-reset
  /// flow too): sets the current session's password. Per Supabase's own
  /// docs this is only meaningful once the account's email is verified, so
  /// callers must sequence this after [verifyEmailCode] (create-account) or
  /// [verifyPasswordResetCode] (reset). Throws [AccountException] with
  /// [AccountError.weakPassword] if the SDK's own strength check rejects it.
  Future<void> setPassword(String password);

  /// Signs in to an existing account with [email]/[password]. Throws
  /// [AccountException] with [AccountError.invalidCredentials] on a wrong
  /// email/password combination.
  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  /// Password-reset flow, step 1: sends a 6-digit OTP to [email].
  Future<void> sendPasswordResetCode(String email);

  /// Password-reset flow, step 2: verifies the OTP sent by
  /// [sendPasswordResetCode]. Follow with [setPassword] to finish the reset.
  Future<void> verifyPasswordResetCode({
    required String email,
    required String code,
  });

  /// Signs out, then immediately re-establishes a fresh anonymous session
  /// (via [ensureSignedIn]) so the app reverts to an anonymous identity
  /// rather than being left with no session at all. Never throws: sign-out
  /// itself is attempted best-effort (the SDK already clears the local
  /// session before the network revoke call even runs, so an offline
  /// failure here does not strand the user mid-sign-out), and
  /// [ensureSignedIn] never throws either.
  ///
  /// Decision (per spec): sign-out keeps all local data (tasks, completions,
  /// history) and simply returns the app to a fresh anonymous identity. It
  /// must NOT wipe the local database.
  Future<void> signOut();
}

/// [AuthService] backed by Supabase auth via a [GoTrueGateway] seam (real
/// production implementation: [SupabaseGoTrueGateway]).
///
/// Deliberately never touches the gateway at construction time; the default
/// gateway itself only touches `Supabase.instance` inside its own method
/// bodies (see [SupabaseGoTrueGateway]'s doc comment), so constructing this
/// is always safe even before `Supabase.initialize()` has completed (or in a
/// test harness that never calls it at all). [gateway] is an override for
/// tests.
class SupabaseAuthService implements AuthService {
  final GoTrueGateway _gateway;

  /// The email a create-account flow's [startEmailUpgrade] most recently
  /// started for, held so [verifyEmailCode] doesn't need the caller to pass
  /// it again (mirrors how the OTP itself only ever makes sense against the
  /// email it was sent to). Cleared back to null once [verifyEmailCode]
  /// succeeds, or never set at all if [startEmailUpgrade] failed.
  String? _pendingUpgradeEmail;

  SupabaseAuthService({GoTrueGateway? gateway})
      : _gateway = gateway ?? SupabaseGoTrueGateway();

  @override
  String? get currentUserId {
    try {
      return _gateway.currentUserId;
    } catch (_) {
      return null;
    }
  }

  @override
  bool get isAnonymous {
    try {
      return _gateway.currentIsAnonymous;
    } catch (_) {
      return false;
    }
  }

  @override
  String? get email {
    try {
      return _gateway.currentEmail;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> ensureSignedIn() async {
    try {
      if (_gateway.currentUserId != null) return;
      await _gateway.signInAnonymously();
    } catch (_) {
      // Offline first launch, an unreachable Supabase project, or Supabase
      // never having been initialised at all: the local-first pipeline
      // keeps working with a null user id either way, and this can simply
      // be tried again later.
    }
  }

  @override
  Future<void> startEmailUpgrade(String email) async {
    await _guarded(() => _gateway.updateEmail(email));
    _pendingUpgradeEmail = email;
  }

  @override
  Future<void> verifyEmailCode(String code) async {
    final pendingEmail = _pendingUpgradeEmail;
    if (pendingEmail == null) {
      throw const AccountException(
        AccountError.unknown,
        'verifyEmailCode called with no email upgrade in progress',
      );
    }
    await _guarded(() => _gateway.verifyOtp(
          email: pendingEmail,
          token: code,
          type: OtpType.emailChange,
        ));
    _pendingUpgradeEmail = null;
  }

  @override
  Future<void> setPassword(String password) =>
      _guarded(() => _gateway.updatePassword(password));

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) =>
      _guarded(
        () => _gateway.signInWithPassword(email: email, password: password),
      );

  @override
  Future<void> sendPasswordResetCode(String email) =>
      _guarded(() => _gateway.resetPasswordForEmail(email));

  @override
  Future<void> verifyPasswordResetCode({
    required String email,
    required String code,
  }) =>
      _guarded(
        () => _gateway.verifyOtp(email: email, token: code, type: OtpType.recovery),
      );

  @override
  Future<void> signOut() async {
    try {
      await _gateway.signOut();
    } catch (_) {
      // See this method's doc comment: the local session is already gone
      // by the time signOut can throw, so falling through to
      // ensureSignedIn regardless is safe and correct.
    }
    await ensureSignedIn();
  }

  /// Runs [body], translating anything it throws into an [AccountException]
  /// via [mapAuthError]. Shared by every mutating method above except
  /// [ensureSignedIn]/[signOut], which have their own never-throw contracts.
  Future<void> _guarded(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      throw AccountException(mapAuthError(e), e.toString());
    }
  }
}
