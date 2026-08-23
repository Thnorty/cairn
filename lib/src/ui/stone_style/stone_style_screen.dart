import 'package:flutter/material.dart' show Material, MaterialPageRoute, MaterialType;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../models/stone_style.dart';
import '../../providers.dart';
import '../premium/premium_screen.dart' show openPremiumScreen;
import '../proof/verification_chrome.dart' show CloseCircleButton, SealCheckmarkIcon;
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/cairn_stack.dart';

/// Pushes [StoneStyleScreen] on top of the current route. Mirrors
/// `premium_screen.dart`'s own `openPremiumScreen` so every entry point
/// (today just Profile's settings row) navigates identically.
void openStoneStyleScreen(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => const StoneStyleScreen(),
  ));
}

/// The four styles in ladder order (lightest to darkest), matching
/// `Cairn Stone Styles.dc.html`'s own layout and header comment.
const List<StoneStyle> _ladderOrder = [
  StoneStyle.river,
  StoneStyle.granite,
  StoneStyle.slate,
  StoneStyle.basalt,
];

String _nameFor(AppLocalizations l10n, StoneStyle style) => switch (style) {
      StoneStyle.river => l10n.stoneStyleRiverName,
      StoneStyle.granite => l10n.stoneStyleGraniteName,
      StoneStyle.slate => l10n.stoneStyleSlateName,
      StoneStyle.basalt => l10n.stoneStyleBasaltName,
    };

String _descriptionFor(AppLocalizations l10n, StoneStyle style) => switch (style) {
      StoneStyle.river => l10n.stoneStyleRiverDescription,
      StoneStyle.granite => l10n.stoneStyleGraniteDescription,
      StoneStyle.slate => l10n.stoneStyleSlateDescription,
      StoneStyle.basalt => l10n.stoneStyleBasaltDescription,
    };

/// `Cairn Stone Styles.dc.html`: the Stone Style picker, reached from
/// Profile's settings list. Lets a premium user choose which of the four
/// stone palettes (see [StoneStyle]) every cairn in the app is drawn in;
/// free users can only ever have [StoneStyle.river] applied, and see the
/// other three styles locked (fully legible, dimmed, never blurred/hidden -
/// see the design's own header comment on why).
///
/// Selection and application are deliberately separate (the design's own
/// "APPLY" section): tapping a tile only changes this screen's local
/// [_selected] state; the footer's Apply button is what actually persists
/// it via [SettingsRepository.setStoneStyle] and refreshes
/// [storedStoneStyleProvider]. Apply is disabled whenever [_selected]
/// already equals the currently-*applied* style (see
/// [effectiveStoneStyleProvider] - deliberately the *effective*, not the
/// raw stored, style: a lapsed premium user's stored pick is locked and
/// can't be re-selected here anyway, so treating [StoneStyle.river] as
/// "applied" while lapsed is what makes the free-state screenshot in the
/// design - River checked, nothing else selectable - fall out correctly
/// even for that case), so opening and closing this screen without tapping
/// anything can never change what's applied. Backing out (the close-X)
/// discards [_selected] entirely, since it's never persisted until Apply.
class StoneStyleScreen extends ConsumerStatefulWidget {
  const StoneStyleScreen({super.key});

  @override
  ConsumerState<StoneStyleScreen> createState() => _StoneStyleScreenState();
}

class _StoneStyleScreenState extends ConsumerState<StoneStyleScreen> {
  /// The tapped-but-not-yet-applied style; null until the user taps an
  /// unlocked tile, meaning "no explicit tap yet, so the selection is
  /// whatever's currently applied" (see [build]'s own `applied`/`selected`
  /// locals).
  StoneStyle? _selected;

  bool _applying = false;

  void _handleTileTap(StoneStyle style, bool isPremium) {
    if (style.requiresPremium && !isPremium) {
      // A locked tile opens the paywall instead of selecting - the same
      // behaviour Stats' own locked "Deeper insights" card uses.
      openPremiumScreen(context);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _selected = style);
  }

  Future<void> _handleApply(StoneStyle target) async {
    HapticFeedback.mediumImpact();
    setState(() => _applying = true);
    await ref.read(settingsRepositoryProvider).setStoneStyle(target);
    ref.invalidate(storedStoneStyleProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = ref.watch(premiumStatusProvider);
    // The *effective*, not the raw stored, style - see this class's own doc
    // comment on why.
    final applied = ref.watch(effectiveStoneStyleProvider);
    final selected = _selected ?? applied;

    return ModalScaffold(
      washes: const [
        RadialGradient(
          center: Alignment(0, -1.12),
          radius: 1.3,
          colors: [AppColors.stoneStyleWash, AppColors.dustWashEnd],
        ),
      ],
      // The design's own phone-screen background is a single warm wash with
      // no topographic contour rings at all (unlike every other modal screen
      // in this app) - see `Cairn Stone Styles.dc.html`'s inner screen div,
      // which has no `repeating-radial-gradient` layer.
      showContour: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: CloseCircleButton(onTap: () => Navigator.of(context).pop()),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(26, 2, 26, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(l10n: l10n, isPremium: isPremium),
                  const SizedBox(height: 22),
                  _StyleGrid(
                    l10n: l10n,
                    selected: selected,
                    isPremium: isPremium,
                    onTap: _applying
                        ? null
                        : (style) => _handleTileTap(style, isPremium),
                  ),
                ],
              ),
            ),
          ),
          if (isPremium)
            _EntitledFooter(
              l10n: l10n,
              label: l10n.stoneStyleApplyButton(_nameFor(l10n, selected)),
              onApply: (!_applying && selected != applied)
                  ? () => _handleApply(selected)
                  : null,
            )
          else
            _FreeFooter(l10n: l10n, onUnlock: () => openPremiumScreen(context)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header: eyebrow (+ PREMIUM pill when entitled) / title / subtitle
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.l10n, required this.isPremium});

  final AppLocalizations l10n;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(l10n.stoneStyleEyebrow, style: AppTextStyles.sectionLabel),
            if (isPremium) ...[
              const SizedBox(width: 9),
              _PremiumPill(label: l10n.statsPremiumBadge),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Text(l10n.stoneStyleTitle, style: AppTextStyles.screenTitle),
        const SizedBox(height: 9),
        Text(l10n.stoneStyleSubtitle, style: AppTextStyles.stoneStyleSubtitle),
      ],
    );
  }
}

/// The small sage "PREMIUM" pill next to the eyebrow, once entitled - the
/// exact same treatment (colour tokens and text style) as the Stats
/// screen's own "Deeper insights" section-label pill, per this run's spec.
class _PremiumPill extends StatelessWidget {
  const _PremiumPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.achievedTierIconBg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Text(label, style: AppTextStyles.statsInsightsPremiumBadgeLabel),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Style grid: 2 columns x 2 rows, ladder order
// ---------------------------------------------------------------------------

class _StyleGrid extends StatelessWidget {
  const _StyleGrid({
    required this.l10n,
    required this.selected,
    required this.isPremium,
    required this.onTap,
  });

  final AppLocalizations l10n;
  final StoneStyle selected;
  final bool isPremium;

  /// Null while an Apply is in flight, disabling every tile until it
  /// resolves (the screen pops right after, so this window is brief).
  final ValueChanged<StoneStyle>? onTap;

  Widget _tile(StoneStyle style) {
    final locked = style.requiresPremium && !isPremium;
    final tap = onTap;
    return _StyleTile(
      key: ValueKey('stone-style-tile-${style.name}'),
      style: style,
      name: _nameFor(l10n, style),
      description: _descriptionFor(l10n, style),
      locked: locked,
      selected: style == selected,
      onTap: tap == null ? null : () => tap(style),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _tile(_ladderOrder[0])),
            const SizedBox(width: 12),
            Expanded(child: _tile(_ladderOrder[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _tile(_ladderOrder[2])),
            const SizedBox(width: 12),
            Expanded(child: _tile(_ladderOrder[3])),
          ],
        ),
      ],
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    super.key,
    required this.style,
    required this.name,
    required this.description,
    required this.locked,
    required this.selected,
    required this.onTap,
  });

  final StoneStyle style;
  final String name;
  final String description;
  final bool locked;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.rowCard);
    final gradient = locked
        ? const LinearGradient(
            begin: Alignment(-0.5, -1),
            end: Alignment(0.5, 1),
            colors: [
              AppColors.stoneStyleLockedTileLight,
              AppColors.stoneStyleLockedTileDark,
            ],
          )
        : AppGradients.card;

    final nameStyle = locked
        ? AppTextStyles.smallCardTitle.copyWith(color: AppColors.premiumDimmedTitle)
        : AppTextStyles.smallCardTitle;
    final descriptionStyle = locked
        ? AppTextStyles.stoneStyleTileDescription.copyWith(color: AppColors.textFaint)
        : AppTextStyles.stoneStyleTileDescription;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(
          color: selected ? AppColors.sage : AppColors.panelBorder,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected ? AppShadows.stoneStyleSelectedTile : null,
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
              padding: const EdgeInsetsDirectional.fromSTEB(12, 16, 12, 13),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 58,
                      child: Center(
                        child: Opacity(
                          opacity: locked ? 0.68 : 1.0,
                          // Every tile, including locked ones, previews the
                          // real 5-stone CairnStack with its top stone
                          // highlighted sage - CairnStack itself never themes
                          // that stone (see its own doc comment), so this is
                          // simultaneously "what this style looks like" and
                          // "the top stone is always sage, in every style".
                          child: CairnStack(
                            stoneCount: 5,
                            style: style,
                            highlightTop: true,
                            scale: 0.55,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(name, textAlign: TextAlign.center, style: nameStyle),
                    const SizedBox(height: 1),
                    Text(description, textAlign: TextAlign.center, style: descriptionStyle),
                  ],
                ),
              ),
            ),
            if (selected)
              const PositionedDirectional(top: 11, end: 11, child: _CheckBadge())
            else if (locked)
              const PositionedDirectional(top: 11, end: 11, child: _LockBadge()),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        selected: selected,
        label: name,
        child: tile,
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const SealCheckmarkIcon(color: AppColors.richCream, size: 12),
    );
  }
}

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(color: AppColors.statsMutedFillBg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const SizedBox(width: 11, height: 11, child: CustomPaint(painter: _LockGlyphPainter())),
    );
  }
}

/// The picker's own small lock glyph (a rounded body rect plus a shackle
/// arc), the same silhouette as `stats_screen.dart`'s private
/// `_LockGlyphPainter` - duplicated privately here per this codebase's
/// existing precedent for small one-off glyphs used in only one file (e.g.
/// that same Stats glyph's own doc comment on `profile_screen.dart`'s
/// `_GlyphShape.bell`/`.shield`).
class _LockGlyphPainter extends CustomPainter {
  const _LockGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final paint = Paint()
      ..color = AppColors.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * s
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

// ---------------------------------------------------------------------------
// Footers
// ---------------------------------------------------------------------------

class _FreeFooter extends StatelessWidget {
  const _FreeFooter({required this.l10n, required this.onUnlock});

  final AppLocalizations l10n;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(26, 12, 26, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(label: l10n.stoneStyleUnlockButton, onPressed: onUnlock),
          const SizedBox(height: 10),
          Text(
            l10n.stoneStyleFreeFooterCaption,
            textAlign: TextAlign.center,
            style: AppTextStyles.statsResetCaption,
          ),
        ],
      ),
    );
  }
}

class _EntitledFooter extends StatelessWidget {
  const _EntitledFooter({required this.l10n, required this.label, required this.onApply});

  final AppLocalizations l10n;
  final String label;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(26, 12, 26, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: label,
            onPressed: onApply,
            color: PrimaryButtonColor.sage,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.stoneStyleEntitledFooterCaption,
            textAlign: TextAlign.center,
            style: AppTextStyles.statsResetCaption,
          ),
        ],
      ),
    );
  }
}
