import 'package:flutter/material.dart'
    show Colors, Scaffold, ScaffoldMessenger, SnackBar, Text;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../../providers.dart';
import '../../services/points_service.dart';
import '../../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import '../widgets/tab_icons.dart';

/// The Profile ("You") screen (`Cairn Profile.dc.html`): the user's rank
/// hero card, the full rank ladder, the anonymous-account status row, the
/// Cairn Premium upsell row, and a settings list.
///
/// All data comes from [profileSnapshotProvider], which stays live (see
/// [ProfileService.watchProfile]'s doc comment): a completion recorded
/// elsewhere, or a pending proof resolving in the background, updates this
/// screen with no manual refresh.
///
/// A deliberate scope note on tier names: [RankTier.label] ("Pebble",
/// "Ridge", ...) is domain/brand vocabulary defined in `points_service.dart`
/// and is rendered here as-is, not routed through [AppLocalizations] - the
/// spec for this screen names `PointsService.rankFor(...).tier.label` as the
/// literal data source, the same way `appTitle` ("Cairn") stays a fixed
/// proper noun. Every other piece of copy on this screen (the surrounding
/// sentence structure, and every number - via [formatMetresNumber]) does go
/// through ARB/intl as usual.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final snapshotAsync = ref.watch(profileSnapshotProvider);

    void showComingSoon() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileComingSoonSnackbar)),
      );
    }

    // This screen gets dropped into AppShell's `IndexedStack` (which already
    // sits under its own `Material(type: MaterialType.transparency)`
    // ancestor) but must also render correctly standalone (a widget test or
    // the screenshot harness pumping just `ProfileScreen`), so - same
    // reasoning as `HomeScreen`'s own `Scaffold` - it supplies its own
    // transparent one: that also gives every `Text` below a real `Material`
    // ancestor (see AppShell's build() comment) and gives `showComingSoon`'s
    // `ScaffoldMessenger.showSnackBar` a real `Scaffold` to present into.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(22, 8, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.profileHeaderLabel, style: AppTextStyles.sectionLabel),
            const SizedBox(height: 4),
            // Reuses navYou ("You") rather than a second identical ARB key:
            // the tab label and this screen's own title are the same literal
            // English word referring to the same screen (see doc comment).
            Text(l10n.navYou, style: AppTextStyles.screenTitle),
            const SizedBox(height: 12),
            Expanded(
              child: snapshotAsync.when(
                data: (snapshot) => _ProfileBody(
                  snapshot: snapshot,
                  onCreateAccount: showComingSoon,
                  onPremiumTap: showComingSoon,
                ),
                // The stream's first emission is effectively synchronous
                // (see HomeService.watchToday's doc comment; ProfileService
                // follows the same recipe), so there's no meaningful loading
                // UI to design here.
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

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.snapshot,
    required this.onCreateAccount,
    required this.onPremiumTap,
  });

  final ProfileSnapshot snapshot;
  final VoidCallback onCreateAccount;
  final VoidCallback onPremiumTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RankHeroCard(snapshot: snapshot),
          const SizedBox(height: 14),
          _RankLadderPanel(rank: snapshot.rank),
          const SizedBox(height: 14),
          _AccountStatusRow(onCreate: onCreateAccount),
          const SizedBox(height: 14),
          _PremiumRow(onTap: onPremiumTap),
          const SizedBox(height: 22),
          const _SettingsSection(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rank hero card
// ---------------------------------------------------------------------------

class _RankHeroCard extends StatelessWidget {
  const _RankHeroCard({required this.snapshot});

  final ProfileSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final rank = snapshot.rank;
    final totalText = formatMetresNumber(snapshot.totalAltitude, locale);

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 22, 22, 20),
      decoration: BoxDecoration(
        gradient: AppGradients.heroDark,
        borderRadius: BorderRadius.circular(AppRadii.heroCard),
        boxShadow: AppShadows.heroCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _RankBadge(),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.profileCurrentRankLabel, style: AppTextStyles.heroLabel),
                    const SizedBox(height: 2),
                    Text(rank.tier.label, style: AppTextStyles.heroTierTitle),
                    const SizedBox(height: 1),
                    Text(
                      l10n.profileMetresGainedLabel(totalText),
                      style: AppTextStyles.heroGainedSubtitle,
                    ),
                    // Withheld metres, shown only while a proof is still
                    // awaiting a verdict - never folded into the total above
                    // (see CLAUDE.md's pending-completion decision and
                    // ProfileSnapshot's doc comment).
                    if (snapshot.pendingAltitude > 0) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _Glyph(
                            shape: _GlyphShape.clockPending,
                            color: AppColors.heroPendingText,
                            size: 11,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            l10n.profilePendingMetresLabel(
                              formatMetresNumber(snapshot.pendingAltitude, locale),
                            ),
                            style: AppTextStyles.heroPendingLabel,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // No design reference exists for the Summit (top-rank) state, so
          // the whole progress-to-next block is simply omitted once there's
          // nowhere further to climb, rather than inventing copy for it.
          if (rank.metresToNext != null && rank.nextTier != null) ...[
            const SizedBox(height: 18),
            _ProgressToNext(rank: rank, l10n: l10n, locale: locale),
          ],
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppGradients.heroBadge,
        shape: BoxShape.circle,
        boxShadow: AppShadows.heroBadge,
      ),
      alignment: Alignment.center,
      child: const _Glyph(
        shape: _GlyphShape.mountain,
        color: AppColors.heroMountainStroke,
        size: 26,
      ),
    );
  }
}

class _ProgressToNext extends StatelessWidget {
  const _ProgressToNext({required this.rank, required this.l10n, required this.locale});

  final Rank rank;
  final AppLocalizations l10n;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final next = rank.nextTier!;
    final span = (next.thresholdMetres - rank.tier.thresholdMetres).toDouble();
    final progressed = (rank.metres - rank.tier.thresholdMetres).toDouble();
    final fraction = span <= 0 ? 1.0 : (progressed / span).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(rank.tier.label, style: AppTextStyles.heroProgressLabel),
            Text(
              l10n.profileMetresToNextTier(
                formatMetresNumber(rank.metresToNext!, locale),
                next.label,
              ),
              style: AppTextStyles.heroProgressNext,
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            width: double.infinity,
            height: 9,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: AppColors.heroProgressTrackBg),
                ),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: fraction,
                  heightFactor: 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: AppGradients.heroProgressFill),
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
// Rank ladder
// ---------------------------------------------------------------------------

enum _TierRowStatus { achieved, current, future }

class _RankLadderPanel extends StatelessWidget {
  const _RankLadderPanel({required this.rank});

  final Rank rank;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final tiers = RankTier.values;
    final currentIndex = tiers.indexOf(rank.tier);

    return _PanelSurface(
      child: Column(
        children: [
          for (var i = 0; i < tiers.length; i++) ...[
            _LadderRow(
              tier: tiers[i],
              status: i < currentIndex
                  ? _TierRowStatus.achieved
                  : i == currentIndex
                      ? _TierRowStatus.current
                      : _TierRowStatus.future,
              isImmediateNext: i == currentIndex + 1,
              l10n: l10n,
              locale: locale,
            ),
            if (i != tiers.length - 1) const _HairlineDivider(),
          ],
        ],
      ),
    );
  }
}

class _LadderRow extends StatelessWidget {
  const _LadderRow({
    required this.tier,
    required this.status,
    required this.isImmediateNext,
    required this.l10n,
    required this.locale,
  });

  final RankTier tier;
  final _TierRowStatus status;
  final bool isImmediateNext;
  final AppLocalizations l10n;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final labelStyle = switch (status) {
      _TierRowStatus.achieved => AppTextStyles.ladderTierLabel,
      _TierRowStatus.current => AppTextStyles.ladderTierLabel.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.inkPrimary,
        ),
      _TierRowStatus.future =>
        AppTextStyles.ladderTierLabel.copyWith(color: AppColors.textFaint),
    };

    final Widget trailing;
    if (status == _TierRowStatus.current) {
      trailing = Text(
        l10n.profileYoureHereLabel,
        style: AppTextStyles.ladderMetresLabel.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.sageText,
        ),
      );
    } else {
      final metresText = formatMetresNumber(tier.thresholdMetres, locale);
      trailing = Text(
        isImmediateNext
            ? l10n.profileNextTierMetres(metresText)
            : l10n.profileTierMetres(metresText),
        style: AppTextStyles.ladderMetresLabel,
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TierIcon(status: status),
              const SizedBox(width: 12),
              Text(tier.label, style: labelStyle),
            ],
          ),
          trailing,
        ],
      ),
    );
  }
}

class _TierIcon extends StatelessWidget {
  const _TierIcon({required this.status});

  final _TierRowStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _TierRowStatus.achieved:
        return Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppColors.achievedTierIconBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const _Glyph(
            shape: _GlyphShape.check,
            color: AppColors.sageText,
            size: 14,
          ),
        );
      case _TierRowStatus.current:
        return Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: AppColors.heroInk, shape: BoxShape.circle),
          ),
        );
      case _TierRowStatus.future:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.futureTierBorder, width: 1.5),
          ),
        );
    }
  }
}

class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 1, child: ColoredBox(color: AppColors.hairlineDivider));
  }
}

/// The gradient/border/top-highlight/radius recipe shared by the rank
/// ladder and the settings list - a uniform-radius parchment panel distinct
/// from [CardSurface]'s deliberately irregular per-corner shape (neither of
/// these two panels uses that shape in the source file).
class _PanelSurface extends StatelessWidget {
  const _PanelSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.listPanel);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: radius,
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(height: 1.5, child: ColoredBox(color: AppColors.panelTopHighlight)),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 18, vertical: 4),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account status ("Climbing anonymously")
// ---------------------------------------------------------------------------

class _AccountStatusRow extends StatelessWidget {
  const _AccountStatusRow({required this.onCreate});

  /// Phase 4 wires this to the real email/password upgrade flow (see
  /// CLAUDE.md's phase plan); for now it is a no-op-for-now that shows a
  /// "coming soon" snackbar rather than any invented account-creation UI.
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppColors.accountStatusBg,
        border: Border.all(color: AppColors.accountStatusBorder),
        borderRadius: BorderRadius.circular(AppRadii.rowCard),
      ),
      // The subtitle is long enough that it wraps to two lines at this
      // card's width; `crossAxisAlignment.start` (rather than the design's
      // literal `align-items:center`, written for a rendering where the
      // browser happened to keep it on one line) keeps the avatar and the
      // "Create" action pinned to the top of the row instead of centering
      // them against a two-line-tall paragraph, which otherwise made
      // "Create" visually collide with the wrapped second line.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppGradients.accountAvatar,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const TabBarIcon(
              shape: TabIconShape.you,
              color: AppColors.accountIconStroke,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.profileClimbingAnonymouslyTitle, style: AppTextStyles.accountStatusTitle),
                const SizedBox(height: 1),
                Text(
                  l10n.profileCreateAccountBody,
                  style: AppTextStyles.caption.copyWith(color: AppColors.clayText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onCreate,
            behavior: HitTestBehavior.opaque,
            child: Semantics(
              button: true,
              label: l10n.profileCreateButton,
              child: Text(l10n.profileCreateButton, style: AppTextStyles.accountCreateLabel),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cairn Premium upsell row
// ---------------------------------------------------------------------------

class _PremiumRow extends StatelessWidget {
  const _PremiumRow({required this.onTap});

  /// Premium is post-MVP (see CLAUDE.md's phase plan); for now this is a
  /// no-op-for-now that shows a "coming soon" snackbar rather than building
  /// the real Premium screen here.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final radius = BorderRadius.circular(AppRadii.rowCard);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: l10n.profilePremiumTitle,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.premiumBg,
            borderRadius: radius,
            border: Border.all(color: AppColors.premiumBorder, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 1.5,
                    child: ColoredBox(color: AppColors.panelTopHighlight),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.all(16),
                  child: Row(
                    children: [
                      const _PremiumMountainBars(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.profilePremiumTitle, style: AppTextStyles.smallCardTitle),
                            const SizedBox(height: 1),
                            Text(l10n.profilePremiumSubtitle, style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      const _Glyph(
                        shape: _GlyphShape.chevronRight,
                        color: AppColors.textFaint,
                        size: 18,
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

/// The three stacked rounded sage bars standing in for a tiny mountain-peaks
/// icon on the Cairn Premium row (three plain divs in the source file, not
/// an SVG path).
class _PremiumMountainBars extends StatelessWidget {
  const _PremiumMountainBars();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height, Color color) {
      return Container(
        width: width,
        height: height,
        margin: const EdgeInsetsDirectional.only(bottom: 0.5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
      );
    }

    return SizedBox(
      width: 26,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          bar(9, 4, AppColors.sage),
          bar(15, 5, AppColors.sageLight),
          bar(20, 5, AppColors.sage),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings list
// ---------------------------------------------------------------------------

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  // Every row below is a navigational placeholder: later phases wire a real
  // destination (Notifications/Privacy settings screens, and the Restore
  // purchase flow alongside Phase 4's account work); none is invented here.
  static void _noOp() {}

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.profileSettingsSectionLabel, style: AppTextStyles.formSectionLabel),
        const SizedBox(height: 11),
        _PanelSurface(
          child: Column(
            children: [
              _SettingsRow(
                glyph: _GlyphShape.bell,
                label: l10n.profileNotificationsRow,
                onTap: _noOp,
              ),
              const _HairlineDivider(),
              _SettingsRow(
                glyph: _GlyphShape.shield,
                label: l10n.profilePrivacyRow,
                onTap: _noOp,
              ),
              const _HairlineDivider(),
              _SettingsRow(
                glyph: _GlyphShape.restore,
                label: l10n.profileRestorePurchaseRow,
                onTap: _noOp,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.glyph, required this.label, required this.onTap});

  final _GlyphShape glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: label,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 15),
          child: Row(
            children: [
              _Glyph(shape: glyph, color: AppColors.textMuted, size: 19),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: AppTextStyles.settingsRowLabel)),
              const _Glyph(
                shape: _GlyphShape.chevronRight,
                color: AppColors.textInactive,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glyphs
// ---------------------------------------------------------------------------

/// Which one-off stroke-icon glyph to paint on this screen. Grouped into one
/// enum + [CustomPainter] (mirroring `TabBarIcon`'s own pattern) rather than
/// a separate tiny painter class per icon.
enum _GlyphShape { mountain, clockPending, check, chevronRight, bell, shield, restore }

class _Glyph extends StatelessWidget {
  const _Glyph({required this.shape, required this.color, this.size = 18});

  final _GlyphShape shape;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GlyphPainter(shape: shape, color: color)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.shape, required this.color});

  final _GlyphShape shape;
  final Color color;

  static double _strokeWidthFor(_GlyphShape shape) => switch (shape) {
        _GlyphShape.mountain => 2,
        _GlyphShape.clockPending => 2.2,
        _GlyphShape.check => 2.6,
        _GlyphShape.chevronRight => 2.2,
        _GlyphShape.bell => 2,
        _GlyphShape.shield => 2,
        _GlyphShape.restore => 2,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidthFor(shape) * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (shape) {
      case _GlyphShape.mountain:
        // `M3 19l5.5-9 3.5 5 2-3 6.5 7z` - the rank hero's mountain badge.
        final path = Path()
          ..moveTo(p(3, 19).dx, p(3, 19).dy)
          ..lineTo(p(8.5, 10).dx, p(8.5, 10).dy)
          ..lineTo(p(12, 15).dx, p(12, 15).dy)
          ..lineTo(p(14, 12).dx, p(14, 12).dy)
          ..lineTo(p(20.5, 19).dx, p(20.5, 19).dy)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case _GlyphShape.clockPending:
        // `<circle cx=12 cy=12 r=8.5/><path d="M12 7.5v5l3.2 2"/>` - the
        // withheld-metres line's clock icon.
        canvas.drawCircle(p(12, 12), 8.5 * s, paint);
        final hand = Path()
          ..moveTo(p(12, 7.5).dx, p(12, 7.5).dy)
          ..lineTo(p(12, 12).dx, p(12, 12).dy)
          ..lineTo(p(15.2, 14).dx, p(15.2, 14).dy);
        canvas.drawPath(hand, paint);
        break;
      case _GlyphShape.check:
        // `M5 12.5l4.2 4.2L19 7` - an achieved rank tier's icon.
        final path = Path()
          ..moveTo(p(5, 12.5).dx, p(5, 12.5).dy)
          ..lineTo(p(9.2, 16.7).dx, p(9.2, 16.7).dy)
          ..lineTo(p(19, 7).dx, p(19, 7).dy);
        canvas.drawPath(path, paint);
        break;
      case _GlyphShape.chevronRight:
        // `M9 6l6 6-6 6` - the Premium row and settings rows' disclosure
        // chevron (same path New Habit's own chevrons use, duplicated here
        // rather than shared across files - matching this codebase's
        // existing precedent, e.g. `_ChevronRightPainter` in
        // new_habit_recurrence_panel.dart).
        final path = Path()
          ..moveTo(p(9, 6).dx, p(9, 6).dy)
          ..lineTo(p(15, 12).dx, p(15, 12).dy)
          ..lineTo(p(9, 18).dx, p(9, 18).dy);
        canvas.drawPath(path, paint);
        break;
      case _GlyphShape.bell:
        // Faithful silhouette (not an exact bezier reproduction - see this
        // codebase's existing precedent for approximated glyphs, e.g.
        // `GalleryGlyph`/`DashedGhostStone`) of
        // `M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9` plus its clapper
        // `M10.5 21a1.8 1.8 0 0 0 3 0`.
        final dome = Path()
          ..moveTo(p(18, 8).dx, p(18, 8).dy)
          ..arcToPoint(p(6, 8), radius: Radius.circular(6 * s), clockwise: false)
          ..cubicTo(
            p(6, 15).dx,
            p(6, 15).dy,
            p(3, 17).dx,
            p(3, 17).dy,
            p(3, 17).dx,
            p(3, 17).dy,
          )
          ..lineTo(p(21, 17).dx, p(21, 17).dy)
          ..cubicTo(
            p(21, 17).dx,
            p(21, 17).dy,
            p(18, 15).dx,
            p(18, 15).dy,
            p(18, 8).dx,
            p(18, 8).dy,
          );
        canvas.drawPath(dome, paint);
        final clapper = Path()
          ..moveTo(p(10.5, 21).dx, p(10.5, 21).dy)
          ..quadraticBezierTo(
            p(12, 22.8).dx,
            p(12, 22.8).dy,
            p(13.5, 21).dx,
            p(13.5, 21).dy,
          );
        canvas.drawPath(clapper, paint);
        break;
      case _GlyphShape.shield:
        // Faithful silhouette of
        // `M12 2.5l7.5 3v6.2c0 4.6-3.2 7.9-7.5 9.3-4.3-1.4-7.5-4.7-7.5-9.3V5.5z`.
        final path = Path()
          ..moveTo(p(12, 2.5).dx, p(12, 2.5).dy)
          ..lineTo(p(19.5, 5.5).dx, p(19.5, 5.5).dy)
          ..lineTo(p(19.5, 11.7).dx, p(19.5, 11.7).dy)
          ..cubicTo(
            p(19.5, 16.3).dx,
            p(19.5, 16.3).dy,
            p(16.3, 19.6).dx,
            p(16.3, 19.6).dy,
            p(12, 21).dx,
            p(12, 21).dy,
          )
          ..cubicTo(
            p(7.7, 19.6).dx,
            p(7.7, 19.6).dy,
            p(4.5, 16.3).dx,
            p(4.5, 16.3).dy,
            p(4.5, 11.7).dx,
            p(4.5, 11.7).dy,
          )
          ..lineTo(p(4.5, 5.5).dx, p(4.5, 5.5).dy)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case _GlyphShape.restore:
        // Faithful silhouette (two opposing arcs + small arrowhead ticks) of
        // `M4 8a8 8 0 0 1 13.5-4L20 6M20 4v3.5h-3.5` and its mirror
        // `M20 16a8 8 0 0 1-13.5 4L4 18M4 20v-3.5h3.5` - the "restore
        // purchase" row's circular-arrows icon.
        final upperRect = Rect.fromCircle(center: p(12, 8), radius: 8 * s);
        canvas.drawArc(upperRect, 3.6, 4.4, false, paint);
        final upperArrow = Path()
          ..moveTo(p(20, 4).dx, p(20, 4).dy)
          ..lineTo(p(20, 7.5).dx, p(20, 7.5).dy)
          ..lineTo(p(16.5, 7.5).dx, p(16.5, 7.5).dy);
        canvas.drawPath(upperArrow, paint);

        final lowerRect = Rect.fromCircle(center: p(12, 16), radius: 8 * s);
        canvas.drawArc(lowerRect, 0.4, 4.4, false, paint);
        final lowerArrow = Path()
          ..moveTo(p(4, 20).dx, p(4, 20).dy)
          ..lineTo(p(4, 16.5).dx, p(4, 16.5).dy)
          ..lineTo(p(7.5, 16.5).dx, p(7.5, 16.5).dy);
        canvas.drawPath(lowerArrow, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      shape != oldDelegate.shape || color != oldDelegate.color;
}
