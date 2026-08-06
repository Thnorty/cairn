import 'package:url_launcher/url_launcher.dart';

/// Opens [urlString] in the device's browser (or whatever app claims it).
///
/// Best-effort by design, like [AppSettingsOpener]: a no-op on an empty
/// string, and it swallows a malformed URL or a device with nothing able to
/// handle it rather than throwing. Every caller is an optional "read more"
/// affordance, so nothing downstream depends on the launch succeeding.
///
/// The empty-string check is what keeps the legal links honest: [AppConfig]'s
/// `termsUrl`/`privacyUrl` are dart-defines that default to the real hosted
/// pages but can be built empty, and a link that silently goes nowhere is
/// worse than one the caller has disabled. Callers that can render a disabled
/// state should check `isNotEmpty` themselves and pass a null handler (see
/// `premium_screen.dart`'s footer links) rather than relying on this.
///
/// Extracted from `premium_screen.dart`'s own private copy when the Profile
/// settings list and the onboarding verification screen needed the same
/// thing, so the three cannot drift into three different launch modes.
Future<void> launchExternalUrl(String urlString) async {
  if (urlString.isEmpty) return;
  try {
    await launchUrl(
      Uri.parse(urlString),
      // externalApplication rather than an in-app webview: these are the
      // app's legal pages, and a user checking a privacy policy should be
      // able to see the real address bar and the real domain.
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // Best-effort; see this function's doc comment.
  }
}
