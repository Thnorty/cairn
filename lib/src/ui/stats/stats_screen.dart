import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../../providers.dart';
import '../../services/insights_service.dart';
import '../../services/points_service.dart';
import '../../services/stats_service.dart';
import '../premium/premium_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glyphs.dart';
import '../widgets/screen_header.dart';

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
/// every tab now). The whole screen (header and scrollable body) is
/// transparent, so it sits on `AppShell`'s shared `ScreenBackground` (the
/// same parchment + warm-clay/sage washes + contour Home, Profile and Trail
/// show), so switching to Stats no longer changes the backdrop. Nothing here
/// paints an opaque fill of its own, so that one shared background reads as a
/// single unbroken surface (no header/body seam).
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final snapshotAsync = ref.watch(statsSnapshotProvider);
    final isPremium = ref.watch(premiumStatusProvider);

    void openPremium() => openPremiumScreen(context);

    // Same reasoning as HomeScreen/ProfileScreen/TrailScreen's own
    // [AppScaffold]: this screen drops into AppShell's `IndexedStack`
    // (already under its own transparent `Material`) but must also render
    // correctly standalone (a widget test or the screenshot harness), so it
    // supplies its own transparent one, stacked on top of its own full-bleed
    // background - see [AppScaffold]'s own doc comment.
    return AppScaffold(
      child: Padding(
        // Shared top-left inset for every tab screen (Home/Trail/Stats/
        // Profile) and the VerificationHeader family - see
        // `kScreenEdgePadding`'s own doc comment.
        padding: kScreenEdgePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reuses navStats ("Stats") rather than a second identical
            // ARB key: the tab label and this screen's own title are the
            // same literal English word referring to the same screen -
            // same pattern ProfileScreen's own header uses for navYou.
            ScreenHeader(eyebrow: l10n.statsHeaderEyebrow, title: l10n.navStats),
            const SizedBox(height: 12),
            Expanded(
              child: snapshotAsync.when(
                data: (snapshot) => _StatsBody(
                  snapshot: snapshot,
                  onPremiumTap: openPremium,
                  isPremium: isPremium,
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
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.snapshot,
    required this.onPremiumTap,
    required this.isPremium,
  });

  final StatsSnapshot snapshot;
  final VoidCallback onPremiumTap;

  /// Gates which "Deeper insights" treatment renders below the current
  /// streaks list: the locked upsell card (unchanged) when false, the real
  /// section (`Cairn Stats - Deeper Insights.dc.html`) when true. Read once
  /// in [StatsScreen.build] via [premiumStatusProvider] and threaded down
  /// rather than watched again here, the same way [snapshot] itself is
  /// threaded down from [statsSnapshotProvider] instead of re-watched.
  final bool isPremium;

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
          if (snapshot.dailyCap != null) ...[
            _ProofsUsedCard(snapshot: snapshot, onGoUnlimited: onPremiumTap),
            const SizedBox(height: 14),
          ],
          _ThisWeekCard(snapshot: snapshot),
          const SizedBox(height: 22),
          Text(l10n.statsCurrentStreaksLabel, style: AppTextStyles.formSectionLabel),
          const SizedBox(height: 11),
          _CurrentStreaksList(streaks: snapshot.streaks),
          if (isPremium) ...[
            const SizedBox(height: 22),
            const _DeeperInsightsSection(),
          ] else ...[
            const SizedBox(height: 16),
            _DeeperInsightsCard(onTap: onPremiumTap),
          ],
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
    (width: 14.0, height: 5.0, color: AppColors.pebbleGlyphMid),
    (width: 18.0, height: 5.0, color: AppColors.pebbleGlyphDark),
  ];

  /// Slightly larger variant for a current-streak row's glyph, verbatim from
  /// the design's own (distinct) three stacked spans there.
  static const rowStones = [
    (width: 10.0, height: 4.0, color: AppColors.sage),
    (width: 15.0, height: 5.0, color: AppColors.pebbleGlyphMid),
    (width: 20.0, height: 5.0, color: AppColors.pebbleGlyphDark),
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
    final cap = snapshot.dailyCap!;

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
                l10n.statsProofsUsedCount(snapshot.proofsUsedToday, cap),
                style: AppTextStyles.statsUsedOfCapLabel,
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              for (var i = 0; i < cap; i++) ...[
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
// Deeper insights (entitled state): consistency / best time of day / rank
// projection - Cairn Stats - Deeper Insights.dc.html
// ---------------------------------------------------------------------------

/// The unlocked "Deeper insights" section shown in place of
/// [_DeeperInsightsCard] once [premiumStatusProvider] is true: a section
/// label + sage PREMIUM pill, then three cards (Consistency, Best time of
/// day, Rank projection) built from [insightsSnapshotProvider]. A
/// [ConsumerWidget] of its own (rather than threading another provider
/// value down from [StatsScreen]) since this is the one part of the screen
/// that needs a second, independent async source alongside [snapshot].
class _DeeperInsightsSection extends ConsumerWidget {
  const _DeeperInsightsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final insightsAsync = ref.watch(insightsSnapshotProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(l10n.statsDeeperInsightsSectionLabel, style: AppTextStyles.formSectionLabel),
            const SizedBox(width: 9),
            _InsightsPremiumPill(label: l10n.statsPremiumBadge),
          ],
        ),
        const SizedBox(height: 11),
        insightsAsync.when(
          data: (insights) => _DeeperInsightsCards(insights: insights),
          // Same reasoning as StatsScreen's own top-level snapshot: the
          // underlying reads resolve quickly and there's no meaningful
          // loading UI to design for this brief a window.
          loading: () => const SizedBox.shrink(),
          error: (error, stackTrace) => Text('$error', style: AppTextStyles.caption),
        ),
      ],
    );
  }
}

/// The small sage "PREMIUM" pill on [_DeeperInsightsSection]'s label row.
/// Sage (not [_DeeperInsightsCard]'s terracotta) is deliberate: sage means
/// "yours / live" here, terracotta means "buy this" on the locked card - see
/// the canonical design's own doc comment.
class _InsightsPremiumPill extends StatelessWidget {
  const _InsightsPremiumPill({required this.label});

  final String label;

  /// The design's own literal radius/padding for this pill - distinct one-
  /// off values, not shared [AppRadii] tokens.
  static const double _radius = 9;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.achievedTierIconBg,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Text(label, style: AppTextStyles.statsInsightsPremiumBadgeLabel),
    );
  }
}

/// The three Deeper Insights cards, 12px apart, in design order.
class _DeeperInsightsCards extends StatelessWidget {
  const _DeeperInsightsCards({required this.insights});

  final InsightsSnapshot insights;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ConsistencyCard(snapshot: insights.consistency),
        const SizedBox(height: 12),
        _BestTimeOfDayCard(bestTimeOfDay: insights.bestTimeOfDay),
        const SizedBox(height: 12),
        _RankProjectionCard(
          projection: insights.rankProjection,
          isAtTopRank: insights.isAtTopRank,
        ),
      ],
    );
  }
}

/// A single centred muted line replacing a Deeper Insights card's body when
/// it has nothing to show yet (see each card's own doc comment for its
/// specific degenerate condition). Not part of the canonical design (which
/// depicts only the populated state) - the card and its header stay put;
/// only the body swaps for this line, per this work order's own spec.
class _InsightsEmptyBody extends StatelessWidget {
  const _InsightsEmptyBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 20),
      child: Center(
        child: Text(message, style: AppTextStyles.caption, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Card 1: Consistency - a per-week trend line over
/// [InsightsService.consistencyWindowWeeks] weeks, plus the overall rate.
class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({required this.snapshot});

  final ConsistencySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final overallRate = snapshot.overallRate;

    return _StatsCard(
      radius: AppRadii.listPanel,
      padding: const EdgeInsetsDirectional.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (overallRate == null)
            Text(l10n.statsConsistencyCardTitle, style: AppTextStyles.statsCardHeading)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.statsConsistencyCardTitle, style: AppTextStyles.statsCardHeading),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatPercent(overallRate, locale),
                      style: AppTextStyles.statsWeekSummaryLabel.copyWith(
                        color: AppColors.sageText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.statsConsistencySummarySuffix(InsightsService.consistencyWindowWeeks),
                      style: AppTextStyles.statsWeekSummaryLabel,
                    ),
                  ],
                ),
              ],
            ),
          if (overallRate == null)
            _InsightsEmptyBody(message: l10n.statsInsightsEmptyState)
          else ...[
            const SizedBox(height: 14),
            _ConsistencyChart(weeks: snapshot.weeks),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.statsConsistencyStartCaption(InsightsService.consistencyWindowWeeks),
                  style: AppTextStyles.statsInsightsAxisCaption,
                ),
                Text(l10n.statsThisWeekLabel, style: AppTextStyles.statsInsightsAxisCaption),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The Consistency card's line chart: a sage stroke over a soft gradient
/// area fill, a dashed 50% reference line, and a filled marker circle on
/// the final (current-week) point.
///
/// Every week in [weeks] gets a plotted point, evenly spaced left to right
/// (oldest to current), even one with a null [WeeklyConsistency.rate] (no
/// week in the window had anything scheduled): it is plotted at 0 rather
/// than skipped, so the curve always has exactly
/// [InsightsService.consistencyWindowWeeks] points at fixed x-positions
/// matching the "8 weeks ago .. This week" axis captions underneath. This
/// card's own caller replaces the whole card body with [_InsightsEmptyBody]
/// when EVERY week is null ([ConsistencySnapshot.overallRate] null); a
/// single null week amid real history (most commonly the still-in-progress
/// current week very early on, e.g. all day Monday) is a real, if
/// unavoidably ambiguous, "nothing yet" data point, and 0 is the simplest
/// honest way to plot it without the curve's x-axis becoming variable-length.
class _ConsistencyChart extends StatelessWidget {
  const _ConsistencyChart({required this.weeks});

  final List<WeeklyConsistency> weeks;

  static const double _height = 88;

  @override
  Widget build(BuildContext context) {
    final points = [for (final week in weeks) week.rate ?? 0.0];
    return SizedBox(
      width: double.infinity,
      height: _height,
      child: CustomPaint(painter: _ConsistencyChartPainter(points: points)),
    );
  }
}

class _ConsistencyChartPainter extends CustomPainter {
  const _ConsistencyChartPainter({required this.points});

  final List<double> points;

  static const double _xPad = 3;
  static const double _topPad = 8;
  static const double _bottomPad = 8;
  static const double _dashWidth = 3;
  static const double _dashGap = 4;
  static const double _markerRadius = 4.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final chartWidth = size.width - _xPad * 2;
    const chartTop = _topPad;
    final chartBottom = size.height - _bottomPad;
    final chartHeight = chartBottom - chartTop;

    Offset pointAt(int i) {
      final x = _xPad + chartWidth * i / (points.length - 1);
      final y = chartBottom - points[i].clamp(0.0, 1.0) * chartHeight;
      return Offset(x, y);
    }

    final offsets = [for (var i = 0; i < points.length; i++) pointAt(i)];

    // 50% dashed reference line.
    final refY = chartBottom - 0.5 * chartHeight;
    final dashPaint = Paint()
      ..color = AppColors.statsFutureBarBg
      ..strokeWidth = 1;
    var dashX = _xPad;
    final dashEnd = size.width - _xPad;
    while (dashX < dashEnd) {
      final segmentEnd = (dashX + _dashWidth).clamp(0.0, dashEnd);
      canvas.drawLine(Offset(dashX, refY), Offset(segmentEnd, refY), dashPaint);
      dashX += _dashWidth + _dashGap;
    }

    // Soft gradient area fill under the curve.
    final fillPath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final point in offsets.skip(1)) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath
      ..lineTo(offsets.last.dx, chartBottom)
      ..lineTo(offsets.first.dx, chartBottom)
      ..close();
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, chartTop),
        Offset(0, chartBottom),
        const [AppColors.statsConsistencyFillStart, AppColors.sageGlowEnd],
      );
    canvas.drawPath(fillPath, fillPaint);

    // The curve itself.
    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final point in offsets.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppColors.sage
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Filled marker circle on the final (current-week) point.
    final marker = offsets.last;
    canvas.drawCircle(marker, _markerRadius, Paint()..color = AppColors.cardGradientLight);
    canvas.drawCircle(
      marker,
      _markerRadius,
      Paint()
        ..color = AppColors.sage
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  @override
  bool shouldRepaint(_ConsistencyChartPainter oldDelegate) =>
      !listEquals(points, oldDelegate.points);
}

/// Card 2: Best time of day - a 6-bucket bar chart of stones by local hour.
class _BestTimeOfDayCard extends StatelessWidget {
  const _BestTimeOfDayCard({required this.bestTimeOfDay});

  final BestTimeOfDay bestTimeOfDay;

  /// The six bucket labels in [BestTimeOfDay.bucketCounts] order
  /// (`[0,4) [4,8) [8,12) [12,16) [16,20) [20,24)`), shared by the bars
  /// themselves and by [statsBestTimeRangeLabel]'s start/end.
  static List<String> bucketLabels(AppLocalizations l10n) => [
        l10n.statsTimeBucketMidnight,
        l10n.statsTimeBucketFourAm,
        l10n.statsTimeBucketEightAm,
        l10n.statsTimeBucketNoon,
        l10n.statsTimeBucketFourPm,
        l10n.statsTimeBucketEightPm,
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final peak = bestTimeOfDay.peakBucketIndex;
    final labels = bucketLabels(l10n);

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
              Text(l10n.statsBestTimeCardTitle, style: AppTextStyles.statsCardHeading),
              if (peak != null)
                Text(
                  l10n.statsBestTimeRangeLabel(labels[peak], labels[(peak + 1) % labels.length]),
                  style: AppTextStyles.statsBestTimePeakLabel,
                ),
            ],
          ),
          if (peak == null)
            _InsightsEmptyBody(message: l10n.statsInsightsEmptyState)
          else ...[
            const SizedBox(height: 15),
            _BestTimeBars(bestTimeOfDay: bestTimeOfDay, peakIndex: peak, labels: labels),
            const SizedBox(height: 11),
            Text(
              l10n.statsBestTimeCaption(bestTimeOfDay.bucketCounts[peak], bestTimeOfDay.total),
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _BestTimeBars extends StatelessWidget {
  const _BestTimeBars({
    required this.bestTimeOfDay,
    required this.peakIndex,
    required this.labels,
  });

  final BestTimeOfDay bestTimeOfDay;
  final int peakIndex;
  final List<String> labels;

  static const double _height = 78;

  @override
  Widget build(BuildContext context) {
    final peakCount = bestTimeOfDay.bucketCounts[peakIndex];

    return SizedBox(
      height: _height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bestTimeOfDay.bucketCounts.length; i++) ...[
            if (i != 0) const SizedBox(width: 8),
            Expanded(
              child: _BestTimeBarColumn(
                key: ValueKey('best-time-bar-$i'),
                fraction: peakCount == 0 ? 0.0 : bestTimeOfDay.bucketCounts[i] / peakCount,
                isPeak: i == peakIndex,
                label: labels[i],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BestTimeBarColumn extends StatelessWidget {
  const _BestTimeBarColumn({
    super.key,
    required this.fraction,
    required this.isPeak,
    required this.label,
  });

  final double fraction;
  final bool isPeak;
  final String label;

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
              heightFactor: fraction.clamp(0.0, 1.0),
              widthFactor: 1.0,
              child: DecoratedBox(
                key: const ValueKey('best-time-bar-fill'),
                decoration: BoxDecoration(
                  gradient: isPeak ? AppGradients.statsWeekBarFill : null,
                  color: isPeak ? null : AppColors.statsMutedFillBg,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: isPeak
              ? AppTextStyles.statsTimeBucketLabel.copyWith(
                  color: AppColors.sageText,
                  fontWeight: FontWeight.w700,
                )
              : AppTextStyles.statsTimeBucketLabel,
        ),
      ],
    );
  }
}

/// Card 3: Rank projection - at the user's recent pace, when the next rank
/// tier arrives.
class _RankProjectionCard extends StatelessWidget {
  const _RankProjectionCard({required this.projection, required this.isAtTopRank});

  final RankProjection? projection;

  /// Distinguishes WHY [projection] is null (see [InsightsSnapshot]'s own
  /// doc comment): already at the top rank tier (nothing to project) versus
  /// not enough recent pace yet - two different fallback messages.
  final bool isAtTopRank;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final projection = this.projection;

    return _StatsCard(
      radius: AppRadii.listPanel,
      padding: const EdgeInsetsDirectional.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.statsRankProjectionCardTitle, style: AppTextStyles.statsCardHeading),
          if (projection == null)
            _InsightsEmptyBody(
              message: isAtTopRank
                  ? l10n.statsRankProjectionAtTopRank
                  : l10n.statsRankProjectionNoPace,
            )
          else ...[
            const SizedBox(height: 14),
            _RankProjectionBody(projection: projection, locale: locale, l10n: l10n),
          ],
        ],
      ),
    );
  }
}

class _RankProjectionBody extends StatelessWidget {
  const _RankProjectionBody({
    required this.projection,
    required this.locale,
    required this.l10n,
  });

  final RankProjection projection;
  final Locale locale;
  final AppLocalizations l10n;

  static const double _iconCircleSize = 42;

  @override
  Widget build(BuildContext context) {
    final weeksOut = (projection.metresRemaining / projection.metresPerWeek).round();
    final currentMetres = projection.nextTier.thresholdMetres - projection.metresRemaining;

    // Same span/progressed/fraction recipe ProfileScreen's own
    // `_ProgressToNext` uses for the rank hero's progress bar: the current
    // tier is always the entry immediately before nextTier in RankTier.
    // values (RankProjection only ever names a non-Pebble tier as next, so
    // index-1 is always safe).
    final tierIndex = RankTier.values.indexOf(projection.nextTier);
    final currentTierThreshold = RankTier.values[tierIndex - 1].thresholdMetres;
    final span = (projection.nextTier.thresholdMetres - currentTierThreshold).toDouble();
    final progressed = (currentMetres - currentTierThreshold).toDouble();
    final fraction = span <= 0 ? 1.0 : (progressed / span).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: _iconCircleSize,
              height: _iconCircleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.achievedTierIconBg,
              ),
              alignment: Alignment.center,
              child: const MountainGlyph(color: AppColors.sageText, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.statsRankProjectionHeadline(
                      projection.nextTier.label,
                      formatShortMonthDay(projection.projectedDate, locale),
                    ),
                    style: AppTextStyles.statsRankProjectionHeadline,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.statsRankProjectionCaption(
                      formatMetresNumber(projection.metresPerWeek.round(), locale),
                      weeksOut,
                    ),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.statsRankProjectionCurrentMetres(formatMetresNumber(currentMetres, locale)),
              style: AppTextStyles.statsResetCaption,
            ),
            Text(
              l10n.statsRankProjectionRemaining(
                formatMetresNumber(projection.metresRemaining, locale),
              ),
              style: AppTextStyles.statsResetCaption,
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            width: double.infinity,
            height: 8,
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: AppColors.statsMutedFillBg)),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: fraction,
                  heightFactor: 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: AppGradients.statsRankProjectionFill),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Locked "Deeper insights" Premium card
// ---------------------------------------------------------------------------

class _DeeperInsightsCard extends StatelessWidget {
  const _DeeperInsightsCard({required this.onTap});

  /// Premium is post-MVP (see AGENTS.md's phase plan); for now this is a
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
