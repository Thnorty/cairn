import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/generated/app_localizations.dart';
import 'src/config.dart';
import 'src/providers.dart';
import 'src/ui/onboarding/onboarding_gate.dart';
import 'src/ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Offline first launch (or any other init failure) must not block the
  // app: the local-first pipeline works fine with a null user id, and
  // authBootstrapProvider retries ensureSignedIn/backfill on every launch
  // once connectivity returns. See AuthService's doc comment.
  if (AppConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
    } catch (_) {
      // Swallowed: see comment above.
    }
  }

  runApp(const ProviderScope(child: CairnApp()));
}

/// App root. A [ConsumerWidget] so it can watch [proofRetryTriggerProvider],
/// [authBootstrapProvider], and [syncTriggerProvider]: all three are lazy
/// [Provider]s, so nothing constructs the pending-verification retry
/// trigger or the sync trigger (and starts their lifecycle
/// listener/connectivity subscriptions), nor kicks off anonymous sign-in and
/// the user_id backfill, until something watches them. The app root is the
/// one place guaranteed to build for the whole lifetime of the running app.
///
/// Deliberately not wired into `test/widget_test.dart`: that test pumps
/// `MaterialApp(home: DebugScreen())` directly rather than [CairnApp], so
/// watching any of these providers here never touches that test and never
/// drags connectivity_plus's platform channel, or a real Supabase auth call,
/// into it.
class CairnApp extends ConsumerWidget {
  const CairnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(proofRetryTriggerProvider);
    ref.watch(authBootstrapProvider);
    ref.watch(syncTriggerProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // System locale only for now: no in-app language picker yet (that's a
      // Profile-screen decision for a later phase).
      theme: AppTheme.light,
      home: const OnboardingGate(),
    );
  }
}
