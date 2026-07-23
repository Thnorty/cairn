import 'package:flutter/material.dart'
    show MaterialPageRoute, Text;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../../providers.dart';
import '../../services/account_service.dart';
import '../../services/points_service.dart';
import '../../services/profile_service.dart';
import '../account/account_flow.dart';
import '../account/signed_in_account_row.dart';
import '../premium/premium_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import '../trail/how_cairns_work_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glyphs.dart';
import '../widgets/screen_header.dart';
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
    final accountFeatureAvailable = ref.watch(accountFeatureAvailableProvider);
    final accountStateAsync = ref.watch(accountStateProvider);

    void openCreateAccountFlow() {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => const AccountFlow(start: AccountEntryPoint.createAccount),
        ),
      );
    }

    // This screen gets dropped into AppShell's `IndexedStack` (which already
    // sits under its own `Material(type: MaterialType.transparency)`
    // ancestor) but must also render correctly standalone (a widget test or
    // the screenshot harness pumping just `ProfileScreen`), so - same
    // reasoning as `HomeScreen`'s own [AppScaffold] - it supplies its own
    // transparent one: that also gives every `Text` below a real `Material`
    // ancestor (see AppShell's build() comment) and gives the sign-out
    // confirmation dialog's `ScaffoldMessenger`/`Navigator` a real `Scaffold`
    // to present into.
    return AppScaffold(
      child: Padding(
        // Shared top-left inset for every tab screen (Home/Trail/Stats/
        // Profile) and the VerificationHeader family - see
        // `kScreenEdgePadding`'s own doc comment.
        padding: kScreenEdgePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reuses navYou ("You") rather than a second identical ARB key:
            // the tab label and this screen's own title are the same literal
            // English word referring to the same screen (see doc comment).
            ScreenHeader(eyebrow: l10n.profileHeaderLabel, title: l10n.navYou),
            const SizedBox(height: 12),
            Expanded(
              child: snapshotAsync.when(
                data: (snapshot) => _ProfileBody(
                  snapshot: snapshot,
                  accountFeatureAvailable: accountFeatureAvailable,
                  accountStateAsync: accountStateAsync,
                  onCreateAccount: openCreateAccountFlow,
                  onPremiumTap: () => openPremiumScreen(context),
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
    required this.accountFeatureAvailable,
    required this.accountStateAsync,
    required this.onCreateAccount,
    required this.onPremiumTap,
  });

  final ProfileSnapshot snapshot;

  /// False when no live Supabase project is configured
  /// ([AccountFeatureAvailableProvider]); the whole account entry (both the
  /// anonymous "Climbing anonymously / Create" row and the signed-in row)
  /// is hidden in that case, per this run's spec, rather than showing a
  /// feature with nothing to talk to.
  final bool accountFeatureAvailable;

  /// Anonymous-vs-signed-in state (`accountStateProvider`); decides which of
  /// the two account rows renders.
  final AsyncValue<AccountState> accountStateAsync;

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
          if (accountFeatureAvailable) ...[
            accountStateAsync.when(
              // AccountState.isAnonymous being false does NOT by itself mean
              // "signed in with an email": per AuthService's own doc
              // comment, it is also false when there is no session at all
              // (e.g. Supabase never initialized, or auth bootstrap hasn't
              // run yet), in which case email is null too. The signed-in
              // row only ever renders once there is a real email to show;
              // every other case (anonymous, or no session yet) falls back
              // to the ordinary "Climbing anonymously / Create" row.
              data: (state) {
                final email = state.email;
                if (!state.isAnonymous && email != null) {
                  return SignedInAccountRow(email: email);
                }
                return _AccountStatusRow(onCreate: onCreateAccount);
              },
              // Resolves effectively synchronously (a plain getter wrapped
              // in Future.value - see accountStateProvider's own doc
              // comment), so there's no meaningful loading UI to design
              // here, same reasoning as profileSnapshotProvider's own
              // loading branch above.
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => Text('$error'),
            ),
            const SizedBox(height: 14),
          ],
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
      child: const MountainGlyph(color: AppColors.heroMountainStroke, size: 26),
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

/// The Profile rank ladder, redesigned (Part 5 of this consistency pass) as
/// a mini vertical trail rather than the original flat radio-button-style
/// list of circles: a single connecting line runs down through every
/// tier's node, solid sage for the reached segment (up to and including the
/// current tier) and faint for the segment through the not-yet-reached
/// tiers, so the panel reads as a journey already underway rather than a
/// selection list. A deliberate, spec-authorized deviation from
/// `Cairn Profile.dc.html`'s own flat ladder (see this run's report) - the
/// underlying data is unchanged: the same [RankTier.values] order (Pebble
/// at top, Summit at bottom) and the same rank/threshold/metres-to-next
/// computation [_RankHeroCard]'s progress row already uses, never
/// recomputed ad hoc here.
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
          for (var i = 0; i < tiers.length; i++)
            _LadderRow(
              tier: tiers[i],
              status: i < currentIndex
                  ? _TierRowStatus.achieved
                  : i == currentIndex
                      ? _TierRowStatus.current
                      : _TierRowStatus.future,
              isImmediateNext: i == currentIndex + 1,
              isFirst: i == 0,
              isLast: i == tiers.length - 1,
              // The connecting line's own solid/faint split: a segment
              // reaching down INTO row i (its top half) is solid whenever
              // row i itself is achieved-or-current; a segment leading OUT
              // of row i (its bottom half) is solid only when row i is
              // strictly achieved (below the current tier's row, the line
              // has already crossed into "future" territory - see this
              // widget's own doc comment).
              topConnectorSolid: i <= currentIndex,
              bottomConnectorSolid: i < currentIndex,
              rank: rank,
              l10n: l10n,
              locale: locale,
            ),
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
    required this.isFirst,
    required this.isLast,
    required this.topConnectorSolid,
    required this.bottomConnectorSolid,
    required this.rank,
    required this.l10n,
    required this.locale,
  });

  final RankTier tier;
  final _TierRowStatus status;
  final bool isImmediateNext;
  final bool isFirst;
  final bool isLast;
  final bool topConnectorSolid;
  final bool bottomConnectorSolid;
  final Rank rank;
  final AppLocalizations l10n;
  final Locale locale;

  /// Fixed per-row height so every connector half-segment (and therefore
  /// the whole trail line) lines up node-to-node regardless of each row's
  /// own text/trailing-label height.
  static const double _rowHeight = 52;

  /// Fixed width of the leading node column: every node (achieved/future's
  /// small circle, the current tier's larger emphasized one) centers
  /// within this same column, so the vertical line - drawn through that
  /// column's horizontal center - passes through every node's own center
  /// no matter its size.
  static const double _railWidth = 26;

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
      // The emphasized node already reads "you are here" (this run's
      // spec), so this row's trailing label carries the same "N m to
      // <next tier>" progress text the rank hero's own progress row shows
      // - reusing rank.metresToNext/rank.nextTier rather than the plain
      // "You're here" caption the old flat ladder used, per this run's
      // spec ("keep the existing progress text"). At Summit there is no
      // next tier to progress toward, so this falls back to
      // profileYoureHereLabel exactly as the old ladder always showed.
      final next = rank.nextTier;
      final metresToNext = rank.metresToNext;
      trailing = Text(
        next != null && metresToNext != null
            ? l10n.profileMetresToNextTier(formatMetresNumber(metresToNext, locale), next.label)
            : l10n.profileYoureHereLabel,
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

    return SizedBox(
      height: _rowHeight,
      child: Stack(
        children: [
          if (!isFirst)
            Positioned(
              top: 0,
              height: _rowHeight / 2,
              left: _railWidth / 2 - 1,
              width: 2,
              child: _TrailConnector(solid: topConnectorSolid),
            ),
          if (!isLast)
            Positioned(
              top: _rowHeight / 2,
              height: _rowHeight / 2,
              left: _railWidth / 2 - 1,
              width: 2,
              child: _TrailConnector(solid: bottomConnectorSolid),
            ),
          Positioned.fill(
            child: Row(
              children: [
                SizedBox(width: _railWidth, child: Center(child: _TierNode(status: status))),
                const SizedBox(width: 12),
                Expanded(child: Text(tier.label, style: labelStyle)),
                trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One half-segment of the mini-trail's connecting line, between one
/// node's center and the next. [solid] sage marks the reached path (up to
/// and including the current tier); the faint variant marks the path
/// through tiers not yet reached - see [_RankLadderPanel]'s doc comment.
class _TrailConnector extends StatelessWidget {
  const _TrailConnector({required this.solid});

  final bool solid;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: solid ? AppColors.sage : AppColors.rankTrailLineFaint);
  }
}

/// A tier's own node on the mini-trail: a small solid sage dot once
/// achieved, a larger emphasized sage node with a soft glow ring and a tiny
/// mountain glyph for the current tier ("you are here"), or a small faint
/// hollow outline for a tier not yet reached.
class _TierNode extends StatelessWidget {
  const _TierNode({required this.status});

  final _TierRowStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _TierRowStatus.achieved:
        return Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
        );
      case _TierRowStatus.current:
        return Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.sage,
            shape: BoxShape.circle,
            // The same soft glow-ring recipe a freshly-placed sage stone
            // uses elsewhere in this app (AppColors.sageRing), reused here
            // rather than a new token, per this run's spec ("a subtle
            // ring/glow").
            boxShadow: [BoxShadow(color: AppColors.sageRing, spreadRadius: 5)],
          ),
          alignment: Alignment.center,
          child: const MountainGlyph(color: AppColors.heroMountainStroke, size: 11),
        );
      case _TierRowStatus.future:
        return Container(
          width: 10,
          height: 10,
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

  /// Opens [PremiumScreen] (see `openPremiumScreen`). Premium itself is
  /// post-MVP and purely presentational (no billing/IAP integration yet -
  /// see CLAUDE.md's phase plan), but the navigation here is real.
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
              const _HairlineDivider(),
              // Moved here from the Trail screen header's "?" info button
              // per this consistency pass (see trail_screen.dart's own doc
              // comment on the removal) - same HowCairnsWorkScreen
              // destination, real navigation rather than a no-op.
              _SettingsRow(
                glyph: _GlyphShape.info,
                label: l10n.profileHowCairnsWorkRow,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const HowCairnsWorkScreen(),
                )),
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
enum _GlyphShape { clockPending, check, chevronRight, bell, shield, restore, info }

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
        _GlyphShape.clockPending => 2.2,
        _GlyphShape.check => 2.6,
        _GlyphShape.chevronRight => 2.2,
        _GlyphShape.bell => 2,
        _GlyphShape.shield => 2,
        _GlyphShape.restore => 2,
        _GlyphShape.info => 2,
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
      case _GlyphShape.info:
        // Faithful silhouette of verification_chrome.dart's own info glyph
        // (`<circle r="9"/><path d="M12 11v5"/><circle r="0.4" fill.../>`),
        // duplicated privately here per this codebase's existing precedent
        // for small one-off glyphs on this screen (e.g. `.bell`/`.shield`
        // above) rather than importing that file's own private painter.
        canvas.drawCircle(p(12, 12), 9 * s, paint);
        canvas.drawLine(p(12, 10.8), p(12, 16), paint);
        canvas.drawCircle(p(12, 8.2), 0.9 * s, Paint()..color = color);
        break;
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      shape != oldDelegate.shape || color != oldDelegate.color;
}
