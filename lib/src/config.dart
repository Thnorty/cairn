/// Compile-time app configuration, read via `--dart-define` at build time
/// (`String.fromEnvironment`), so a value can be overridden per build
/// without touching source.
///
/// The defaults below are this Cairn project's public Supabase values: the
/// project URL and its publishable (anon) key are not secrets by design
/// (row-level security, not secrecy, is what protects data behind them), so
/// baking them in as defaults lets a plain `flutter run` work out of the
/// box. The Gemini API key is never here and never ships in the app binary
/// at all: it lives only as an Edge Function secret
/// (`supabase/functions/verify-proof`), read server-side via
/// `Deno.env.get('GEMINI_API_KEY')`.
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

  /// Public RevenueCat API key read via `--dart-define`.
  ///
  /// RevenueCat public keys are safe to embed in client binaries. Defaulted to
  /// empty so an unconfigured build stays inert; a configured build supplies
  /// it via `--dart-define` or bakes the key in a later step.
  static const String revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: '',
  );

  /// Whether a RevenueCat API key is configured for subscriptions.
  static bool get isPremiumConfigured => revenueCatApiKey.isNotEmpty;

  static const String termsUrl = String.fromEnvironment('TERMS_URL', defaultValue: '');
  static const String privacyUrl = String.fromEnvironment('PRIVACY_URL', defaultValue: '');
}

