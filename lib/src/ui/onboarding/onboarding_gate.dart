import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../shell/app_shell.dart';
import '../theme/app_colors.dart';
import 'onboarding_flow.dart';

/// The app's root route, used as `CairnApp`'s `MaterialApp.home`: reads
/// [onboardingCompleteProvider] and shows [OnboardingFlow] until the
/// first-launch onboarding flow is complete, then [AppShell] from then on.
///
/// Fails OPEN to [AppShell] on a read error (never traps the user behind a
/// broken settings read), and shows a plain parchment-coloured placeholder
/// while the (near-instant, local-only) read is in flight rather than a
/// spinner - see this run's spec.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingComplete = ref.watch(onboardingCompleteProvider);
    return onboardingComplete.when(
      data: (done) => done ? const AppShell() : const OnboardingFlow(),
      loading: () => const ColoredBox(
        color: AppColors.screenBackground,
        child: SizedBox.expand(),
      ),
      error: (_, __) => const AppShell(),
    );
  }
}
