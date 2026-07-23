import 'dart:io' show SocketException;

import 'package:cairn/src/services/account_error.dart';
import 'package:cairn/src/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthApiException,
        AuthRetryableFetchException,
        AuthWeakPasswordException,
        OtpType;

import 'support/fake_go_true_gateway.dart';

void main() {
  group('currentUserId / isAnonymous / email never throw', () {
    test('resolve normally against a healthy gateway', () {
      final gateway = FakeGoTrueGateway(
        userId: 'user-1',
        userEmail: 'a@b.com',
        isAnonymousUser: false,
      );
      final auth = SupabaseAuthService(gateway: gateway);

      expect(auth.currentUserId, 'user-1');
      expect(auth.email, 'a@b.com');
      expect(auth.isAnonymous, isFalse);
    });

    test('a throwing gateway getter is swallowed to a safe default', () {
      final auth = SupabaseAuthService(gateway: _ThrowingGetterGateway());

      expect(auth.currentUserId, isNull);
      expect(auth.email, isNull);
      expect(auth.isAnonymous, isFalse);
    });
  });

  group('ensureSignedIn', () {
    test('signs in anonymously when there is no session yet', () async {
      final gateway = FakeGoTrueGateway();
      final auth = SupabaseAuthService(gateway: gateway);

      await auth.ensureSignedIn();

      expect(gateway.signInAnonymouslyCallCount, 1);
      expect(auth.currentUserId, isNotNull);
      expect(auth.isAnonymous, isTrue);
    });

    test('is a no-op once a session already exists', () async {
      final gateway = FakeGoTrueGateway(userId: 'existing-user');
      final auth = SupabaseAuthService(gateway: gateway);

      await auth.ensureSignedIn();

      expect(gateway.signInAnonymouslyCallCount, 0);
    });

    test('never throws even when the gateway call fails', () async {
      final gateway = FakeGoTrueGateway()
        ..signInAnonymouslyError = const SocketException('offline');
      final auth = SupabaseAuthService(gateway: gateway);

      await auth.ensureSignedIn(); // must not throw
      expect(auth.currentUserId, isNull);
    });
  });

  group('create-account flow ordering', () {
    test('verifyEmailCode sends the OTP against the email startEmailUpgrade '
        'started for, with type emailChange', () async {
      final gateway = FakeGoTrueGateway(userId: 'anon', isAnonymousUser: true);
      final auth = SupabaseAuthService(gateway: gateway);

      await auth.startEmailUpgrade('new@example.com');
      await auth.verifyEmailCode('123456');

      expect(gateway.updateEmailCalls, ['new@example.com']);
      expect(gateway.verifyOtpCalls, hasLength(1));
      expect(gateway.verifyOtpCalls.single.email, 'new@example.com');
      expect(gateway.verifyOtpCalls.single.token, '123456');
      expect(gateway.verifyOtpCalls.single.type, OtpType.emailChange);
      expect(auth.email, 'new@example.com');
      expect(auth.isAnonymous, isFalse);
    });

    test('verifyEmailCode with no prior startEmailUpgrade throws', () async {
      final auth = SupabaseAuthService(gateway: FakeGoTrueGateway());

      expect(
        () => auth.verifyEmailCode('123456'),
        throwsA(isA<AccountException>()),
      );
    });

    test('a failed startEmailUpgrade does not arm verifyEmailCode', () async {
      final gateway = FakeGoTrueGateway()
        ..updateEmailError =
            const AuthApiException('already taken', code: 'email_exists');
      final auth = SupabaseAuthService(gateway: gateway);

      await expectLater(
        auth.startEmailUpgrade('taken@example.com'),
        throwsA(
          isA<AccountException>().having(
            (e) => e.error,
            'error',
            AccountError.emailInUse,
          ),
        ),
      );

      // No email was ever held, so this must still fail as "no upgrade in
      // progress", not attempt an OTP verify against a stale/absent email.
      expect(
        () => auth.verifyEmailCode('123456'),
        throwsA(isA<AccountException>()),
      );
      expect(gateway.verifyOtpCalls, isEmpty);
    });

    test('setPassword calls the gateway directly', () async {
      final gateway = FakeGoTrueGateway();
      final auth = SupabaseAuthService(gateway: gateway);

      await auth.setPassword('correct horse battery staple');

      expect(gateway.updatePasswordCalls, ['correct horse battery staple']);
    });
  });

  group('sign-in flow', () {
    test('signInWithPassword forwards email/password', () async {
      final gateway = FakeGoTrueGateway();
      final auth = SupabaseAuthService(gateway: gateway);

      await auth.signInWithPassword(email: 'a@b.com', password: 'hunter2');

      expect(gateway.signInWithPasswordCalls, hasLength(1));
      expect(gateway.signInWithPasswordCalls.single.email, 'a@b.com');
      expect(gateway.signInWithPasswordCalls.single.password, 'hunter2');
      expect(auth.currentUserId, isNotNull);
      expect(auth.isAnonymous, isFalse);
    });
  });

  group('password-reset flow', () {
    test('sendPasswordResetCode / verifyPasswordResetCode use OtpType.recovery',
        () async {
      final gateway = FakeGoTrueGateway();
      final auth = SupabaseAuthService(gateway: gateway);

      await auth.sendPasswordResetCode('a@b.com');
      await auth.verifyPasswordResetCode(email: 'a@b.com', code: '999999');

      expect(gateway.resetPasswordForEmailCalls, ['a@b.com']);
      expect(gateway.verifyOtpCalls.single.type, OtpType.recovery);
      expect(gateway.verifyOtpCalls.single.email, 'a@b.com');
      expect(gateway.verifyOtpCalls.single.token, '999999');
    });
  });

  group('signOut', () {
    test('clears the session and re-establishes a fresh anonymous one',
        () async {
      final gateway = FakeGoTrueGateway(userId: 'real-user', userEmail: 'a@b.com');
      final auth = SupabaseAuthService(gateway: gateway);

      await auth.signOut();

      expect(gateway.signOutCallCount, 1);
      expect(gateway.signInAnonymouslyCallCount, 1);
      expect(auth.isAnonymous, isTrue);
      expect(auth.email, isNull);
    });

    test('never throws even when the gateway signOut call fails (offline), '
        'and still falls through to a fresh anonymous session', () async {
      final gateway = FakeGoTrueGateway(userId: 'real-user')
        ..signOutError = AuthRetryableFetchException(message: 'offline');
      final auth = SupabaseAuthService(gateway: gateway);

      await auth.signOut(); // must not throw

      expect(gateway.signOutCallCount, 1);
      expect(gateway.signInAnonymouslyCallCount, 1);
      expect(auth.isAnonymous, isTrue);
    });
  });

  group('mapAuthError / error mapping through AuthService methods', () {
    test('email_exists -> emailInUse', () async {
      final gateway = FakeGoTrueGateway()
        ..updateEmailError =
            const AuthApiException('in use', code: 'email_exists');
      final auth = SupabaseAuthService(gateway: gateway);

      await expectLater(
        auth.startEmailUpgrade('taken@example.com'),
        throwsA(isA<AccountException>()
            .having((e) => e.error, 'error', AccountError.emailInUse)),
      );
    });

    test('weak_password -> weakPassword', () async {
      final gateway = FakeGoTrueGateway()
        ..updatePasswordError =
            const AuthApiException('too weak', code: 'weak_password');
      final auth = SupabaseAuthService(gateway: gateway);

      await expectLater(
        auth.setPassword('123'),
        throwsA(isA<AccountException>()
            .having((e) => e.error, 'error', AccountError.weakPassword)),
      );
    });

    test('same_password -> samePassword', () async {
      final gateway = FakeGoTrueGateway()
        ..updatePasswordError = const AuthApiException(
          'New password should be different from the old password.',
          code: 'same_password',
        );
      final auth = SupabaseAuthService(gateway: gateway);

      await expectLater(
        auth.setPassword('Same1234'),
        throwsA(isA<AccountException>()
            .having((e) => e.error, 'error', AccountError.samePassword)),
      );
    });

    test('AuthWeakPasswordException -> weakPassword regardless of code',
        () async {
      final gateway = FakeGoTrueGateway()
        ..updatePasswordError = AuthWeakPasswordException(
          message: 'too weak',
          statusCode: '422',
          reasons: const ['length'],
        );
      final auth = SupabaseAuthService(gateway: gateway);

      await expectLater(
        auth.setPassword('123'),
        throwsA(isA<AccountException>()
            .having((e) => e.error, 'error', AccountError.weakPassword)),
      );
    });

    test('otp_expired -> invalidCode', () async {
      final gateway = FakeGoTrueGateway()
        ..verifyOtpError =
            const AuthApiException('expired', code: 'otp_expired');
      final auth = SupabaseAuthService(gateway: gateway);
      await auth.startEmailUpgrade('a@b.com');

      await expectLater(
        auth.verifyEmailCode('000000'),
        throwsA(isA<AccountException>()
            .having((e) => e.error, 'error', AccountError.invalidCode)),
      );
    });

    test('invalid_credentials -> invalidCredentials', () async {
      final gateway = FakeGoTrueGateway()
        ..signInWithPasswordError =
            const AuthApiException('bad login', code: 'invalid_credentials');
      final auth = SupabaseAuthService(gateway: gateway);

      await expectLater(
        auth.signInWithPassword(email: 'a@b.com', password: 'wrong'),
        throwsA(isA<AccountException>()
            .having((e) => e.error, 'error', AccountError.invalidCredentials)),
      );
    });

    test('over_email_send_rate_limit -> rateLimited', () async {
      final gateway = FakeGoTrueGateway()
        ..resetPasswordForEmailError = const AuthApiException(
          'slow down',
          code: 'over_email_send_rate_limit',
        );
      final auth = SupabaseAuthService(gateway: gateway);

      await expectLater(
        auth.sendPasswordResetCode('a@b.com'),
        throwsA(isA<AccountException>()
            .having((e) => e.error, 'error', AccountError.rateLimited)),
      );
    });

    test('AuthRetryableFetchException -> offline', () async {
      final gateway = FakeGoTrueGateway()
        ..signInWithPasswordError =
            AuthRetryableFetchException(message: '5xx');
      final auth = SupabaseAuthService(gateway: gateway);

      await expectLater(
        auth.signInWithPassword(email: 'a@b.com', password: 'x'),
        throwsA(isA<AccountException>()
            .having((e) => e.error, 'error', AccountError.offline)),
      );
    });

    test('a bare SocketException -> offline', () async {
      final gateway = FakeGoTrueGateway()
        ..signInWithPasswordError = const SocketException('no route');
      final auth = SupabaseAuthService(gateway: gateway);

      await expectLater(
        auth.signInWithPassword(email: 'a@b.com', password: 'x'),
        throwsA(isA<AccountException>()
            .having((e) => e.error, 'error', AccountError.offline)),
      );
    });

    test('an unrecognised AuthException code -> unknown', () async {
      final gateway = FakeGoTrueGateway()
        ..signInWithPasswordError =
            const AuthApiException('huh', code: 'some_new_code_we_dont_map');
      final auth = SupabaseAuthService(gateway: gateway);

      await expectLater(
        auth.signInWithPassword(email: 'a@b.com', password: 'x'),
        throwsA(isA<AccountException>()
            .having((e) => e.error, 'error', AccountError.unknown)),
      );
    });

    test('a completely unrelated thrown object -> unknown', () async {
      final gateway = FakeGoTrueGateway()
        ..signInWithPasswordError = StateError('something else broke');
      final auth = SupabaseAuthService(gateway: gateway);

      await expectLater(
        auth.signInWithPassword(email: 'a@b.com', password: 'x'),
        throwsA(isA<AccountException>()
            .having((e) => e.error, 'error', AccountError.unknown)),
      );
    });
  });
}

/// Gateway whose getters all throw, to prove [SupabaseAuthService]'s
/// read-only accessors swallow that and resolve to a safe default rather
/// than propagating it.
class _ThrowingGetterGateway extends FakeGoTrueGateway {
  @override
  String? get currentUserId => throw StateError('boom');

  @override
  String? get currentEmail => throw StateError('boom');

  @override
  bool get currentIsAnonymous => throw StateError('boom');
}
