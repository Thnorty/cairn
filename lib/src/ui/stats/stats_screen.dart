import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors, Scaffold, Text;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../../providers.dart';
import '../../services/stats_service.dart';
import '../premium/premium_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// The Stats screen (`Cairn Stats.dc.html`): lifetime stones/cairns totals,
/// today's proof budget, a Monday..Sunday weekly bar chart, every active
/// task's current streak, and a locked "Deeper insights" Premium upsell
/// card.
///
/// All data comes from [statsSnapshotProvider], which stays live (see
/// [StatsService.watchStats]'s doc comment): a completion recorded
/// elsewhere, or a pending proof resolving in the background, updates this
/// screen with no manual refresh. This screen brings its own fixed header
/// (eyebrow + title, the same treatment Profile's own header uses - see
/// [AppShell]'s doc comment on why the shared wordmark header is hidden for
/// every tab now) and its own full-bleed, washless background
/// ([_StatsScreenBackground]) rather than `ScreenBackground`'s default
/// Home-tuned washes/contour: `Cairn Stats.dc.html`'s scroll body has no
/// wash/contour of its own (unlike Trail's own multi-stop gradient), just
/// the flat parchment base colour, so painting that flat colour behind the
/// whole screen (header included) is what hides Home's washes without
/// introducing a seam - the same rationale `_TrailScreenBackground` gives
/// for Trail's own (differently-toned) full-bleed layer.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final snapshotAsync = ref.watch(statsSnapshotProvider);

    void openPremium() => openPremiumScreen(context);

    // Same reasoning as HomeScreen/ProfileScreen/TrailScreen's own root
    // Scaffold: this screen drops into AppShell's `IndexedStack` (already
    // under its own transparent `Material`) but must also render correctly
    // standalone (a widget test or the screenshot harness), so it supplies
    // its own transparent one.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: _StatsScreenBackground()),
          Padding(
            // 24/8 horizontal/top inset, matching the standardized top-left
            // header position shared by every tab screen (Home/Trail/Stats/
            // Profile) and the VerificationHeader family - this run's spec.
            padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.statsHeaderEyebrow, style: AppTextStyles.sectionLabel),
                const SizedBox(height: 4),
                // Reuses navStats ("Stats") rather than a second identical
                // ARB key: the tab label and this screen's own title are the
                // same literal English word referring to the same screen -
                // same pattern ProfileScreen's own header uses for navYou.
                Text(l10n.navStats, style: AppTextStyles.screenTitle),
                const SizedBox(height: 12),
                Expanded(
                  child: snapshotAsync.when(
                    data: (snapshot) => _StatsBody(
                      snapshot: snapshot,
                      onPremiumTap: openPremium,
                    ),
                    // The stream's first emission is effectively synchronous
                    // (see HomeService.watchToday's doc comment), so there's
                    // no meaningful loading UI to design here.
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => Center(child: Text('$error')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Stats screen's one continuous background layer: a flat parchment
/// fill covering the whole screen (header and scrollable body alike) - see
/// [StatsScreen]'s own doc comment for why no wash/contour is painted here
/// (the canonical design has none for this screen).
class _StatsScreenBackground extends StatelessWidget {
  const _StatsScreenBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: AppColors.screenBackground),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.snapshot, required this.onPremiumTap});

  final StatsSnapshot snapshot;
  final VoidCallback onPremiumTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopStatTiles(snapshot: snapshot),
          const SizedBox(height: 14),
          _ProofsUsedCard(snapshot: snapshot, onGoUnlimited: onPremiumTap),
          const SizedBox(height: 14),
          _ThisWeekCard(snapshot: snapshot),
          const SizedBox(height: 22),
          Text(l10n.statsCurrentStreaksLabel, style: AppTextStyles.formSectionLabel),
          const SizedBox(height: 11),
          _CurrentStreaksList(streaks: snapshot.streaks),
          const SizedBox(height: 16),
          _DeeperInsightsCard(onTap: onPremiumTap),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card surface
// ---------------------------------------------------------------------------

/// The gradient/border/top-highlight recipe shared by every parchment card
/// on this screen - the same recipe Profile's own `_PanelSurface` uses,
/// duplicated privately here (parameterised by radius/padding, which differ
/// per card on this screen) rather than shared, matching this codebase's
/// existing precedent of small per-screen private surface widgets.
class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.child,
    required this.radius,
    required this.padding,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: br,
        border: Border.all(color: AppColors.panelBorder),
        boxShadow: AppShadows.cardDimmed,
      ),
      child: ClipRRect(
        borderRadius: br,
        child: Stack(
          children: [
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(height: 1.5, child: ColoredBox(color: AppColors.panelTopHighlight)),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// The small stacked-pebble glyph used both by the top "Stones placed" tile
/// and by every current-streak row, at two different sizes - the same three
/// plain rounded bars `TrailScreen`'s own `_StackedPebbleGlyph` draws for its
/// selected habit-chip, duplicated privately here (per this codebase's
/// existing precedent for small one-off glyph widgets) rather than shared,
/// parameterised by [stones] so this file's two call sites can each supply
/// their own size.
class _StackedPebbleGlyph extends StatelessWidget {
  const _StackedPebbleGlyph({this.stones = _tileStones});

  /// (width, height, colour) for the top stat tile's glyph, verbatim from
  /// the design's three stacked spans.
  static const _tileStones = [
    (width: 9.0, height: 4.0, color: AppColors.sage),
    (width: 14.0, height: 5.0, color: Color(0xFFB6AD9C)),
    (width: 18.0, height: 5.0, color: Color(0xFFAEA491)),
  ];

  /// Slightly larger variant for a current-streak row's glyph, verbatim from
  /// the design's own (distinct) three stacked spans there.
  static const rowStones = [
    (width: 10.0, height: 4.0, color: AppColors.sage),
    (width: 15.0, height: 5.0, color: Color(0xFFB6AD9C)),
    (width: 20.0, height: 5.0, color: Color(0xFFAEA491)),
  ];

  final List<({double width, double height, Color color})> stones;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final stone in stones)
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

// ---------------------------------------------------------------------------
// Top stat tiles: Stones placed / Cairns built
// ---------------------------------------------------------------------------

class _TopStatTiles extends StatelessWidget {
  const _TopStatTiles({required this.snapshot});

  final StatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    return Row(
      children: [
        Expanded(
          child: _StatsCard(
            radius: AppRadii.listPanel,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _StackedPebbleGlyph(),
                    const SizedBox(width: 8),
                    Text(
                      formatMetresNumber(snapshot.stonesPlaced, locale),
                      style: AppTextStyles.statsBigNumber,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(l10n.statsStonesPlacedLabel, style: AppTextStyles.caption),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatsCard(
            radius: AppRadii.listPanel,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatMetresNumber(snapshot.cairnsBuilt, locale),
                  style: AppTextStyles.statsBigNumber,
                ),
                const SizedBox(height: 8),
                Text(l10n.statsCairnsBuiltLabel, style: AppTextStyles.caption),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Proofs used today
// ---------------------------------------------------------------------------

class _ProofsUsedCard extends StatelessWidget {
  const _ProofsUsedCard({required this.snapshot, required this.onGoUnlimited});

  final StatsSnapshot snapshot;
  final VoidCallback onGoUnlimited;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _StatsCard(
      radius: AppRadii.rowCard,
      padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.statsProofsUsedTodayLabel, style: AppTextStyles.statsCardHeading),
              Text(
                l10n.statsProofsUsedCount(snapshot.proofsUsedToday, snapshot.dailyCap),
                style: AppTextStyles.statsUsedOfCapLabel,
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              for (var i = 0; i < snapshot.dailyCap; i++) ...[
                if (i != 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    // Keyed so widget tests can assert the filled/unfilled
                    // segment count without reaching into this widget's
                    // private layout - same precedent as CairnStack's own
                    // per-stone keys.
                    key: ValueKey('proof-segment-$i'),
                    height: 9,
                    decoration: BoxDecoration(
                      color: i < snapshot.proofsUsedToday
                          ? AppColors.sage
                          : AppColors.statsMutedFillBg,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.resetsAtMidnight, style: AppTextStyles.statsResetCaption),
              const SizedBox(width: 4),
              Text('·', style: AppTextStyles.statsResetCaption),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onGoUnlimited,
                behavior: HitTestBehavior.opaque,
                child: Semantics(
                  button: true,
                  label: l10n.goUnlimitedButton,
                  child: Text(
                    l10n.goUnlimitedButton,
                    style: AppTextStyles.statsResetCaption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.sage,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// This week
// ---------------------------------------------------------------------------

class _ThisWeekCard extends StatelessWidget {
  const _ThisWeekCard({required this.snapshot});

  final StatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _StatsCard(
      radius: AppRadii.listPanel,
      padding: const EdgeInsetsDirectional.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.statsThisWeekLabel, style: AppTextStyles.statsCardHeading),
              Text(
                l10n.tasksDoneCount(snapshot.weekDone, snapshot.weekTotal),
                style: AppTextStyles.statsWeekSummaryLabel,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _WeekChart(week: snapshot.week),
        ],
      ),
    );
  }
}

/// The 7-bar weekly chart. Each bar's fill fraction is
/// `scheduled == 0 ? 0 : (done / scheduled)`, clamped to 1.0 (a completion
/// recorded for a task that was later archived can leave `done` counting
/// more than the currently-active `scheduled` total for that date - see
/// [StatsSnapshot.week]'s doc comment); a future day is rendered with a
/// faint, muted fill instead of the sage gradient regardless of its
/// fraction, matching the canonical design's own faded last (Sunday) bar -
/// in practice a future date's `done` is always 0 (no back-filling), so the
/// fraction is 0 there too, and "faint" and "low" arrive together exactly as
/// the design shows, without this widget needing to invent a fixed height
/// for a day that hasn't happened yet.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.week});

  final List<StatsWeekdayBar> week;

  static const double _chartHeight = 104;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return SizedBox(
      height: _chartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < week.length; i++) ...[
            if (i != 0) const SizedBox(width: 8),
            Expanded(
              child: _WeekdayBarColumn(
                key: ValueKey('week-bar-$i'),
                bar: week[i],
                label: formatWeekdayNarrow(week[i].date, locale),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekdayBarColumn extends StatelessWidget {
  const _WeekdayBarColumn({super.key, required this.bar, required this.label});

  final StatsWeekdayBar bar;
  final String label;

  double get _fraction {
    if (bar.scheduled == 0) return 0.0;
    return (bar.done / bar.scheduled).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: _fraction,
              widthFactor: 1.0,
              child: DecoratedBox(
                // Keyed (distinct from this column's own outer key) so
                // widget tests can inspect the fill decoration itself - its
                // colour/gradient - without reaching into this widget's
                // private layout, same precedent as CairnStack's own
                // per-stone keys.
                key: const ValueKey('week-bar-fill'),
                decoration: BoxDecoration(
                  gradient: bar.isFuture ? null : AppGradients.statsWeekBarFill,
                  color: bar.isFuture ? AppColors.statsFutureBarBg : null,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(label, style: AppTextStyles.statsWeekdayLabel),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Current streaks
// ---------------------------------------------------------------------------

class _CurrentStreaksList extends StatelessWidget {
  const _CurrentStreaksList({required this.streaks});

  final List<StatsStreak> streaks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (streaks.isEmpty) {
      return Text(l10n.statsNoActiveStreaksLabel, style: AppTextStyles.body);
    }

    return Column(
      children: [
        for (var i = 0; i < streaks.length; i++) ...[
          if (i != 0) const SizedBox(height: 10),
          _StreakRow(streak: streaks[i]),
        ],
      ],
    );
  }
}

class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.streak});

  final StatsStreak streak;

  /// The design's own literal radius for this row (`border-radius:22px`) -
  /// close to, but distinct from, [AppRadii.buttonSmall]'s numerically
  /// identical 22, which names an unrelated button shape; kept as a local
  /// literal rather than reusing that token's name for a different concept.
  static const double _radius = 22;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _StatsCard(
      radius: _radius,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _StackedPebbleGlyph(stones: _StackedPebbleGlyph.rowStones),
              const SizedBox(width: 13),
              Text(streak.taskTitle, style: AppTextStyles.smallCardTitle),
            ],
          ),
          Text(
            l10n.statsStreakDaysCount(streak.days),
            style: AppTextStyles.statsStreakDaysLabel,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Locked "Deeper insights" Premium card
// ---------------------------------------------------------------------------

class _DeeperInsightsCard extends StatelessWidget {
  const _DeeperInsightsCard({required this.onTap});

  /// Premium is post-MVP (see CLAUDE.md's phase plan); for now this is a
  /// no-op-for-now that shows a "coming soon" snackbar rather than building
  /// the real Premium screen here - same scope decision as Profile's own
  /// `_PremiumRow`.
  final VoidCallback onTap;

  /// Relative heights of the blurred faux-chart bars behind the lock icon,
  /// verbatim from the design's own five bars (40%/70%/55%/85%/60%).
  static const _fauxBarHeights = [0.40, 0.70, 0.55, 0.85, 0.60];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final radius = BorderRadius.circular(AppRadii.listPanel);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: l10n.statsDeeperInsightsTitle,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.statsLockedCardBg,
            borderRadius: radius,
            border: Border.all(color: AppColors.statsLockedCardBorder),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.35,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < _fauxBarHeights.length; i++) ...[
                              if (i != 0) const SizedBox(width: 6),
                              Expanded(
                                child: FractionallySizedBox(
                                  heightFactor: _fauxBarHeights[i],
                                  widthFactor: 1.0,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppColors.statsFauxChartBar,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.statsMutedFillBg,
                        ),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 17,
                          height: 17,
                          child: CustomPaint(painter: _LockGlyphPainter()),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.statsDeeperInsightsTitle, style: AppTextStyles.smallCardTitle),
                            const SizedBox(height: 1),
                            Text(l10n.statsDeeperInsightsSubtitle, style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.clayTintBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(l10n.statsPremiumBadge, style: AppTextStyles.statsPremiumBadgeLabel),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The locked "Deeper insights" card's small padlock glyph
/// (`M4 10h16v11H4z` body + `M8 10V7a4 4 0 0 1 8 0v3` shackle) - a faithful
/// silhouette (not an exact bezier reproduction), the same approximation
/// precedent this codebase already uses for other one-off glyphs (e.g.
/// `_GlyphShape.bell`/`.shield` in `profile_screen.dart`).
class _LockGlyphPainter extends CustomPainter {
  const _LockGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final paint = Paint()
      ..color = AppColors.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(4 * s, 10 * s, 16 * s, 11 * s),
      Radius.circular(2.5 * s),
    );
    canvas.drawRRect(body, paint);

    final shackle = Path()
      ..moveTo(p(8, 10).dx, p(8, 10).dy)
      ..lineTo(p(8, 7).dx, p(8, 7).dy)
      ..arcToPoint(p(16, 7), radius: Radius.circular(4 * s), clockwise: true)
      ..lineTo(p(16, 10).dx, p(16, 10).dy);
    canvas.drawPath(shackle, paint);
  }

  @override
  bool shouldRepaint(_LockGlyphPainter oldDelegate) => false;
}
