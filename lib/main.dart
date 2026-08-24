import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/generated/app_localizations.dart';
import 'src/config.dart';
import 'src/providers.dart';
import 'src/ui/onboarding/onboarding_gate.dart';
import 'src/ui/theme/app_theme.dart';
import 'src/ui/widgets/cairn_stack.dart' show StoneStyleScope;

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

  if (AppConfig.isPremiumConfigured) {
    try {
      await Purchases.configure(
        PurchasesConfiguration(AppConfig.revenueCatApiKey),
      );
    } catch (_) {
      // Swallowed: billing init failure must not block app launch.
    }
  }

  runApp(const ProviderScope(child: CairnApp()));
}

/// App root. A [ConsumerWidget] so it can watch [proofRetryTriggerProvider],
/// [authBootstrapProvider], [syncTriggerProvider], and
/// [notificationTriggerProvider]: all four are lazy [Provider]s, so nothing
/// constructs the pending-verification retry trigger, the sync trigger, or
/// the notification-replan trigger (and starts their lifecycle
/// listener/connectivity/database subscriptions), nor kicks off anonymous
/// sign-in and the user_id backfill, until something watches them. The app
/// root is the one place guaranteed to build for the whole lifetime of the
/// running app.
///
/// The notification-tap route is deliberately NOT wired here: it hangs off
/// [OnboardingGate]'s post-onboarding branch instead, so a tap can never
/// drop a first-launch user into the camera mid-onboarding (see
/// [NotificationTapListener]).
///
/// Deliberately not wired into `test/widget_test.dart`: that test pumps
/// `MaterialApp(home: DebugScreen())` directly rather than [CairnApp], so
/// watching any of these providers here never touches that test and never
/// drags connectivity_plus's platform channel, or a real Supabase auth call,
/// into it.
///
/// Also installs [StoneStyleScope] (Phase 5's "Stone Styles" feature), fed
/// from `effectiveStoneStyleProvider`: the single Riverpod touch point that
/// feature needs, so every [CairnStack] beneath it (i.e. every real screen)
/// themes automatically with no further wiring - see that scope's own doc
/// comment.
class CairnApp extends ConsumerWidget {
  const CairnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(proofRetryTriggerProvider);
    ref.watch(authBootstrapProvider);
    ref.watch(syncTriggerProvider);
    ref.watch(notificationTriggerProvider);
    ref.watch(widgetTriggerProvider);
    final stoneStyle = ref.watch(effectiveStoneStyleProvider);
    return StoneStyleScope(
      style: stoneStyle,
      child: MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // System locale only for now: no in-app language picker yet (that's
        // a Profile-screen decision for a later phase).
        theme: AppTheme.light,
        home: const OnboardingGate(),
      ),
    );
  }
}
