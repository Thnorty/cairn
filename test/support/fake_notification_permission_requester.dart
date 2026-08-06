import 'package:cairn/src/services/notification_permission_requester.dart';

/// Test fake for [NotificationPermissionRequester], so a widget test can
/// drive both the "Allow notifications" path and the settings screen's
/// blocked state without touching `permission_handler`'s platform channel.
///
/// [grantOnRequest] is what a [request] resolves to AND what it flips
/// [isGranted] to, which is exactly how the real OS prompt behaves: granting
/// it changes the answer the next `isGranted` check gets.
class FakeNotificationPermissionRequester
    implements NotificationPermissionRequester {
  FakeNotificationPermissionRequester({
    this.grantOnRequest = true,
    bool initiallyGranted = false,
  }) : _granted = initiallyGranted;

  /// Whether the simulated OS prompt is accepted.
  bool grantOnRequest;

  bool _granted;
  int requestCount = 0;

  @override
  Future<bool> request() async {
    requestCount++;
    if (grantOnRequest) _granted = true;
    return _granted;
  }

  @override
  Future<bool> isGranted() async => _granted;
}
