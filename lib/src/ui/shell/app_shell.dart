import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';

import '../../debug/debug_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/screen_background.dart';
import '../widgets/app_tab_bar.dart';

/// The four-tab app shell: real background, real tab bar, real theme, so
/// each real screen (Home/Trail/Stats/Profile) can drop straight in over
/// the next few runs instead of being built against a bare `Scaffold`.
///
/// Bodies are placeholders until their own run lands; only the chrome
/// (background, wordmark header, tab bar) is real here.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _placeholders = [
    _PlaceholderBody(label: 'Today'),
    _PlaceholderBody(label: 'Trail'),
    _PlaceholderBody(label: 'Stats'),
    _PlaceholderBody(label: 'You'),
  ];

  void _openDebugScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DebugScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return ScreenBackground(
      child: SafeArea(
        child: Column(
          children: [
            // TEMPORARY: Phase 1's debug screen (exercises the fake
            // verifier without spending Gemini calls) has no home in the
            // real navigation yet. Long-pressing the wordmark is a
            // stand-in entry point until a real settings/debug affordance
            // exists; remove this once one does.
            _WordmarkHeader(onLongPress: _openDebugScreen),
            Expanded(
              child: IndexedStack(index: _index, children: _placeholders),
            ),
            AppTabBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
            ),
          ],
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
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 8, 22, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: GestureDetector(
          onLongPress: onLongPress,
          behavior: HitTestBehavior.opaque,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WordmarkGlyph(),
              SizedBox(width: 10),
              Text('Cairn', style: AppTextStyles.wordmark),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tiny stacked-blob brand mark next to the "Cairn" wordmark. Unlike
/// [CairnStack] (the tan-stone illustration used for task progress) this
/// is a fixed 3-blob monochrome ink mark, so it's kept as a private
/// one-off here rather than a reusable component.
class _WordmarkGlyph extends StatelessWidget {
  const _WordmarkGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 38,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _blob(11, 8, AppColors.inkDimmed),
          const SizedBox(height: 1),
          _blob(17, 9, AppColors.iconMuted),
          const SizedBox(height: 1),
          _blob(24, 10, AppColors.inkStrong),
        ],
      ),
    );
  }

  Widget _blob(double width, double height, Color color) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height),
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
