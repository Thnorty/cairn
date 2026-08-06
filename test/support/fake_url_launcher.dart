import 'package:flutter_test/flutter_test.dart';
// `link.dart` is a separate entry point: LinkDelegate lives there, not in the
// package's main library, which only exports src/types.dart and
// src/url_launcher_platform.dart.
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Intercepts `launchExternalUrl` (`lib/src/ui/external_url.dart`) so a widget
/// test can assert WHICH url an external link opens, without going near
/// url_launcher's platform channel.
///
/// Swaps the plugin's own `UrlLauncherPlatform.instance`, which is the
/// package-sanctioned seam for exactly this, rather than mocking a raw method
/// channel whose name and Pigeon-generated shape differ per platform and
/// change between versions.
class FakeUrlLauncher extends UrlLauncherPlatform {
  /// Every url passed to [launchUrl], in order.
  final List<String> launched = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }

  /// Installs a fresh fake as the platform instance and restores the previous
  /// one at the end of the test.
  ///
  /// The restore matters: `UrlLauncherPlatform.instance` is a static, so a
  /// fake left installed would silently leak into every test that ran after
  /// it in the same file.
  static FakeUrlLauncher install() {
    final previous = UrlLauncherPlatform.instance;
    final fake = FakeUrlLauncher();
    UrlLauncherPlatform.instance = fake;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    return fake;
  }
}
