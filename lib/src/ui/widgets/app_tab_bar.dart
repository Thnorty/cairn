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

    return DecoratedBox(
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
        padding: const EdgeInsetsDirectional.fromSTEB(40, 12, 40, 26),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < tabs.length; i++)
              _TabItem(
                shape: tabs[i].$1,
                label: tabs[i].$2,
                selected: i == currentIndex,
                onTap: () => onTap(i),
              ),
          ],
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
        child: SizedBox(
          width: 48,
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
