import 'package:flutter/material.dart' show Material, MaterialPageRoute, MaterialType;
import 'package:flutter/widgets.dart';

import '../../debug/debug_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../stats/stats_screen.dart';
import '../theme/screen_background.dart';
import '../trail/trail_screen.dart';
import '../widgets/app_tab_bar.dart';

/// The four-tab app shell: real background, real tab bar, real theme, and
/// (as of this run) all four real screens - Today is [HomeScreen], Trail is
/// [TrailScreen], Stats is [StatsScreen], You is [ProfileScreen].
///
/// Every tab now brings its own full header from its own canonical design
/// file (Home's brand row; Trail's "TRAIL OF" eyebrow + task title + rank
/// pill; Stats' "YOUR GROUND" eyebrow + "Stats" title; Profile's "PROFILE"
/// label + "You" title) instead of a shared one, so this shell no longer
/// paints any header of its own: the build below is just the tab bodies in
/// an `IndexedStack` plus the tab bar.
///
/// TEMPORARY: Phase 1's debug screen (exercises the fake verifier without
/// spending Gemini calls) has no home in the real navigation yet.
/// Long-pressing the wordmark on HomeScreen's own brand row is a stand-in
/// entry point until a real settings/debug affordance exists - see
/// [HomeScreen.onOpenDebug], wired below via [_openDebugScreen]; remove both
/// once a real entry point exists.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _openDebugScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DebugScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final bodies = [
      HomeScreen(onOpenDebug: _openDebugScreen),
      const TrailScreen(),
      const StatsScreen(),
      const ProfileScreen(),
    ];

    // `MaterialApp` (see main.dart) deliberately gives its root
    // `DefaultTextStyle` an ugly red/yellow-double-underlined debug style
    // to flag `Text` with no `Material` ancestor (see
    // MaterialApp's "Why is my app's text red with yellow underlines?"
    // troubleshooting doc). `Material.textStyle` merges over that with a
    // real theme-derived style. `MaterialType.transparency` paints
    // nothing of its own - no fill, no elevation, no shape - so it can't
    // cover `ScreenBackground`'s parchment colour/washes/contour beneath
    // it; it exists purely to fix text/ink inheritance for every
    // descendant (the tab bar and whatever each real screen paints).
    return Material(
      type: MaterialType.transparency,
      child: ScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(index: _index, children: bodies),
              ),
              AppTabBar(
                currentIndex: _index,
                onTap: (i) => setState(() => _index = i),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
