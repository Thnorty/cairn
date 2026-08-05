import '../models/trail_summary.dart';
import '../premium/premium_service.dart';
import '../repo/completion_repository.dart';
import '../repo/settings_repository.dart';
import '../repo/task_repository.dart';
import '../sync/sync_service.dart';
import 'auth_service.dart';

/// Outcome of [AccountService.signIn]: either the switch to the account's
/// data is already done, or the device has local data of its own and the
/// caller (WO-B's chooser screen) must ask the user which trail to keep -
/// see [SignInNeedsTrailChoice].
sealed class SignInOutcome {
  const SignInOutcome();
}

/// Sign-in completed and the local database has already been replaced with
/// the account's cloud data (there was no local trail to lose). [syncResult]
/// is the outcome of that replace's own sync cycle - check
/// [SyncResult.isFullSuccess] before assuming the switch actually landed
/// (see [SyncService.replaceLocalWithCloud]'s doc comment on the rare
/// offline-in-between case).
class SignInComplete extends SignInOutcome {
  final SyncResult syncResult;
  const SignInComplete(this.syncResult);
}

/// Sign-in succeeded, but this device already has local syncable data (at
/// least one live completion) and the account may have its own. Nothing has
/// been touched yet: the caller must show [local] vs [remote] to the user
/// and then call exactly one of [AccountService.keepThisDevice] or
/// [AccountService.useAccount] to proceed.
class SignInNeedsTrailChoice extends SignInOutcome {
  final TrailSummary local;
  final TrailSummary remote;
  const SignInNeedsTrailChoice({required this.local, required this.remote});
}

/// Anonymous-vs-signed-in state for the Profile row (see
/// `accountStateProvider` in `providers.dart` for the Riverpod-facing
/// wrapper).
class AccountState {
  final bool isAnonymous;
  final String? email;
  const AccountState({required this.isAnonymous, this.email});
}

/// Orchestrates the Phase 4b account-upgrade flows (create account, sign in
/// to an existing account, reset a forgotten password, sign out) on top of
/// [AuthService] and [SyncService], so WO-B's screens hold no business
/// logic of their own - they only call methods here and react to what comes
/// back.
class AccountService {
  final AuthService _auth;
  final SyncService _sync;
  final CompletionRepository _completions;
  final TaskRepository _tasks;
  final PremiumService? _premium;

  /// Local display-name settings, used to carry the user's name up to the
  /// account (create-account, `keepThisDevice`) and down from it
  /// (`signIn`'s `SignInComplete` case, `useAccount`) - see
  /// `Cairn Onboarding Name.dc.html`'s doc comment on "carry it to the
  /// account, with no new account fields". Optional (mirrors [_premium]):
  /// a caller that builds an [AccountService] without wiring this simply
  /// skips the display-name step, rather than every existing call site (this
  /// file's own tests, `providers.dart`'s older call shape) having to be
  /// touched just to keep constructing.
  final SettingsRepository? _settings;

  /// Held between [startCreateAccount] and [confirmCreateAccount] (never
  /// exposed back to the caller): the create-account flow collects
  /// email+password up front, but the password can only actually be set
  /// server-side once the email is verified (see [AuthService.setPassword]'s
  /// doc comment), so it has to be remembered somewhere in between. This is
  /// that somewhere, rather than the widget.
  String? _heldPassword;

  AccountService({
    required AuthService auth,
    required SyncService sync,
    required CompletionRepository completions,
    required TaskRepository tasks,
    PremiumService? premium,
    SettingsRepository? settings,
  })  : _auth = auth,
        _sync = sync,
        _completions = completions,
        _tasks = tasks,
        _premium = premium,
        _settings = settings;

  bool get isAnonymous => _auth.isAnonymous;
  String? get email => _auth.email;

  // ---- create-account flow ---------------------------------------------

  /// Step 1: begins attaching [email] to the current anonymous session
  /// (sends the OTP) and holds [password] in memory for [confirmCreateAccount]
  /// to use once the email is verified. [password] is expected to already be
  /// validated client-side (length, etc.) by the caller before this is
  /// invoked; this method does not re-validate it. Throws
  /// [AccountException] (e.g. [AccountError.emailInUse]) without holding the
  /// password if [startEmailUpgrade] itself fails.
  Future<void> startCreateAccount({
    required String email,
    required String password,
  }) async {
    await _auth.startEmailUpgrade(email);
    _heldPassword = password;
  }

  /// Step 2: verifies [code] against the email started by
  /// [startCreateAccount], then sets the held password on the now-verified
  /// account. Throws [StateError] if called with no create-account flow in
  /// progress (a caller bug, not a user-facing error) - WO-B should never be
  /// able to reach this screen without a prior successful
  /// [startCreateAccount] call.
  Future<void> confirmCreateAccount(String code) async {
    final password = _heldPassword;
    if (password == null) {
      throw StateError(
        'confirmCreateAccount called with no create-account flow in progress',
      );
    }
    await _auth.verifyEmailCode(code);
    await _auth.setPassword(password);
    _heldPassword = null;
    // Best-effort: carry the local display name (if any) up to the new
    // account's metadata so it syncs to other devices. A failure here must
    // never fail or roll back account creation - same defensive posture as
    // signOut()'s premium?.logOut() below.
    await _pushLocalDisplayNameIfPresent();
  }

  // ---- sign-in flow -----------------------------------------------------

  /// Signs in to an existing account, then decides what happens to local
  /// data: no local trail at all AND no live task at all (a fresh
  /// install/onboarding) replaces local data with the account's outright and
  /// reports [SignInComplete]; any local trail (at least one live
  /// completion) OR any live task (a habit created locally but not yet
  /// completed - `local.stones == 0` alone would miss it) reports
  /// [SignInNeedsTrailChoice] with both sides' summaries and applies nothing
  /// until the caller picks one of [keepThisDevice]/[useAccount]. This is
  /// what keeps a user's locally-created habits from ever being silently
  /// wiped by a same-device sign-in (decided alongside WO-B of the Phase 4b
  /// account upgrade).
  Future<SignInOutcome> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(email: email, password: password);

    final local = await _completions.localTrailSummary();
    final hasLiveTasks = await _tasks.hasAnyLiveTasks();
    if (local.stones == 0 && !hasLiveTasks) {
      final result = await _sync.replaceLocalWithCloud();
      // Onboarding sign-in (empty local) adopts the account outright, name
      // included - see Cairn Onboarding Name.dc.html's doc comment. Older
      // accounts with no stored name leave local untouched (there's nothing
      // to adopt yet, and local is empty here anyway).
      await _adoptRemoteDisplayNameIfPresent();
      return SignInComplete(result);
    }

    final remote = await _sync.remoteTrailSummary();
    return SignInNeedsTrailChoice(local: local, remote: remote);
  }

  /// User picked "keep this device" on the trail chooser: the account
  /// (cloud) is made to match this device's local live data, tombstoning
  /// whatever the account had that this device doesn't. See
  /// [SyncService.replaceCloudWithLocal]. The local display name (if any)
  /// is pushed up to the account's metadata best-effort, the same "this
  /// device wins" direction as the trail data itself.
  Future<SyncResult> keepThisDevice() async {
    final result = await _sync.replaceCloudWithLocal();
    await _pushLocalDisplayNameIfPresent();
    return result;
  }

  /// User picked "use the account" on the trail chooser: local data is
  /// discarded in favour of the account's. See
  /// [SyncService.replaceLocalWithCloud]. The account's stored display name
  /// (if any) is adopted into local settings, the same "account wins"
  /// direction as the trail data itself; an older account with no stored
  /// name leaves the local name untouched rather than clearing it.
  Future<SyncResult> useAccount() async {
    final result = await _sync.replaceLocalWithCloud();
    await _adoptRemoteDisplayNameIfPresent();
    return result;
  }

  /// Pushes the local device's stored display name (if any) up to the
  /// signed-in account's `user_metadata`. Best-effort throughout: a missing
  /// [_settings] wiring, no local name yet, or an [_auth] failure are all
  /// silently no-ops - never surfaced to the caller, per this run's spec
  /// ("a metadata failure must NEVER fail or roll back account creation,
  /// same defensive posture as signOut()'s premium?.logOut()").
  Future<void> _pushLocalDisplayNameIfPresent() async {
    try {
      final name = await _settings?.displayName();
      if (name != null) await _auth.setDisplayName(name);
    } catch (_) {
      // Best-effort: see this method's doc comment.
    }
  }

  /// Adopts the signed-in account's stored display name (if any) into local
  /// settings. Best-effort (see [_pushLocalDisplayNameIfPresent]'s doc
  /// comment); an account with no stored name (an older account, created
  /// before this feature existed) leaves the local name exactly as it was
  /// rather than clearing it.
  Future<void> _adoptRemoteDisplayNameIfPresent() async {
    try {
      final remoteName = _auth.displayName;
      if (remoteName != null && remoteName.trim().isNotEmpty) {
        await _settings?.setDisplayName(remoteName);
      }
    } catch (_) {
      // Best-effort: see _pushLocalDisplayNameIfPresent's doc comment.
    }
  }

  // ---- password-reset flow -----------------------------------------------

  Future<void> sendPasswordResetCode(String email) =>
      _auth.sendPasswordResetCode(email);

  Future<void> verifyPasswordResetCode({
    required String email,
    required String code,
  }) =>
      _auth.verifyPasswordResetCode(email: email, code: code);

  Future<void> setNewPassword(String password) => _auth.setPassword(password);

  // ---- sign-out -----------------------------------------------------------

  /// See [AuthService.signOut]'s doc comment: releases billing identity then
  /// reverts to a fresh anonymous session.
  ///
  /// The billing log-out runs first, while the user id is still known, but is
  /// deliberately best-effort: a failure there must never strand the user in a
  /// session they asked to leave, so it is swallowed and the auth sign-out
  /// always proceeds.
  Future<void> signOut() async {
    try {
      await _premium?.logOut();
    } catch (_) {
      // Best-effort: see above.
    }
    await _auth.signOut();
  }
}
