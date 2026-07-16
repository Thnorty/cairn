import 'package:flutter/material.dart'
    show Colors, Material, MaterialPageRoute, MaterialType, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../../providers.dart';
import '../../services/cairn_grouping.dart';
import '../../services/points_service.dart';
import '../../services/trail_service.dart';
import '../home/empty_today_view.dart';
import '../new_habit/new_habit_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import '../theme/screen_background.dart';
import '../widgets/cairn_stack.dart';
import '../widgets/ghost_cairn.dart';
import '../widgets/plus_glyph.dart';

/// Opens `NewHabitScreen` on top of the current route - the same navigation
/// Home's own "New habit" pill/Empty Today CTA use (see
/// `home_screen.dart`'s identically-named private helper; duplicated here
/// rather than exported, matching this codebase's existing precedent of
/// small per-screen navigation helpers).
void _openNewHabitScreen(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => const NewHabitScreen(),
  ));
}

/// The Trail screen (`Cairn Trail.dc.html`): a per-task history of "cairns"
/// (see `CLAUDE.md`'s per-task-cairns domain rule and
/// `lib/src/services/cairn_grouping.dart`), rendered as a winding path from
/// the currently-growing cairn at the top down to the trailhead at the
/// bottom.
///
/// All data comes from [trailSnapshotProvider], which stays live (see
/// [TrailService.watchTrail]'s doc comment): a completion recorded
/// elsewhere, or a pending proof resolving in the background, updates this
/// screen with no manual refresh. This screen brings its own fixed header
/// (eyebrow + task title + per-task rank pill) and its own habit-selector
/// chip row, unlike Trail's placeholder predecessor - see [AppShell]'s doc
/// comment on why the shared wordmark header is now hidden for this tab.
class TrailScreen extends ConsumerWidget {
  const TrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(trailSnapshotProvider);

    // Same reasoning as HomeScreen/ProfileScreen's own root Scaffold: this
    // screen drops into AppShell's `IndexedStack` (already under its own
    // transparent `Material`) but must also render correctly standalone (a
    // widget test or the screenshot harness), so it supplies its own
    // transparent one rather than depending on the caller remembering one.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: snapshotAsync.when(
        data: (snapshot) {
          if (snapshot.chips.isEmpty) {
            // No tasks at all, anywhere in the app: the same empty-state
            // illustration/copy Home shows for the identical condition (see
            // this run's spec: "reuse Empty Today's visual language").
            return EmptyTodayView(
              onNewHabit: () => _openNewHabitScreen(context),
            );
          }
          return _TrailScreenBody(snapshot: snapshot, ref: ref);
        },
        // The stream's first emission is effectively synchronous (see
        // HomeService.watchToday's doc comment; TrailService follows the
        // same recipe), so there's no meaningful loading UI to design here.
        loading: () => const SizedBox.shrink(),
        error: (error, stackTrace) => Center(child: Text('$error')),
      ),
    );
  }
}

class _TrailScreenBody extends StatelessWidget {
  const _TrailScreenBody({required this.snapshot, required this.ref});

  final TrailSnapshot snapshot;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TrailHeader(
          taskTitle: snapshot.selectedTaskTitle!,
          rank: snapshot.rank,
          altitude: snapshot.altitude,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 2),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final chip in snapshot.chips) ...[
                  _HabitChip(
                    title: chip.title,
                    selected: chip.taskId == snapshot.selectedTaskId,
                    onTap: () => ref
                        .read(selectedTrailTaskIdProvider.notifier)
                        .state = chip.taskId,
                  ),
                  const SizedBox(width: 8),
                ],
                _AddHabitChip(
                  onTap: () => _openNewHabitScreen(context),
                  semanticLabel: l10n.newHabitButton,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _TrailBody(
            cairns: snapshot.cairns,
            taskTitle: snapshot.selectedTaskTitle!,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header: eyebrow + task title + per-task rank pill
// ---------------------------------------------------------------------------

class _TrailHeader extends StatelessWidget {
  const _TrailHeader({
    required this.taskTitle,
    required this.rank,
    required this.altitude,
  });

  final String taskTitle;
  final Rank rank;
  final int altitude;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.trailHeaderEyebrow, style: AppTextStyles.sectionLabel),
                const SizedBox(height: 4),
                Text(taskTitle, style: AppTextStyles.screenTitle),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RankPill(
            rank: rank,
            metresText: l10n.trailRankMetresLabel(formatMetresNumber(altitude, locale)),
          ),
        ],
      ),
    );
  }
}

class _RankPill extends StatelessWidget {
  const _RankPill({required this.rank, required this.metresText});

  final Rank rank;
  final String metresText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 9, 14, 9),
      decoration: BoxDecoration(
        gradient: AppGradients.circleInactive,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.panelBorder),
        boxShadow: AppShadows.trailRankPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: AppGradients.heroBadge,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const _MountainGlyph(),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(rank.tier.label, style: AppTextStyles.trailRankPillTier),
              Text(metresText, style: AppTextStyles.trailRankPillMetres),
            ],
          ),
        ],
      ),
    );
  }
}

/// The rank pill's mountain glyph (`M3 19l5.5-9 3.5 5 2-3 6.5 7z`) - the
/// same path Profile's own rank-hero badge draws, duplicated privately here
/// rather than shared, matching this codebase's existing precedent for
/// small one-off glyph painters (e.g. `_ChevronRightPainter` in
/// `new_habit_recurrence_panel.dart`, noted in `profile_screen.dart`'s own
/// doc comment).
class _MountainGlyph extends StatelessWidget {
  const _MountainGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 17,
      height: 17,
      child: CustomPaint(painter: _MountainGlyphPainter()),
    );
  }
}

class _MountainGlyphPainter extends CustomPainter {
  const _MountainGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final paint = Paint()
      ..color = AppColors.heroMountainStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(p(3, 19).dx, p(3, 19).dy)
      ..lineTo(p(8.5, 10).dx, p(8.5, 10).dy)
      ..lineTo(p(12, 15).dx, p(12, 15).dy)
      ..lineTo(p(14, 12).dx, p(14, 12).dy)
      ..lineTo(p(20.5, 19).dx, p(20.5, 19).dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MountainGlyphPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Habit selector chips
// ---------------------------------------------------------------------------

class _HabitChip extends StatelessWidget {
  const _HabitChip({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.pill);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        selected: selected,
        label: title,
        // Every reusable chip/button in this app wraps itself in a
        // transparent Material (see `buttons.dart`'s `_Pressable` doc
        // comment) so it never depends on its host remembering one.
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            padding: selected
                ? const EdgeInsetsDirectional.fromSTEB(11, 8, 14, 8)
                : const EdgeInsetsDirectional.symmetric(
                    horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.inkStrong : null,
              gradient: selected ? null : AppGradients.circleInactive,
              borderRadius: radius,
              border:
                  selected ? null : Border.all(color: AppColors.circleBorder),
              boxShadow: selected ? AppShadows.trailSelectedChip : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const _StackedPebbleGlyph(),
                  const SizedBox(width: 7),
                ],
                Text(
                  title,
                  style: selected
                      ? AppTextStyles.trailChipLabelSelected
                      : AppTextStyles.trailChipLabelUnselected,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The selected chip's small stacked-pebble glyph: three plain rounded bars,
/// matching the source file's three nested `<span>`s rather than an SVG
/// path - the same "plain divs, not a real icon" treatment this codebase
/// already uses for other tiny decorative bits (e.g. `_PremiumMountainBars`
/// in `profile_screen.dart`, `_SummaryDot` in `home_screen.dart`).
class _StackedPebbleGlyph extends StatelessWidget {
  const _StackedPebbleGlyph();

  // (width, height, colour) verbatim from the design's three stacked spans.
  // The first colour matches AppColors.heroLabelSage (#c2cdae) exactly; the
  // other two have no existing token (single use), kept as local literals
  // per this file's own precedent for one-off decorative colours.
  static const _stones = [
    (width: 7.0, height: 3.0, color: AppColors.heroLabelSage),
    (width: 11.0, height: 4.0, color: Color(0xFFA9B78E)),
    (width: 14.0, height: 4.0, color: Color(0xFF93A473)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final stone in _stones)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 0.5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: stone.color,
                borderRadius: BorderRadius.circular(stone.height / 2),
              ),
              child: SizedBox(width: stone.width, height: stone.height),
            ),
          ),
      ],
    );
  }
}

class _AddHabitChip extends StatelessWidget {
  const _AddHabitChip({required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          type: MaterialType.transparency,
          child: CustomPaint(
            painter: const _DashedChipBorderPainter(),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 13, vertical: 8),
              child: PlusGlyph(color: AppColors.textFaint, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rect border for the trailing "+" chip, using the same
/// path-metrics dashing technique as `ghost_cairn.dart`'s
/// `_DashedPebblePainter`.
class _DashedChipBorderPainter extends CustomPainter {
  const _DashedChipBorderPainter();

  static const double _dashLength = 4;
  static const double _gapLength = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.scheduledPillBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(AppRadii.pill),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedChipBorderPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// The winding trail body
// ---------------------------------------------------------------------------

/// The scrollable trail: the selected task's cairns as a winding path,
/// newest/growing at the top, the trailhead at the bottom ("scroll down =
/// back in time"). Data-driven for any number of cairns: layout is derived
/// from fixed per-node spacing/alternation rather than the design's
/// hardcoded pixel coordinates, reproducing its visual language (a parchment
/// wash, a topo contour overlay, a winding dashed connector threading
/// through alternating left/right anchor points) instead.
class _TrailBody extends StatelessWidget {
  const _TrailBody({required this.cairns, required this.taskTitle});

  final List<TaskCairn> cairns;
  final String taskTitle;

  /// Vertical space above the first (newest) node.
  static const double _topPad = 40;

  /// Vertical distance between consecutive nodes.
  static const double _rowSpacing = 230;

  /// How far below each node's own top the winding path's anchor point
  /// sits (roughly the node's own visual centre).
  static const double _anchorYOffset = 78;

  /// Extra vertical gap between the last (trailhead) node and the "WHERE
  /// YOU STARTED" marker below it.
  static const double _markerGap = 96;

  static const double _bottomPadding = 56;

  /// Horizontal placement as a 0..1 fraction of the available width: the
  /// topmost (newest/growing) node sits centred; every node after that
  /// alternates left/right, matching the design's own zigzag sequence.
  static double _xFractionFor(int displayIndex) {
    if (displayIndex == 0) return 0.5;
    return displayIndex.isOdd ? 0.24 : 0.62;
  }

  @override
  Widget build(BuildContext context) {
    if (cairns.isEmpty) {
      return _EmptyTrailBody(taskTitle: taskTitle);
    }

    // cairnsFor returns oldest-first (index 1 = trailhead); the screen
    // displays newest at the top, so this is the one place that reverses it.
    final display = cairns.reversed.toList();
    final n = display.length;
    final contentHeight =
        _topPad + (n - 1) * _rowSpacing + _markerGap + _bottomPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final anchors = [
          for (var i = 0; i < n; i++)
            Offset(
              _xFractionFor(i) * width,
              _topPad + i * _rowSpacing + _anchorYOffset,
            ),
        ];

        return SingleChildScrollView(
          child: SizedBox(
            width: width,
            height: contentHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: AppGradients.trailBackground),
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.5,
                    child: CustomPaint(
                      painter: TopographicContourPainter(
                        origin: const Alignment(0.2, -0.88),
                        ringSpacing: 30,
                        ringColor: const Color(0x0D5A6448),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _WindingTrailPainter(anchors: anchors)),
                ),
                for (var i = 0; i < n; i++)
                  Positioned(
                    top: _topPad + i * _rowSpacing,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment(_xFractionFor(i) * 2 - 1, 0),
                      child: _CairnNode(cairn: display[i], taskTitle: taskTitle),
                    ),
                  ),
                Positioned(
                  top: _topPad + (n - 1) * _rowSpacing + _markerGap,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.trailWhereYouStartedLabel,
                      style: AppTextStyles.trailWhereYouStartedLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Draws the winding dashed path threading through [anchors] (top to
/// bottom): a wide, sparsely-dashed background stroke plus a thin
/// continuous overlay, matching `Cairn Trail.dc.html`'s two stacked
/// `<path>` layers. Anchors are joined with cubic Beziers whose control
/// points swing through the midpoint between each pair, producing the same
/// gentle S-curve sway the design's own hand-authored path has, without
/// depending on its literal coordinates.
class _WindingTrailPainter extends CustomPainter {
  const _WindingTrailPainter({required this.anchors});

  final List<Offset> anchors;

  // `#cabfa9` at ~.85 alpha and `#d8cfbd` at ~.5 alpha - single-use literals
  // (not AppColors tokens), matching this codebase's precedent for a
  // decorative painter's own private palette (e.g.
  // `_DiagonalStripesPainter` in `home_occurrence_card.dart`).
  static const Color _wideStroke = Color(0xD9CABFA9);
  static const Color _thinStroke = Color(0x80D8CFBD);

  @override
  void paint(Canvas canvas, Size size) {
    if (anchors.length < 2) return;
    final path = _buildPath();

    final widePaint = Paint()
      ..color = _wideStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    _drawDashed(canvas, path, widePaint, dash: 1, gap: 26);

    final thinPaint = Paint()
      ..color = _thinStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, thinPaint);
  }

  Path _buildPath() {
    final path = Path()..moveTo(anchors.first.dx, anchors.first.dy);
    for (var i = 0; i < anchors.length - 1; i++) {
      final p0 = anchors[i];
      final p1 = anchors[i + 1];
      final midY = (p0.dy + p1.dy) / 2;
      path.cubicTo(p0.dx, midY, p1.dx, midY, p1.dx, p1.dy);
    }
    return path;
  }

  void _drawDashed(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WindingTrailPainter oldDelegate) =>
      anchors != oldDelegate.anchors;
}

// ---------------------------------------------------------------------------
// Cairn nodes
// ---------------------------------------------------------------------------

class _CairnNode extends StatelessWidget {
  const _CairnNode({required this.cairn, required this.taskTitle});

  final TaskCairn cairn;
  final String taskTitle;

  @override
  Widget build(BuildContext context) {
    switch (cairn.status) {
      case CairnStatus.growing:
        return _GrowingCairnNode(cairn: cairn, taskTitle: taskTitle);
      case CairnStatus.capped:
        return _SettledCairnNode(cairn: cairn, broken: false);
      case CairnStatus.broken:
        return _SettledCairnNode(cairn: cairn, broken: true);
    }
  }
}

class _GrowingCairnNode extends StatelessWidget {
  const _GrowingCairnNode({required this.cairn, required this.taskTitle});

  final TaskCairn cairn;
  final String taskTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    return SizedBox(
      width: 160,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _GrowingBadge(label: l10n.trailGrowingNowBadge),
          const SizedBox(height: 6),
          cairn.stoneCount == 0
              ? const GhostCairnStack()
              : CairnStack(stoneCount: cairn.stoneCount, highlightTop: true),
          const SizedBox(height: 8),
          Text(
            taskTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.trailGrowingTaskTitle,
          ),
          // The trailhead override replaces the usual "Cairn N · N stones"
          // caption for index 1 - see `_SettledCairnNode`'s identical
          // override and this run's report for the judgment call.
          if (cairn.isTrailhead)
            Text(
              l10n.trailTrailheadCaption(
                formatShortMonthDay(cairn.firstStoneDate!, locale),
              ),
              style: AppTextStyles.trailCairnCaption,
            )
          else
            Text(
              l10n.trailCairnStoneCount(cairn.index, cairn.stoneCount),
              style: AppTextStyles.trailGrowingCaption,
            ),
        ],
      ),
    );
  }
}

class _GrowingBadge extends StatelessWidget {
  const _GrowingBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.sageChipBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: AppTextStyles.trailGrowingBadgeLabel),
    );
  }
}

/// A capped or broken cairn (never both, and never 0 stones - see
/// [CairnGrouping.cairnsFor]'s own guarantee that a capped/broken entry
/// always carries at least one stone).
class _SettledCairnNode extends StatelessWidget {
  const _SettledCairnNode({required this.cairn, required this.broken});

  final TaskCairn cairn;
  final bool broken;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    final Widget caption;
    if (cairn.isTrailhead) {
      caption = Text(
        l10n.trailTrailheadCaption(
          formatShortMonthDay(cairn.firstStoneDate!, locale),
        ),
        style: AppTextStyles.trailCairnCaption,
      );
    } else if (broken) {
      caption = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LightningGlyph(),
          const SizedBox(width: 4),
          Text(
            l10n.trailBrokenCaption(cairn.stoneCount),
            style: AppTextStyles.trailBrokenCaption,
          ),
        ],
      );
    } else {
      caption = Text(
        l10n.trailCappedCaption(cairn.stoneCount),
        style: AppTextStyles.trailCairnCaption,
      );
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // mutedOpacity: false - the outer Opacity below reproduces the
        // design's single flat `opacity:.52` over the *whole* node (stack
        // and text alike), so CairnStack's own internal stack-only fade
        // (its default `mutedOpacity: true`) would double up otherwise.
        CairnStack(stoneCount: cairn.stoneCount, muted: broken, mutedOpacity: false),
        const SizedBox(height: 8),
        Text(
          l10n.trailCairnLabel(cairn.index),
          style: broken
              ? AppTextStyles.trailBrokenCairnTitleStyle
              : AppTextStyles.trailCairnTitle,
        ),
        const SizedBox(height: 1),
        caption,
      ],
    );

    return broken ? Opacity(opacity: 0.52, child: content) : content;
  }
}

/// The broken cairn's small lightning-bolt glyph
/// (`M13 3l-2 8h6l-8 10 2-8H5z`).
class _LightningGlyph extends StatelessWidget {
  const _LightningGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 10,
      height: 10,
      child: CustomPaint(painter: _LightningGlyphPainter()),
    );
  }
}

class _LightningGlyphPainter extends CustomPainter {
  const _LightningGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final paint = Paint()
      ..color = AppColors.textFaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(p(13, 3).dx, p(13, 3).dy)
      ..lineTo(p(11, 11).dx, p(11, 11).dy)
      ..lineTo(p(17, 11).dx, p(17, 11).dy)
      ..lineTo(p(9, 21).dx, p(9, 21).dy)
      ..lineTo(p(11, 13).dx, p(11, 13).dy)
      ..lineTo(p(5, 13).dx, p(5, 13).dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LightningGlyphPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Empty trail (task exists but has zero stones yet)
// ---------------------------------------------------------------------------

class _EmptyTrailBody extends StatelessWidget {
  const _EmptyTrailBody({required this.taskTitle});

  final String taskTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GhostCairnStack(),
            const SizedBox(height: 18),
            Text(
              l10n.trailEmptyTrailBody,
              textAlign: TextAlign.center,
              style: AppTextStyles.emptyStateBody,
            ),
            const SizedBox(height: 22),
            Text(
              l10n.trailWhereYouStartedLabel,
              style: AppTextStyles.trailWhereYouStartedLabel,
            ),
          ],
        ),
      ),
    );
  }
}
