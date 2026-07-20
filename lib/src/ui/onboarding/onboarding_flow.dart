import 'dart:async';

import 'package:flutter/material.dart' show MaterialPageRoute, Text, ScaffoldMessenger, SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import 'onboarding_how_it_works_screen.dart';
import 'onboarding_verification_screen.dart';
import 'onboarding_welcome_screen.dart';

/// Hosts the three first-launch onboarding screens - Welcome
/// ([OnboardingWelcomeScreen]) -\> How It Works
/// ([OnboardingHowItWorksScreen]) -\> Verify
/// ([OnboardingVerificationScreen]) - on their OWN nested [Navigator],
/// rather than pushing them onto the app's root `MaterialApp` navigator.
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
  static const _verificationRoute = '/verification';

  void _showComingSoon(String message) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The "Allow camera" completion path (decision 4 in this run's spec):
  /// entry is never gated on the OS permission prompt's outcome, only on it
  /// having resolved at all - marks onboarding complete, then invalidates
  /// [onboardingCompleteProvider] so [OnboardingGate] rebuilds into
  /// [AppShell], unmounting this whole flow.
  Future<void> _completeOnboarding() async {
    await ref.read(settingsRepositoryProvider).markOnboardingComplete();
    ref.invalidate(onboardingCompleteProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) {
        if (settings.name == _verificationRoute) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => OnboardingVerificationScreen(
              onBack: () => _navigatorKey.currentState!.pop(),
              onAllowCameraComplete: () => unawaited(_completeOnboarding()),
            ),
          );
        }
        if (settings.name == _howItWorksRoute) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => OnboardingHowItWorksScreen(
              onBack: () => _navigatorKey.currentState!.pop(),
              onContinue: () => _navigatorKey.currentState!.pushNamed(_verificationRoute),
            ),
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (routeContext) => OnboardingWelcomeScreen(
            onStartClimbing: () => _navigatorKey.currentState!.pushNamed(_howItWorksRoute),
            onAlreadyHaveAccount: () => _showComingSoon(
              AppLocalizations.of(routeContext)!.onboardingSignInComingSoonSnackbar,
            ),
          ),
        );
      },
    );
  }
}
