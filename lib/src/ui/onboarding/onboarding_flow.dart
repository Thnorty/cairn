import 'dart:async';

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../account/account_flow.dart';
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
