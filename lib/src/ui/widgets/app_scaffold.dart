import 'package:flutter/material.dart' show Colors, Scaffold;
import 'package:flutter/widgets.dart';

import '../theme/screen_background.dart';

/// The pushed/modal screen family's shared outer wrapper:
/// `Scaffold(backgroundColor: Colors.transparent)` around a
/// [ScreenBackground] around a `SafeArea` around [child].
///
/// Every modal-style screen in this app (Premium, the three onboarding
/// steps, New Habit, Camera Unavailable) hand-rolled this exact
/// three-layer wrapper, differing only in which washes/contour tint they
/// pass to [ScreenBackground] - this widget is the single source of truth
/// for that wrapper so a screen only has to state its own tint. [washes]
/// is required (every one of today's call sites overrides it; there is no
/// sensible shared default across such differently-tinted screens);
/// [showContour]/[contourOrigin]/[contourRingColor] default to
/// [ScreenBackground]'s own defaults, matching the screens (New Habit)
/// that never overrode them.
///
/// [child] is everything each screen used to put directly inside its own
/// `SafeArea` (typically a `Column` of header + scrollable body + footer) -
/// unchanged by this widget, so every screen keeps its own header/footer/
/// padding exactly as before; only the repeated outer wrapper moves here.
///
/// The proof-outcome screens (Verify Result/Failed/Failed - No
/// Retries/Pending, Daily Limit) do not use this widget directly: they
/// share a further layer of chrome (`VerificationHeader`/
/// `VerificationFooter`) on top of this same three-layer wrapper, factored
/// as `ProofOutcomeScaffold` in `proof/verification_chrome.dart`, which
/// itself builds on this widget.
class ModalScaffold extends StatelessWidget {
  const ModalScaffold({
    super.key,
    required this.washes,
    this.showContour = true,
    this.contourOrigin = const Alignment(0.68, -0.92),
    this.contourRingColor = const Color(0x0D463C2C),
    required this.child,
  });

  /// [ScreenBackground.washes].
  final List<RadialGradient> washes;

  /// [ScreenBackground.showContour].
  final bool showContour;

  /// [ScreenBackground.contourOrigin].
  final Alignment contourOrigin;

  /// [ScreenBackground.contourRingColor].
  final Color contourRingColor;

  /// The screen's own content, placed directly inside the shared
  /// `SafeArea` - exactly what each screen used to nest there itself.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenBackground(
        washes: washes,
        showContour: showContour,
        contourOrigin: contourOrigin,
        contourRingColor: contourRingColor,
        child: SafeArea(child: child),
      ),
    );
  }
}

/// The tab family's shared outer wrapper: a transparent `Scaffold` whose
/// body is either [child] alone (Home/Profile: [AppShell] already paints
/// the shared [ScreenBackground] beneath the whole tab strip, so these two
/// screens have no background of their own to add) or [child] stacked on
/// top of an opaque, full-bleed [background] (Stats/Trail: each paints its
/// own continuous wash + contour behind its entire screen - see
/// `_StatsScreenBackground`/`_TrailScreenBackground` in their own files -
/// to hide [AppShell]'s Home-tuned washes rather than layering on top of
/// them).
///
/// Every one of the four tab screens hand-rolled this exact
/// `Scaffold(backgroundColor: Colors.transparent, body: ...)` wrapper (see
/// each screen's own doc comment on why it supplies its own `Scaffold`:
/// rendering correctly both inside [AppShell]'s `IndexedStack` and
/// standalone in a widget test/screenshot harness); this widget is the
/// single source of truth for it.
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, this.background, required this.child});

  /// An opaque, full-bleed background painted behind [child], or null when
  /// the screen relies on an ancestor for its background instead (here,
  /// always [AppShell]'s own [ScreenBackground]).
  final Widget? background;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: background == null
          ? child
          : Stack(children: [Positioned.fill(child: background!), child]),
    );
  }
}
