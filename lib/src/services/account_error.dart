import 'dart:io' show SocketException;

import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, AuthRetryableFetchException, AuthWeakPasswordException;

/// Typed outcomes the account-upgrade UI (WO-B) branches on, so it never has
/// to string-match Supabase's error text.
///
/// See [mapAuthError]'s doc comment for the exact SDK error codes each of
/// these was verified against (gotrue 2.26.0 / supabase_flutter 2.16.0).
enum AccountError {
  /// `updateUser(email: ...)` (the create-account flow's first step) found
  /// the email already registered to a different account. Code `email_exists`.
  emailInUse,

  /// The SDK's own password-strength check rejected `updateUser(password: ...)`.
  /// Code `weak_password` (or the dedicated `AuthWeakPasswordException`).
  weakPassword,

  /// `updateUser(password: ...)` failed because the new password is identical
  /// to the account's current password. Code `same_password`.
  samePassword,

  /// `verifyOtp` failed: the 6-digit code was wrong, already used, or has
  /// expired. Code `otp_expired` - Supabase's Auth server does not
  /// distinguish "wrong" from "expired" in the code it returns.
  invalidCode,

  /// `signInWithPassword` failed: the email/password combination doesn't
  /// match an account. Code `invalid_credentials`.
  invalidCredentials,

  /// A send/request rate limit was hit (OTP emails, password-reset emails,
  /// or the general auth request limit). Codes `over_email_send_rate_limit`,
  /// `over_sms_send_rate_limit`, `over_request_rate_limit`.
  rateLimited,

  /// No network reached the auth server at all (a thrown
  /// `AuthRetryableFetchException`, i.e. a 5xx or a fetch-level failure, or a
  /// bare `SocketException`).
  offline,

  /// Anything else: an SDK error whose code isn't one of the above, or a
  /// non-SDK error this mapping doesn't specifically recognise.
  unknown,
}

/// Thrown by every mutating [AuthService] method that can fail, carrying the
/// typed [error] plus the original message for logging (WO-B must branch on
/// [error], never on [message]).
class AccountException implements Exception {
  final AccountError error;
  final String message;

  const AccountException(this.error, [this.message = '']);

  @override
  String toString() => 'AccountException($error'
      '${message.isEmpty ? '' : ': $message'})';
}

/// Maps a thrown error (almost always an [AuthException] from the Supabase
/// SDK's `GoTrueClient`, but defensively anything else too) to a typed
/// [AccountError].
///
/// Verified against the resolved package versions in this project
/// (gotrue 2.26.0 via supabase_flutter 2.16.0): `AuthException.code` carries
/// the raw `code` field from the Auth server's JSON error body (see
/// `gotrue`'s `fetch.dart`), which is not restricted to the codes the
/// `ErrorCode` enum in that package happens to enumerate - Supabase's public
/// error-codes documentation confirms `invalid_credentials` and
/// `over_email_send_rate_limit` are real, current codes even though the
/// installed `gotrue` package's own `ErrorCode` enum (used only internally,
/// for special-casing weak-password responses) does not list them.
AccountError mapAuthError(Object error) {
  if (error is AuthWeakPasswordException) return AccountError.weakPassword;
  if (error is AuthRetryableFetchException) return AccountError.offline;
  if (error is SocketException) return AccountError.offline;

  if (error is AuthException) {
    switch (error.code) {
      case 'email_exists':
        return AccountError.emailInUse;
      case 'weak_password':
        return AccountError.weakPassword;
      case 'same_password':
        return AccountError.samePassword;
      case 'otp_expired':
        return AccountError.invalidCode;
      case 'invalid_credentials':
        return AccountError.invalidCredentials;
      case 'over_email_send_rate_limit':
      case 'over_sms_send_rate_limit':
      case 'over_request_rate_limit':
        return AccountError.rateLimited;
    }
    if (error.message.toLowerCase().contains('different from the old password')) {
      return AccountError.samePassword;
    }
  }

  return AccountError.unknown;
}
