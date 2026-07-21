import 'package:flutter/material.dart'
    show Material, MaterialPageRoute, MaterialType;
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
import '../widgets/app_scaffold.dart';
import '../widgets/cairn_stack.dart';
import '../widgets/ghost_cairn.dart';
import '../widgets/glyphs.dart';
import '../widgets/plus_glyph.dart';
import '../widgets/screen_header.dart';

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
/// (eyebrow + task title + the global rank pill - see this run's report on
/// why it's app-wide, not per-task) and its own habit-selector chip row,
/// unlike Trail's placeholder predecessor - see [AppShell]'s doc comment on
/// why the shared wordmark header is now hidden for this tab.
///
/// The whole screen (fixed header, chip row and the scrollable body) is
/// transparent, so it sits on `AppShell`'s shared `ScreenBackground` (the
/// same parchment + warm-clay/sage washes + contour Home and Profile show)
/// exactly like the other tabs - switching to Trail no longer changes the
/// backdrop. Nothing here paints an opaque fill of its own, so that one
/// shared background reads as a single unbroken surface (no header/body
/// seam), which is why Trail previously needed a full-bleed layer but no
/// longer does.
class TrailScreen extends ConsumerWidget {
  const TrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(trailSnapshotProvider);

    // Same reasoning as HomeScreen/ProfileScreen's own [AppScaffold]: this
    // screen drops into AppShell's `IndexedStack` (already under its own
    // transparent `Material`) but must also render correctly standalone (a
    // widget test or the screenshot harness), so it supplies its own
    // transparent one rather than depending on the caller remembering one -
    // see [AppScaffold]'s own doc comment.
    return AppScaffold(
      // No background override: the Trail uses AppShell's shared
      // ScreenBackground, the same parchment + washes + contour Home and
      // Profile show, so switching to this tab no longer shifts the
      // backdrop. The header, chip row and scrollable body are all
      // transparent, so that one shared background reads as a single
      // unbroken surface behind them (no seam) - which is why the Trail no
      // longer paints its own full-bleed gradient.
      child: snapshotAsync.when(
        data: (snapshot) {
          if (snapshot.chips.isEmpty) {
            // No tasks at all, anywhere in the app: the same empty-state
            // illustration/copy Home shows for the identical condition
            // (see this run's spec: "reuse Empty Today's visual
            // language").
            return EmptyTodayView(
              onNewHabit: () => _openNewHabitScreen(context),
            );
          }
          return _TrailScreenBody(snapshot: snapshot, ref: ref);
        },
        // The stream's first emission is effectively synchronous (see
        // HomeService.watchToday's doc comment; TrailService follows
        // the same recipe), so there's no meaningful loading UI to
        // design here.
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
      // Shared top-left inset for every tab screen (Home/Trail/Stats/
      // Profile) and the VerificationHeader family - see
      // `kScreenEdgePadding`'s own doc comment.
      padding: kScreenEdgePadding,
      child: ScreenHeader(
        eyebrow: l10n.trailHeaderEyebrow,
        title: taskTitle,
        // ScreenHeader's own Row keeps the eyebrow top-aligned regardless of
        // this pill's height - see ScreenHeader's doc comment on why (this
        // is the exact drift this run's spec fixes: the old Row here used
        // `crossAxisAlignment: end`, so the pill's own height silently
        // pushed the eyebrow down relative to Stats/Profile).
        trailing: _RankPill(
          rank: rank,
          metresText: l10n.trailRankMetresLabel(formatMetresNumber(altitude, locale)),
        ),
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
            child: const MountainGlyph(color: AppColors.heroMountainStroke, size: 17),
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
  // other two match AppColors.miniCairnMid/miniCairnDark, shared with Camera
  // Capture's "Verifying…" mini-cairn glyph (centralized this pass - they
  // were previously each a single-use local literal here).
  static const _stones = [
    (width: 7.0, height: 3.0, color: AppColors.heroLabelSage),
    (width: 11.0, height: 4.0, color: AppColors.miniCairnMid),
    (width: 14.0, height: 4.0, color: AppColors.miniCairnDark),
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
/// hardcoded pixel coordinates, reproducing its visual language (a winding
/// dashed connector threading through alternating left/right anchor points)
/// instead. The parchment wash and topo contour are no longer painted here -
/// see [_TrailScreenBackground], which now covers the whole screen instead
/// of just this scrollable body.
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

  /// Extra vertical gap between the last (trailhead) node's own top and the
  /// "WHERE YOU STARTED" marker below it. Deliberately reuses [_rowSpacing]
  /// - the same vertical budget this layout already reserves between any
  /// two consecutive nodes - rather than a smaller constant of its own: the
  /// trailhead can *also* be the single still-growing cairn of a brand-new
  /// task (badge + up to a 9-stone stack, [PointsService.cairnCapStones] -
  /// 1 + title + caption), the tallest node this layout ever renders, and a
  /// fixed 96px clearance landed the marker on top of that content instead
  /// of below it. [_rowSpacing] is already this layout's own assumption of
  /// "enough room for one node's content" (every node, growing or settled,
  /// must fit within it before the next node starts), so reusing it here
  /// guarantees the marker clears the trailhead's content too, verified
  /// against `trail_screenshot_test.dart`'s single-growing-cairn scenario.
  static const double _markerGap = _rowSpacing;

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
        final viewportHeight = constraints.maxHeight;
        final anchors = [
          for (var i = 0; i < n; i++)
            Offset(
              _xFractionFor(i) * width,
              _topPad + i * _rowSpacing + _anchorYOffset,
            ),
        ];

        final trailStack = SizedBox(
          width: width,
          height: contentHeight,
          child: Stack(
            children: [
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
        );

        // Center-if-short, scroll-if-tall: a short trail (e.g. a single
        // still-growing trailhead cairn) would otherwise sit pinned to the
        // top of the viewport with a large dead expanse below it. Forcing
        // the scroll child's minimum height up to the viewport's own height
        // gives `Column`'s `MainAxisAlignment.center` room to centre
        // `trailStack` when it's shorter than the viewport, while a taller
        // trail simply exceeds that minimum and scrolls exactly as before -
        // the trailhead and "WHERE YOU STARTED" remain reachable at the
        // bottom for `trail_history.png`'s multi-cairn scenario.
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewportHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [trailStack],
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
          const LightningGlyph(color: AppColors.textFaint, size: 10),
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
