import 'package:cairn/src/services/account_deleter.dart';

/// Test fake for [AccountDeleter].
class FakeAccountDeleter implements AccountDeleter {
  int callCount = 0;
  Object? errorToThrow;

  @override
  Future<void> deleteRemoteAccount() async {
    callCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
  }
}
