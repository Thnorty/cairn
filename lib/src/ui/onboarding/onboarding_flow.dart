import 'dart:async';

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../account/account_flow.dart';
import 'onboarding_how_it_works_screen.dart';
import 'onboarding_name_screen.dart';
import 'onboarding_notifications_screen.dart';
import 'onboarding_verification_screen.dart';
import 'onboarding_welcome_screen.dart';

/// Hosts the five first-launch onboarding screens - Welcome
/// ([OnboardingWelcomeScreen]) -\> How It Works
/// ([OnboardingHowItWorksScreen]) -\> Your Name ([OnboardingNameScreen]) -\>
/// Verify ([OnboardingVerificationScreen]) -\> Reminders
/// ([OnboardingNotificationsScreen]) - on their OWN nested [Navigator],
/// rather than pushing them onto the app's root `MaterialApp` navigator.
///
/// The two permission asks are deliberately separate steps in this order:
/// the camera grant is load-bearing (without it the app cannot do its one
/// job) and is framed by "how verification works", while reminders are
/// genuinely optional. Camera first also means the more important grant is
/// asked for while attention is freshest. See
/// `Cairn Onboarding Notifications.dc.html`'s header comment.
///
/// This matters for [OnboardingGate]: completing onboarding swaps the
/// gate's `home:` from this widget to [AppShell] by invalidating
/// [onboardingCompleteProvider]. If any of these screens had instead been
/// pushed on the ROOT navigator, that swap would leave it sitting on the
/// root route stack underneath the new [AppShell] route, reachable by an
/// errant back-gesture. Keeping the whole flow on its own nested Navigator
/// means the gate's rebuild unmounts this entire subtree - route stack
/// included - in one step, exactly like closing a self-contained mini-app.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  static const _howItWorksRoute = '/how-it-works';
  static const _nameRoute = '/name';
  static const _verificationRoute = '/verification';
  static const _notificationsRoute = '/notifications';

  /// Completing the flow: marks onboarding complete, then invalidates
  /// [onboardingCompleteProvider] so [OnboardingGate] rebuilds into
  /// [AppShell], unmounting this whole flow.
  ///
  /// Neither permission step gates entry on its prompt's outcome, only on it
  /// having resolved (or been skipped) - see each screen's own doc comment.
  Future<void> _completeOnboarding() async {
    await ref.read(settingsRepositoryProvider).markOnboardingComplete();
    ref.invalidate(onboardingCompleteProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) {
        if (settings.name == _notificationsRoute) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => OnboardingNotificationsScreen(
              onBack: () => _navigatorKey.currentState!.pop(),
              onComplete: () => unawaited(_completeOnboarding()),
            ),
          );
        }
        if (settings.name == _verificationRoute) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => OnboardingVerificationScreen(
              onBack: () => _navigatorKey.currentState!.pop(),
              onCameraPermissionResolved: () =>
                  _navigatorKey.currentState!.pushNamed(_notificationsRoute),
            ),
          );
        }
        if (settings.name == _nameRoute) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => OnboardingNameScreen(
              onBack: () => _navigatorKey.currentState!.pop(),
              onSubmit: () => _navigatorKey.currentState!.pushNamed(_verificationRoute),
            ),
          );
        }
        if (settings.name == _howItWorksRoute) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => OnboardingHowItWorksScreen(
              onBack: () => _navigatorKey.currentState!.pop(),
              onContinue: () => _navigatorKey.currentState!.pushNamed(_nameRoute),
            ),
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => OnboardingWelcomeScreen(
            onStartClimbing: () => _navigatorKey.currentState!.pushNamed(_howItWorksRoute),
            // Pushes the full account flow (Sign in first) on THIS SAME
            // nested Navigator, per this run's spec. AccountFlow's
            // onComplete marks onboarding complete and hands off to
            // AppShell (via onboardingCompleteProvider) on a successful
            // sign-in; a plain close-via-X just pops back to this welcome
            // screen, same as any other pushed route here.
            onAlreadyHaveAccount: () => _navigatorKey.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => AccountFlow(
                  start: AccountEntryPoint.signIn,
                  onComplete: () => unawaited(_completeOnboarding()),
                ),
              ),
            ),
            showAlreadyHaveAccount: ref.watch(accountFeatureAvailableProvider),
          ),
        );
      },
    );
  }
}
