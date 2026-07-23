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

/// Returns true if [password] meets the minimum length requirement.
bool passwordHasMinLength(String password) =>
    password.length >= kMinPasswordLength;

/// Returns true if [password] contains at least one uppercase letter (A-Z).
bool passwordHasUppercase(String password) =>
    _hasUppercase.hasMatch(password);

/// Returns true if [password] contains at least one lowercase letter (a-z).
bool passwordHasLowercase(String password) =>
    _hasLowercase.hasMatch(password);

/// Returns true if [password] contains at least one digit (0-9).
bool passwordHasDigit(String password) => _hasDigit.hasMatch(password);

/// Returns true if [password] meets this project's Supabase Auth password
/// policy: at least [kMinPasswordLength] characters, containing at least one
/// lowercase letter (a-z), one uppercase letter (A-Z), and one digit (0-9).
///
/// Checked client-side before any network round trip, and also used to word a
/// server-side [AccountError.weakPassword] fallback.
bool meetsPasswordPolicy(String password) {
  return passwordHasMinLength(password) &&
      passwordHasUppercase(password) &&
      passwordHasLowercase(password) &&
      passwordHasDigit(password);
}

