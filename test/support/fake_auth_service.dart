import 'package:cairn/src/services/auth_service.dart';

class RecordedPasswordSignIn {
  final String email;
  final String password;
  const RecordedPasswordSignIn(this.email, this.password);
}

class RecordedResetCodeVerify {
  final String email;
  final String code;
  const RecordedResetCodeVerify(this.email, this.code);
}

/// In-memory [AuthService] fake for testing [AccountService]'s orchestration
/// logic without a real Supabase SDK or `GoTrueGateway` in the loop -
/// [AuthService]'s own error-mapping/flow-ordering is covered separately in
/// `auth_service_test.dart` against [FakeGoTrueGateway]; this fake lets
/// `AccountService` tests focus purely on its own decisions (what it calls,
/// in what order, and how it interprets the results).
class FakeAuthService implements AuthService {
  String? userId;
  String? userEmail;
  bool isAnonymousUser;

  Object? startEmailUpgradeError;
  Object? verifyEmailCodeError;
  Object? setPasswordError;
  Object? signInWithPasswordError;
  Object? sendPasswordResetCodeError;
  Object? verifyPasswordResetCodeError;

  final List<String> startEmailUpgradeCalls = [];
  final List<String> verifyEmailCodeCalls = [];
  final List<String> setPasswordCalls = [];
  final List<RecordedPasswordSignIn> signInWithPasswordCalls = [];
  final List<String> sendPasswordResetCodeCalls = [];
  final List<RecordedResetCodeVerify> verifyPasswordResetCodeCalls = [];
  int signOutCallCount = 0;
  int ensureSignedInCallCount = 0;

  FakeAuthService({
    this.userId = 'anon-user',
    this.userEmail,
    this.isAnonymousUser = true,
  });

  @override
  String? get currentUserId => userId;

  @override
  bool get isAnonymous => isAnonymousUser;

  @override
  String? get email => userEmail;

  @override
  Future<void> ensureSignedIn() async {
    ensureSignedInCallCount++;
    userId ??= 'anon-user';
  }

  @override
  Future<void> startEmailUpgrade(String email) async {
    startEmailUpgradeCalls.add(email);
    if (startEmailUpgradeError != null) throw startEmailUpgradeError!;
  }

  @override
  Future<void> verifyEmailCode(String code) async {
    verifyEmailCodeCalls.add(code);
    if (verifyEmailCodeError != null) throw verifyEmailCodeError!;
    isAnonymousUser = false;
  }

  @override
  Future<void> setPassword(String password) async {
    setPasswordCalls.add(password);
    if (setPasswordError != null) throw setPasswordError!;
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInWithPasswordCalls.add(RecordedPasswordSignIn(email, password));
    if (signInWithPasswordError != null) throw signInWithPasswordError!;
    userId = 'signed-in-user';
    userEmail = email;
    isAnonymousUser = false;
  }

  @override
  Future<void> sendPasswordResetCode(String email) async {
    sendPasswordResetCodeCalls.add(email);
    if (sendPasswordResetCodeError != null) throw sendPasswordResetCodeError!;
  }

  @override
  Future<void> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    verifyPasswordResetCodeCalls.add(RecordedResetCodeVerify(email, code));
    if (verifyPasswordResetCodeError != null) throw verifyPasswordResetCodeError!;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    userId = 'anon-user';
    userEmail = null;
    isAnonymousUser = true;
  }
}
