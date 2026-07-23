import 'package:cairn/src/services/go_true_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

class RecordedVerifyOtp {
  final String email;
  final String token;
  final OtpType type;
  const RecordedVerifyOtp(this.email, this.token, this.type);
}

class RecordedSignIn {
  final String email;
  final String password;
  const RecordedSignIn(this.email, this.password);
}

/// In-memory [GoTrueGateway] fake for testing [SupabaseAuthService]'s
/// flow-ordering and error-mapping logic with no network and no real
/// `SupabaseClient`.
///
/// Each `*Error` field, when non-null, makes the next (and every subsequent,
/// until reset) call to the matching method throw that error instead of
/// succeeding; tests set it back to null themselves to let a later call in
/// the same sequence succeed, keeping multi-step flows explicit.
///
/// State-mutating calls (`signInAnonymously`, `verifyOtp` with
/// `emailChange`, `signInWithPassword`, `signOut`) update [userId]/
/// [userEmail]/[isAnonymousUser] the same way the real GoTrue server would,
/// so ordering tests can assert on the resulting session shape too.
/// [signOut] mirrors the real SDK's own documented ordering (see
/// `GoTrueGateway.signOut`'s doc comment): the session is cleared *before*
/// any configured error is thrown, since that's what
/// `SupabaseAuthService.signOut` relies on to safely fall through to a
/// fresh anonymous sign-in even when offline.
class FakeGoTrueGateway implements GoTrueGateway {
  String? userId;
  String? userEmail;
  bool isAnonymousUser;

  Object? signInAnonymouslyError;
  Object? updateEmailError;
  Object? verifyOtpError;
  Object? updatePasswordError;
  Object? signInWithPasswordError;
  Object? resetPasswordForEmailError;
  Object? signOutError;

  int signInAnonymouslyCallCount = 0;
  int signOutCallCount = 0;
  final List<String> updateEmailCalls = [];
  final List<RecordedVerifyOtp> verifyOtpCalls = [];
  final List<String> updatePasswordCalls = [];
  final List<RecordedSignIn> signInWithPasswordCalls = [];
  final List<String> resetPasswordForEmailCalls = [];

  FakeGoTrueGateway({
    this.userId,
    this.userEmail,
    this.isAnonymousUser = false,
  });

  @override
  String? get currentUserId => userId;

  @override
  String? get currentEmail => userEmail;

  @override
  bool get currentIsAnonymous => isAnonymousUser;

  @override
  Future<void> signInAnonymously() async {
    signInAnonymouslyCallCount++;
    if (signInAnonymouslyError != null) throw signInAnonymouslyError!;
    userId = 'anon-user-id';
    userEmail = null;
    isAnonymousUser = true;
  }

  @override
  Future<void> updateEmail(String email) async {
    updateEmailCalls.add(email);
    if (updateEmailError != null) throw updateEmailError!;
    // Confirm-email ON (this project's setting): does not attach the email
    // yet, matching production - see GoTrueGateway.updateEmail's doc comment.
  }

  @override
  Future<void> verifyOtp({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    verifyOtpCalls.add(RecordedVerifyOtp(email, token, type));
    if (verifyOtpError != null) throw verifyOtpError!;
    if (type == OtpType.emailChange) {
      userEmail = email;
      isAnonymousUser = false;
    }
  }

  @override
  Future<void> updatePassword(String password) async {
    updatePasswordCalls.add(password);
    if (updatePasswordError != null) throw updatePasswordError!;
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInWithPasswordCalls.add(RecordedSignIn(email, password));
    if (signInWithPasswordError != null) throw signInWithPasswordError!;
    userId = 'signed-in-user-id';
    userEmail = email;
    isAnonymousUser = false;
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    resetPasswordForEmailCalls.add(email);
    if (resetPasswordForEmailError != null) throw resetPasswordForEmailError!;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    userId = null;
    userEmail = null;
    isAnonymousUser = false;
    if (signOutError != null) throw signOutError!;
  }
}
