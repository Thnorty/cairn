import 'package:flutter/widgets.dart';

import '../theme/app_text_styles.dart';

/// The shared top-left inset for every main tab screen (Home, Trail, Stats,
/// Profile): each screen's outer body [Padding] applies this constant
/// directly as its inset, so the header's on-screen position is structural
/// (one shared value referenced by every screen) rather than a literal
/// duplicated per file, which is how the four screens drifted out of
/// alignment in the first place.
const EdgeInsetsDirectional kScreenEdgePadding =
    EdgeInsetsDirectional.fromSTEB(24, 8, 24, 0);

/// The shared eyebrow+title header content for every main tab screen (Home,
/// Trail, Stats, Profile) - the single source of truth for tab-screen header
/// placement. Before this widget existed each screen hand-rolled its own
/// eyebrow+title `Column`/`Row`, and even with the same outer inset they
/// still drifted on-device (Trail's eyebrow/title lived inside a `Row` with
/// the rank pill, whose height silently pushed the eyebrow down; the others
/// were a plain `Column`). Routing every screen through this one widget
/// fixes that structurally.
///
/// This widget carries no outer padding of its own: the caller's own body
/// [Padding] (using [kScreenEdgePadding]) supplies the inset, so this
/// composes cleanly whether it's the very first thing in the body (Stats,
/// Profile, Trail) or sits below another row (Home's brand row, above this
/// header).
///
/// When [trailing] is supplied (Trail's per-task rank pill), the eyebrow's
/// vertical position must stay identical to the no-trailing case - that
/// silent-shift is exactly the bug this widget fixes. Wrapping in a [Row]
/// with [CrossAxisAlignment.start] guarantees it: the eyebrow+title
/// [Column] and [trailing] both start flush with the row's own top edge, so
/// a tall trailing widget can sit alongside the title without ever pushing
/// the eyebrow down, no matter how tall it is.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
    this.titleStyle,
  });

  /// The small uppercase label above [title] (e.g. "YOUR GROUND", "PROFILE",
  /// "TRAIL OF", or Home's own formatted date line).
  final String eyebrow;

  /// The screen's own title or greeting, directly under [eyebrow].
  final String title;

  /// An optional right-side widget (Trail's per-task rank pill). See this
  /// class's own doc comment for the top-alignment guarantee this provides.
  final Widget? trailing;

  /// Style for [title]; defaults to [AppTextStyles.screenTitle]. Home passes
  /// [AppTextStyles.greeting] instead.
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final eyebrowAndTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(eyebrow, style: AppTextStyles.sectionLabel),
        const SizedBox(height: 4),
        Text(title, style: titleStyle ?? AppTextStyles.screenTitle),
      ],
    );

    final trailingWidget = trailing;
    if (trailingWidget == null) return eyebrowAndTitle;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: eyebrowAndTitle),
        const SizedBox(width: 10),
        trailingWidget,
      ],
    );
  }
}
