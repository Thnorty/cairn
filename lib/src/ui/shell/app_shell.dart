import 'package:flutter/material.dart' show Material, MaterialPageRoute, MaterialType;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../debug/debug_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../theme/app_text_styles.dart';
import '../theme/screen_background.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/wordmark_glyph.dart';

/// The four-tab app shell: real background, real tab bar, real theme, so
/// each real screen (Home/Trail/Stats/Profile) can drop straight in over
/// the next few runs instead of being built against a bare `Scaffold`.
///
/// Today is the real [HomeScreen] and You is the real [ProfileScreen]
/// (Phase 3); Trail/Stats remain placeholders until their own runs land.
/// Trail, Stats and Profile each have a *different* header treatment in
/// their own design files (see `Cairn Trail.dc.html`/`Cairn Profile.dc.html`),
/// not the wordmark row used here - so [_WordmarkHeader] is only ever shown
/// above a still-placeholder body (Trail/Stats); a real screen always brings
/// its own full header (Home's brand row, in particular, already includes
/// this same [WordmarkGlyph] plus its own controls; Profile's own header is
/// its "PROFILE" label + "You" title) and this shared one is hidden for it
/// instead of stacking two headers.
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
      const _PlaceholderBody(label: 'Trail'),
      const _PlaceholderBody(label: 'Stats'),
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
    // descendant (the wordmark, the placeholder bodies, the tab bar, and
    // whatever real screens land here in Phase 3).
    return Material(
      type: MaterialType.transparency,
      child: ScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
              // TEMPORARY: Phase 1's debug screen (exercises the fake
              // verifier without spending Gemini calls) has no home in the
              // real navigation yet. Long-pressing the wordmark is a
              // stand-in entry point until a real settings/debug affordance
              // exists; remove this once one does. Only shown above a
              // still-placeholder body (Trail/Stats) - see this class's doc
              // comment; index 0 (Home) and index 3 (Profile) both bring
              // their own real header instead.
              if (_index != 0 && _index != 3)
                _WordmarkHeader(onLongPress: _openDebugScreen),
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

class _WordmarkHeader extends StatelessWidget {
  const _WordmarkHeader({required this.onLongPress});

  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 8, 22, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: GestureDetector(
          onLongPress: onLongPress,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WordmarkGlyph(),
              const SizedBox(width: 10),
              Text(l10n.appTitle, style: AppTextStyles.wordmark),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderBody extends StatelessWidget {
  const _PlaceholderBody({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$label - coming soon',
        style: AppTextStyles.body,
      ),
    );
  }
}
