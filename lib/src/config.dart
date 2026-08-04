/// Compile-time app configuration, read via `--dart-define` at build time
/// (`String.fromEnvironment`), so a value can be overridden per build
/// without touching source.
///
/// Every default below is a *public* value, safe to ship in the binary, so
/// baking them in lets a plain `flutter run` or release build work out of the
/// box: the Supabase project URL and its publishable (anon) key (row-level
/// security, not secrecy, is what protects data behind them), RevenueCat's
/// public SDK key, and the hosted legal-document URLs.
///
/// Genuine secrets are never here and never ship in the app binary at all.
/// The Gemini API key lives only as an Edge Function secret
/// (`supabase/functions/verify-proof`), read server-side via
/// `Deno.env.get('GEMINI_API_KEY')`; the Google Play service-account JSON and
/// RevenueCat's REST key live only in their respective dashboards.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://cuerjdnznhsdgqbajgvv.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_AWoUlAfC4yTwVHClNohZxw_yfAhsa3g',
  );

  /// Whether both values are present (non-empty). False only if a build
  /// explicitly overrides one of them to an empty string via `--dart-define`;
  /// callers can use this to skip `Supabase.initialize` entirely rather than
  /// pointing the client at a blank URL/key.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Public RevenueCat Android SDK key.
  ///
  /// RevenueCat's *public* SDK keys are designed to ship inside client
  /// binaries (the secret counterpart is the REST key, which never leaves the
  /// dashboard), so this is baked in as a default for the same reason the
  /// Supabase anon key above is: a plain `flutter run` or release build then
  /// works without remembering a flag. Overridable via `--dart-define` for a
  /// different RevenueCat project, or to `''` to force an inert build.
  static const String revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: 'goog_eOzBeHeylWNyEBhLKPxvwvwtlfa',
  );

  /// Whether a RevenueCat API key is configured for subscriptions.
  static bool get isPremiumConfigured => revenueCatApiKey.isNotEmpty;

  /// Public legal-document URLs linked from the Premium paywall footer.
  ///
  /// Both are served from this repo's `docs/` folder via GitHub Pages, so the
  /// hosted copy and the committed source stay in step.
  static const String termsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: 'https://thnorty.github.io/cairn/docs/terms.html',
  );

  static const String privacyUrl = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: 'https://thnorty.github.io/cairn/docs/privacy.html',
  );
}

