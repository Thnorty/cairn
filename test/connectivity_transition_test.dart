import 'package:cairn/src/services/proof_retry_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isReconnectTransition', () {
    test('unknown -> connected runs', () {
      expect(
        isReconnectTransition(
          ConnectivityState.unknown,
          ConnectivityState.connected,
        ),
        isTrue,
      );
    });

    test('none -> connected runs', () {
      expect(
        isReconnectTransition(
          ConnectivityState.none,
          ConnectivityState.connected,
        ),
        isTrue,
      );
    });

    test('connected -> connected does not run', () {
      expect(
        isReconnectTransition(
          ConnectivityState.connected,
          ConnectivityState.connected,
        ),
        isFalse,
      );
    });

    test('connected -> none does not run', () {
      expect(
        isReconnectTransition(
          ConnectivityState.connected,
          ConnectivityState.none,
        ),
        isFalse,
      );
    });

    test('none -> none does not run', () {
      expect(
        isReconnectTransition(ConnectivityState.none, ConnectivityState.none),
        isFalse,
      );
    });
  });
}
