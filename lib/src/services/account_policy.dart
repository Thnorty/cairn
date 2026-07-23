/// Client-side password policy gate for the Phase 4b account screens
/// (`CreateAccountScreen` and `SetNewPasswordScreen`), checked before ever
/// calling `AccountService` methods so an invalid password never costs a
/// network round trip.
///
/// Mirrors this project's actual Supabase Auth password policy (minimum length
/// 8, containing at least one lowercase letter, one uppercase letter, and one
/// digit), as confirmed for this project. Also reused to word a server-side
/// `AccountError.weakPassword` fallback rejection.
const int kMinPasswordLength = 8;

final _hasLowercase = RegExp(r'[a-z]');
final _hasUppercase = RegExp(r'[A-Z]');
final _hasDigit = RegExp(r'[0-9]');

/// Returns true if [password] meets this project's Supabase Auth password
/// policy: at least [kMinPasswordLength] characters, containing at least one
/// lowercase letter (a-z), one uppercase letter (A-Z), and one digit (0-9).
///
/// Checked client-side before any network round trip, and also used to word a
/// server-side [AccountError.weakPassword] fallback.
bool meetsPasswordPolicy(String password) {
  return password.length >= kMinPasswordLength &&
      _hasLowercase.hasMatch(password) &&
      _hasUppercase.hasMatch(password) &&
      _hasDigit.hasMatch(password);
}

