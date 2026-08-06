import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException, Supabase;

/// Invokes the `delete-account` Edge Function.
typedef AccountDeleterInvoker = Future<dynamic> Function();

/// Injectable seam for remote account deletion.
abstract class AccountDeleter {
  /// Deletes the signed-in user's remote auth user AND every cloud row they
  /// own. Throws on failure.
  Future<void> deleteRemoteAccount();
}

/// [AccountDeleter] backed by the `delete-account` Supabase Edge Function.
class SupabaseAccountDeleter implements AccountDeleter {
  /// Name of the deployed Edge Function.
  static const String functionName = 'delete-account';

  final AccountDeleterInvoker _invoke;
  final Duration _timeout;

  SupabaseAccountDeleter({
    AccountDeleterInvoker invoke = _defaultInvoke,
    Duration timeout = const Duration(seconds: 30),
  })  : _invoke = invoke,
        _timeout = timeout;

  @override
  Future<void> deleteRemoteAccount() async {
    try {
      await _invoke().timeout(_timeout);
    } on TimeoutException catch (e) {
      throw Exception('delete-account timed out: $e');
    } on FunctionException catch (e) {
      throw Exception(
        'delete-account returned ${e.status}: ${e.reasonPhrase ?? e.details}',
      );
    } catch (e) {
      throw Exception('delete-account call failed: $e');
    }
  }

  static Future<dynamic> _defaultInvoke() async {
    return Supabase.instance.client.functions.invoke(functionName);
  }
}

/// Fallback [AccountDeleter] when [AppConfig.isConfigured] is false.
class UnconfiguredAccountDeleter implements AccountDeleter {
  const UnconfiguredAccountDeleter();

  @override
  Future<void> deleteRemoteAccount() {
    throw StateError(
      'Cannot delete remote account when AppConfig is unconfigured',
    );
  }
}
