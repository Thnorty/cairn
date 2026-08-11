import 'dart:async';

import 'package:flutter/material.dart'
    show MaterialPageRoute, Text;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../../premium/premium_service.dart';
import '../../providers.dart';
import '../../config.dart';
import '../external_url.dart';
import '../../services/account_service.dart';
import '../../services/points_service.dart';
import '../../services/profile_service.dart';
import '../account/account_flow.dart';
import '../account/delete_account_screen.dart';
import '../account/signed_in_account_row.dart';
import '../onboarding/onboarding_name_screen.dart';
import '../premium/premium_screen.dart';
import '../settings/notifications_screen.dart';
import '../stone_style/stone_style_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import '../trail/how_cairns_work_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/cairn_dialog.dart';
import '../widgets/glyphs.dart';
import '../widgets/message_snack_bar.dart';
import '../widgets/screen_header.dart';
import '../widgets/settings_panel.dart';
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
    final isPremium = ref.watch(premiumStatusProvider);

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
                  isPremium: isPremium,
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
    required this.isPremium,
    required this.accountFeatureAvailable,
    required this.accountStateAsync,
    required this.onCreateAccount,
    required this.onPremiumTap,
  });

  final ProfileSnapshot snapshot;

  /// Whether the user is currently entitled to Premium
  /// (`premiumStatusProvider`), watched once here in this screen's
  /// `ConsumerWidget` ancestor and threaded down as a plain bool - see
  /// [_RankHeroCard]'s own doc comment on why it stays a [StatelessWidget]
  /// rather than becoming a [ConsumerWidget] just for this one flag.
  final bool isPremium;

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
          _RankHeroCard(snapshot: snapshot, isPremium: isPremium),
          const SizedBox(height: 14),
          _RankLadderPanel(rank: snapshot.rank),
          const SizedBox(height: 14),
          if (accountFeatureAvailable) ...[
            accountStateAsync.when(
              // The signed-in row only ever renders once there is a real
              // email to show; every other case (anonymous, or no session
              // yet) falls back to the ordinary "Climbing anonymously /
              // Create" row. That distinction lives in
              // [AccountState.isSignedIn] - see its doc comment for why
              // `!isAnonymous` alone is not enough.
              data: (state) {
                final email = state.email;
                if (state.isSignedIn && email != null) {
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
  const _RankHeroCard({required this.snapshot, required this.isPremium});

  final ProfileSnapshot snapshot;

  /// Whether to show the PREMIUM badge (see `Cairn Profile.dc.html`'s own
  /// HTML comment above the badge `<span>` for the design rationale). Passed
  /// down from [ProfileScreen]'s `ConsumerWidget` build method rather than
  /// watched here directly: this card stays a plain [StatelessWidget], the
  /// same "pass a bool down" approach this run's spec calls for instead of
  /// promoting it to a [ConsumerWidget] just for one flag.
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final rank = snapshot.rank;
    final totalText = formatMetresNumber(snapshot.totalAltitude, locale);

    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.heroDark,
        borderRadius: BorderRadius.circular(AppRadii.heroCard),
        boxShadow: AppShadows.heroCard,
      ),
      // A Stack (rather than folding the badge into the padded Column below)
      // so the badge's top/end offsets are measured from the CARD's own
      // edge, matching the source file's CSS: the badge `<span>` is
      // `position:absolute` against the outer div, which has its own
      // `padding:22px 22px 20px` - offsets on an absolutely positioned
      // element are relative to its containing block's edge, not inset by
      // that block's own padding. A `Positioned` child of a `Padding`-wrapped
      // Column would instead measure from the padded content box, sitting
      // ~22px further in than the design.
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(22, 22, 22, 20),
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
                          // Withheld metres, shown only while a proof is
                          // still awaiting a verdict - never folded into the
                          // total above (see AGENTS.md's pending-completion
                          // decision and ProfileSnapshot's doc comment).
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
                // No design reference exists for the Summit (top-rank)
                // state, so the whole progress-to-next block is simply
                // omitted once there's nowhere further to climb, rather
                // than inventing copy for it.
                if (rank.metresToNext != null && rank.nextTier != null) ...[
                  const SizedBox(height: 18),
                  _ProgressToNext(rank: rank, l10n: l10n, locale: locale),
                ],
              ],
            ),
          ),
          if (isPremium)
            const PositionedDirectional(top: 18, end: 20, child: _PremiumBadge()),
        ],
      ),
    );
  }
}

/// The rank hero's "PREMIUM" pill (`Cairn Profile.dc.html`'s HTML comment
/// above the badge `<span>`): sage, not the terracotta used by the paywall
/// upsell pills elsewhere - in this design language sage means "yours /
/// live" and terracotta means "buy this".
class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.heroPremiumBadgeBg,
        border: Border.all(color: AppColors.heroPremiumBadgeBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 9, vertical: 4),
        child: Text(l10n.profilePremiumBadge, style: AppTextStyles.heroPremiumBadgeLabel),
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

    return SettingsPanel(
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


// ---------------------------------------------------------------------------
// Account status ("Climbing anonymously")
// ---------------------------------------------------------------------------

class _AccountStatusRow extends StatelessWidget {
  const _AccountStatusRow({required this.onCreate});

  /// Callback invoked to open the account-upgrade / create-account flow.
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onCreate,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: l10n.profileCreateButton,
        child: Container(
          padding: const EdgeInsetsDirectional.all(16),
          decoration: BoxDecoration(
            color: AppColors.accountStatusBg,
            border: Border.all(color: AppColors.accountStatusBorder),
            borderRadius: BorderRadius.circular(AppRadii.rowCard),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cairn Premium upsell row
// ---------------------------------------------------------------------------

class _PremiumRow extends ConsumerWidget {
  const _PremiumRow({required this.onTap});

  /// Opens [PremiumScreen] (see `openPremiumScreen`).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = ref.watch(premiumStatusProvider);
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
                            Text(
                              isPremium
                                  ? l10n.premiumAlreadySubscribedSubtitle
                                  : l10n.profilePremiumSubtitle,
                              style: AppTextStyles.caption,
                            ),
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

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();


  Future<void> _handleRestore(BuildContext context, WidgetRef ref) async {
    final isSignedIn =
        ref.read(accountStateProvider).asData?.value.isSignedIn ?? false;

    if (!isSignedIn) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showCairnDialog(
        context: context,
        icon: const RestoreDialogIcon(),
        title: l10n.premiumRestoreDialogTitle,
        body: l10n.premiumRestoreDialogBody,
        cancelLabel: l10n.premiumRestoreDialogNotNow,
        confirmLabel: l10n.premiumRestoreDialogContinue,
        tone: CairnDialogTone.sage,
      );
      if (confirmed && context.mounted) {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => AccountFlow(
              start: AccountEntryPoint.createAccount,
              onComplete: () {
                ref.invalidate(accountStateProvider);
              },
            ),
          ),
        );
      }
      return;
    }

    final outcome = await ref.read(premiumServiceProvider).restore();
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    switch (outcome) {
      case PremiumPurchaseSucceeded(:final isPremium):
        if (isPremium) {
          context.showMessageSnackBar(
            l10n.premiumRestoreSuccessSnackbar,
            tone: MessageTone.success,
          );
        } else {
          context.showMessageSnackBar(
            l10n.premiumRestoreNoneSnackbar,
            tone: MessageTone.muted,
          );
        }
      case PremiumPurchaseCancelled():
        break;
      case PremiumPurchaseFailed(:final message):
        context.showMessageSnackBar(
          message,
          tone: MessageTone.neutral,
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Watched here (not read lazily inside the row's own onTap) so the
    // provider is already resolved by the time the screen is on-screen and
    // tappable: a bare ref.read on a FutureProvider that has never been
    // watched yet would only just be starting its future at that exact
    // synchronous call, returning its still-loading (null) AsyncValue - the
    // pre-fill would silently come up empty on the very first tap.
    final currentName = ref.watch(storedDisplayNameProvider).asData?.value;
    final accountState = ref.watch(accountStateProvider).asData?.value;
    // Non-null only for a real email account - see AccountState.isSignedIn,
    // which exists because `!isAnonymous` alone also passes for "no session
    // at all". The Delete account row keys off this being non-null.
    final signedInEmail =
        (accountState?.isSignedIn ?? false) ? accountState!.email : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.profileSettingsSectionLabel, style: AppTextStyles.formSectionLabel),
        const SizedBox(height: 11),
        SettingsPanel(
          child: Column(
            children: [
              // Row order is the one `Cairn Profile.dc.html` now shows, and
              // is deliberate rather than the append-as-built order this
              // list previously grew in: the rows you change about yourself
              // (notifications, name, stone style) come first, the one you
              // read (how cairns work) next, and the two you almost never
              // touch (privacy, restore purchase) last.
              // Phase 6's notification feature: opens NotificationsScreen
              // (`Cairn Notifications.dc.html`).
              _SettingsRow(
                glyph: _GlyphShape.bell,
                label: l10n.profileNotificationsRow,
                onTap: () => openNotificationsScreen(context),
              ),
              const HairlineDivider(),
              // The onboarding "Your name" screen's edit variant (see
              // OnboardingNameScreen's own doc comment): close-X, no page
              // dots, "Save", pre-filled with [currentName] (the *raw*
              // stored value watched above, not userDisplayNameProvider's
              // fallback-guarded one, since an empty field must show
              // genuinely empty here, not "Friend").
              _SettingsRow(
                glyph: _GlyphShape.person,
                label: l10n.profileYourNameRow,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => OnboardingNameScreen(
                    initialName: currentName,
                    onClose: () => Navigator.of(context).pop(),
                    onSubmit: () => Navigator.of(context).pop(),
                  ),
                )),
              ),
              const HairlineDivider(),
              // Phase 5's Stone Styles feature: opens StoneStyleScreen
              // (`Cairn Stone Styles.dc.html`).
              _SettingsRow(
                glyph: _GlyphShape.stones,
                label: l10n.profileStoneStyleRow,
                onTap: () => openStoneStyleScreen(context),
              ),
              const HairlineDivider(),
              // Moved here from the Trail screen header's "?" info button
              // per an earlier consistency pass (see trail_screen.dart's own
              // doc comment on the removal) - same HowCairnsWorkScreen
              // destination, real navigation rather than a no-op.
              _SettingsRow(
                glyph: _GlyphShape.info,
                label: l10n.profileHowCairnsWorkRow,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const HowCairnsWorkScreen(),
                )),
              ),
              const HairlineDivider(),
              // Opens the hosted privacy policy (AppConfig.privacyUrl, filled
              // in at Phase 5c). Was a no-op long after that URL existed,
              // which left a tappable-looking row that did nothing.
              _SettingsRow(
                glyph: _GlyphShape.shield,
                label: l10n.profilePrivacyRow,
                onTap: () => unawaited(launchExternalUrl(AppConfig.privacyUrl)),
              ),
              const HairlineDivider(),
              _SettingsRow(
                glyph: _GlyphShape.restore,
                label: l10n.profileRestorePurchaseRow,
                onTap: () => _handleRestore(context, ref),
              ),
              if (signedInEmail != null) ...[
                const HairlineDivider(),
                _SettingsRow(
                  glyph: _GlyphShape.trash,
                  label: l10n.accountDeleteRow,
                  isDestructive: true,
                  // Pushed and popped on the SAME navigator. The first cut
                  // pushed with `rootNavigator: true` but popped without it;
                  // both happen to resolve to the root today (nothing nests a
                  // Navigator around AppShell), so it worked by luck and would
                  // have broken quietly the moment one did.
                  onTap: () {
                    final navigator = Navigator.of(context, rootNavigator: true);
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder: (_) => DeleteAccountScreen(
                          email: signedInEmail,
                          onClose: navigator.pop,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.glyph,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final _GlyphShape glyph;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final textColor = isDestructive
        ? AppColors.accountFieldErrorIcon
        : AppColors.inkPrimary;
    final glyphColor = isDestructive
        ? AppColors.accountFieldErrorIcon
        : AppColors.textMuted;

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
              _Glyph(shape: glyph, color: glyphColor, size: 19),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.settingsRowLabel.copyWith(
                    color: textColor,
                  ),
                ),
              ),
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
enum _GlyphShape {
  clockPending,
  check,
  chevronRight,
  bell,
  shield,
  restore,
  info,
  stones,
  person,
  trash,
}

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
        _GlyphShape.stones => 2,
        _GlyphShape.person => 2,
        _GlyphShape.trash => 2,
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
      case _GlyphShape.stones:
        // Three stacked stone outlines, widest at the bottom - a small
        // stroke-based cairn pictogram for the "Stone style" settings row,
        // in the same 24x24 stroke-icon shape as every other glyph on this
        // screen (not a filled/coloured motif like `_PremiumMountainBars` or
        // `_StackedPebbleGlyph` elsewhere in this app, since every other
        // `_GlyphShape` here is an outline).
        canvas.drawOval(Rect.fromCenter(center: p(12, 7.4), width: 8 * s, height: 4.4 * s), paint);
        canvas.drawOval(Rect.fromCenter(center: p(12, 12.6), width: 11.5 * s, height: 5 * s), paint);
        canvas.drawOval(Rect.fromCenter(center: p(12, 18.2), width: 15 * s, height: 5.6 * s), paint);
        break;
      case _GlyphShape.person:
        // The "Your name" settings row's icon: the same silhouette as
        // TabBarIcon's own TabIconShape.you (`<circle cx=12 cy=8 r=3.4/>`
        // plus `M5.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6`), duplicated
        // privately here per this screen's own precedent for small one-off
        // glyphs (e.g. .bell/.shield/.stones above) rather than importing
        // that file's own private painter.
        canvas.drawCircle(p(12, 8), 3.4 * s, paint);
        final shoulders = Path()
          ..moveTo(p(5.5, 20).dx, p(5.5, 20).dy)
          ..cubicTo(
            p(5.5, 16.4).dx,
            p(5.5, 16.4).dy,
            p(8.4, 14).dx,
            p(8.4, 14).dy,
            p(12, 14).dx,
            p(12, 14).dy,
          )
          ..cubicTo(
            p(15.6, 14).dx,
            p(15.6, 14).dy,
            p(18.5, 16.4).dx,
            p(18.5, 16.4).dy,
            p(18.5, 20).dx,
            p(18.5, 20).dy,
          );
        canvas.drawPath(shoulders, paint);
        break;
      case _GlyphShape.trash:
        canvas.drawLine(p(4, 7), p(20, 7), paint);
        final lid = Path()
          ..moveTo(p(9.5, 7).dx, p(9.5, 7).dy)
          ..lineTo(p(9.5, 5.2).dx, p(9.5, 5.2).dy)
          ..arcToPoint(p(10.7, 4), radius: Radius.circular(1.2 * s))
          ..lineTo(p(13.3, 4).dx, p(13.3, 4).dy)
          ..arcToPoint(p(14.5, 5.2), radius: Radius.circular(1.2 * s))
          ..lineTo(p(14.5, 7).dx, p(14.5, 7).dy);
        canvas.drawPath(lid, paint);
        final bin = Path()
          ..moveTo(p(6.4, 7).dx, p(6.4, 7).dy)
          ..lineTo(p(7.3, 19).dx, p(7.3, 19).dy)
          ..arcToPoint(p(8.9, 20.5), radius: Radius.circular(1.6 * s))
          ..lineTo(p(15.1, 20.5).dx, p(15.1, 20.5).dy)
          ..arcToPoint(p(16.7, 19), radius: Radius.circular(1.6 * s))
          ..lineTo(p(17.6, 7).dx, p(17.6, 7).dy);
        canvas.drawPath(bin, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      shape != oldDelegate.shape || color != oldDelegate.color;
}
