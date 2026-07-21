import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'tab_icons.dart';

/// The four bottom tabs shared by every top-level screen: Today, Trail,
/// Stats, You - with the exact stroke-icon artwork from the designs (see
/// [TabBarIcon]), a soft fade-to-transparent backdrop so content can
/// scroll under it, and the active tab picked out in ink rather than the
/// muted inactive colour.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.currentIndex, required this.onTap});

  /// Index of the selected tab, 0-3 in Today/Trail/Stats/You order.
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = [
      (TabIconShape.today, l10n.navToday),
      (TabIconShape.trail, l10n.navTrail),
      (TabIconShape.stats, l10n.navStats),
      (TabIconShape.you, l10n.navYou),
    ];

    // The tab bar gets dropped in wherever a real shell/screen needs it and
    // must not depend on the caller remembering a `Material` ancestor
    // (without one, the labels fall back to MaterialApp's deliberately-ugly
    // red/yellow-underlined debug style - see AppShell's build() comment).
    // `MaterialType.transparency` fixes text inheritance without painting
    // anything of its own, so it can't cover the gradient fade below.
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AppColors.screenBackground,
              AppColors.screenBackground,
              Color(0x00E9E1D3),
            ],
            stops: [0, 0.6, 1],
          ),
        ),
        child: Padding(
          // Reduced side inset (16 vs the old 40) so each tab's Expanded
          // slot fills the bar with no dead gaps between tabs; the icons
          // still land within ~3px of their previous positions.
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < tabs.length; i++)
                // Expanded so each tab's tappable area spans its full
                // quarter of the bar - taps in the space between icons now
                // register instead of falling into a dead gap.
                Expanded(
                  child: _TabItem(
                    shape: tabs[i].$1,
                    label: tabs[i].$2,
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.shape,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final TabIconShape shape;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.inkStrong : AppColors.textInactive;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // The opaque hit area fills the tab's Expanded slot width; the
        // vertical padding makes it taller than the icon+label alone, so a
        // tap that lands a little high or low still registers.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBarIcon(shape: shape, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                style: selected
                    ? AppTextStyles.tabLabelActive
                    : AppTextStyles.tabLabelInactive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
