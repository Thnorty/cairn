import 'dart:io';

import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../db/database.dart' show Completion;
import '../../l10n/date_number_formatting.dart';
import '../../services/home_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/buttons.dart';
import '../widgets/card_surface.dart';
import '../widgets/cairn_stack.dart';
import '../widgets/ghost_cairn.dart';
import '../widgets/status_chip.dart';

/// Builds a "HH:mm" 24-hour due time into a throwaway [DateTime] purely so
/// [formatTimeOfDay] (which formats a `DateTime`'s time-of-day component)
/// can render it in the locale's preferred 12/24-hour convention. Only the
/// hour/minute are meaningful; the date fields are arbitrary and unused.
DateTime _timeOfDay(String hhmm) {
  final parts = hhmm.split(':');
  return DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
}

/// One card on the Home screen: renders [HomeOccurrenceCard] in whichever
/// of its four states it's in (see `Cairn Home.dc.html`'s four card
/// examples). Reused as-is by the screenshot harness to render a specific
/// state in isolation.
class HomeOccurrenceCardView extends StatelessWidget {
  const HomeOccurrenceCardView({
    super.key,
    required this.card,
    required this.onProveIt,
  });

  final HomeOccurrenceCard card;
  final VoidCallback onProveIt;

  @override
  Widget build(BuildContext context) {
    switch (card.status) {
      case HomeCardStatus.verified:
        return _VerifiedCard(card: card);
      case HomeCardStatus.awaitingVerification:
        return _AwaitingCard(card: card);
      case HomeCardStatus.due:
        return _DueCard(card: card, onProveIt: onProveIt);
      case HomeCardStatus.scheduled:
        return _ScheduledCard(card: card, onProveIt: onProveIt);
    }
  }
}

class _VerifiedCard extends StatelessWidget {
  const _VerifiedCard({required this.card});

  final HomeOccurrenceCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final completion = card.completion!;
    final time = formatTimeOfDay(
      DateTime.fromMillisecondsSinceEpoch(completion.completedAt),
      locale,
    );

    return CardSurface(
      variant: CardRadiusVariant.a,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _CairnColumn(stoneCount: card.stoneCount, highlightTop: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(card.taskTitle, style: AppTextStyles.taskTitle),
                    ),
                    const SizedBox(width: 10),
                    _ProofThumbnail(completion: completion),
                  ],
                ),
                const SizedBox(height: 9),
                StatusChip(
                  variant: StatusChipVariant.verified,
                  label: l10n.verifiedAt(time),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.taskSummaryVerifiedNewStone(
                    card.currentCairnIndex,
                    card.stoneCount,
                  ),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AwaitingCard extends StatelessWidget {
  const _AwaitingCard({required this.card});

  final HomeOccurrenceCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final completion = card.completion!;
    final metres = formatMetresNumber(completion.pointsAwarded, locale);

    return CardSurface(
      variant: CardRadiusVariant.b,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _CairnColumn(stoneCount: card.stoneCount, pendingTop: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(card.taskTitle, style: AppTextStyles.taskTitle),
                    ),
                    const SizedBox(width: 10),
                    _ProofThumbnail(completion: completion),
                  ],
                ),
                const SizedBox(height: 9),
                StatusChip(
                  variant: StatusChipVariant.awaiting,
                  label: l10n.awaitingVerificationChip,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.taskSummaryAwaitingVerification(
                    card.currentCairnIndex,
                    card.stoneCount,
                    metres,
                  ),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard({required this.card, required this.onProveIt});

  final HomeOccurrenceCard card;
  final VoidCallback onProveIt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CardSurface(
      variant: CardRadiusVariant.b,
      padding: const EdgeInsetsDirectional.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CairnColumn(stoneCount: card.stoneCount),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.taskTitle, style: AppTextStyles.taskTitle),
                const SizedBox(height: 4),
                Text(
                  l10n.taskSummaryDueToday(card.currentCairnIndex, card.stoneCount),
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: l10n.proveItButton,
                  onPressed: onProveIt,
                  size: PrimaryButtonSize.small,
                  expand: false,
                  icon: const _CameraGlyph(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The SCHEDULED state: a today occurrence not yet completed whose due time
/// is still ahead. `Cairn Home.dc.html`'s Card 3 (updated 2026-07-16, real-
/// device test feedback) shows the "Scheduled · HH:MM" chip as before *and*
/// a working terracotta "Prove it" button beneath it - a task scheduled for
/// later today is still completable *now* (the repository's own guard is
/// "is this a generated occurrence for today", not "has its due time
/// passed" - see `HomeService.isOccurrenceDueBy`'s doc comment and
/// `CompletionRepository`'s no-back-fill rule, neither of which this card
/// changes). [onProveIt] runs the exact same precheck-and-route path
/// [_DueCard] does.
class _ScheduledCard extends StatelessWidget {
  const _ScheduledCard({required this.card, required this.onProveIt});

  final HomeOccurrenceCard card;
  final VoidCallback onProveIt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final time = formatTimeOfDay(_timeOfDay(card.dueTime!), locale);

    return CardSurface(
      variant: CardRadiusVariant.a,
      dimmed: true,
      padding: const EdgeInsetsDirectional.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Real-device fix: the design still gives this card its own
          // paler surface (CardSurface's `dimmed` gradient/border/shadow,
          // unaffected by this change) and its mini-cairn its own muted
          // stone palette, but the design's whole-stack `opacity:.75` fade
          // is gone - a scheduled task is now clearly actionable, not
          // visually inert, so `mutedOpacity: false` keeps the muted
          // colours without the extra dimming (see CairnStack's own doc
          // comment on why those are two independent things).
          _CairnColumn(
            stoneCount: card.stoneCount,
            muted: true,
            mutedOpacity: false,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.taskTitle, style: AppTextStyles.taskTitleDimmed),
                const SizedBox(height: 4),
                Text(
                  l10n.taskSummaryScheduled(card.currentCairnIndex, card.stoneCount),
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 13),
                StatusChip(
                  variant: StatusChipVariant.scheduled,
                  label: l10n.scheduledAt(time),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: l10n.proveItButton,
                  onPressed: onProveIt,
                  size: PrimaryButtonSize.small,
                  expand: false,
                  icon: const _CameraGlyph(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The fixed-width mini-cairn column every card state shares (`width:60px`
/// in the source files). The source files leave `align-items` at its CSS
/// default (`stretch`) on the verified/awaiting cards' row, which in CSS
/// means "match the row's tallest child, then bottom-align the shorter
/// one" - not Flutter's `CrossAxisAlignment.stretch`, which instead forces
/// every child to the row's own *incoming* height constraint and crashes
/// with "BoxConstraints forces an infinite height" the moment that
/// constraint is unbounded (as it is here: the row sizes to its content
/// inside a `ListView` item, so nothing above it ever hands it a bounded
/// height to stretch to). `CrossAxisAlignment.end` reproduces the same
/// *visual* result CSS stretch+bottom-align gives here - the shorter mini-
/// cairn column sitting at the bottom of the row next to the taller info
/// column - without needing a bounded incoming height at all, since Flutter
/// sizes an unbounded `Row` to its tallest child by construction. See
/// `_VerifiedCard`/`_AwaitingCard`'s `Row`s for the `end` alignment this
/// pairs with; due/scheduled cards use `CrossAxisAlignment.center` instead,
/// matching their `align-items:center` in the source files.
class _CairnColumn extends StatelessWidget {
  const _CairnColumn({
    required this.stoneCount,
    this.muted = false,
    this.mutedOpacity = true,
    this.highlightTop = false,
    this.pendingTop = false,
  });

  final int stoneCount;
  final bool muted;

  /// Forwarded to [CairnStack.mutedOpacity]; see that widget's doc comment.
  final bool mutedOpacity;
  final bool highlightTop;
  final bool pendingTop;

  /// Scales [GhostCairnStack] (native ground-shadow width 64px) down to
  /// roughly the same visual weight a real [CairnStack]'s base/ground
  /// footprint has in this same 60px column (see that widget's width
  /// envelope: a base stone runs ~42-44px wide, so its ground shadow runs
  /// ~46-48px).
  static const double _zeroStoneScale = 0.7;

  @override
  Widget build(BuildContext context) {
    // A brand new task starts with zero completions (DUE/SCHEDULED are the
    // only states that can reach here with none yet - a card with a
    // completion always has at least one stone). None of the static
    // mockups show this "cairn hasn't started" moment, and CairnStack
    // itself requires at least one stone (`assert(stoneCount >= 1, ...)`).
    // Design-owner decision: render the dashed ghost cairn already used for
    // "no tasks at all" (`Cairn Empty Today.dc.html`), scaled down to fit
    // this column, rather than an invented "empty stack" treatment or a
    // bare gap.
    if (stoneCount == 0) {
      return const SizedBox(
        width: 60,
        child: Center(child: GhostCairnStack(scale: _zeroStoneScale)),
      );
    }

    final stack = CairnStack(
      stoneCount: stoneCount,
      muted: muted,
      mutedOpacity: mutedOpacity,
      highlightTop: highlightTop,
      pendingTop: pendingTop,
    );
    // Horizontal centering only: the row's own `crossAxisAlignment` (see
    // class doc comment) handles vertical positioning.
    return SizedBox(
      width: 60,
      child: Center(child: stack),
    );
  }
}

/// The 46x46 proof thumbnail shown on verified/awaiting cards: the real
/// proof photo when [Completion.proofPhotoPath] points at a file that still
/// exists, or a diagonal-stripe placeholder swatch otherwise (e.g. a Phase 1
/// debug-inserted completion never had a photo to begin with).
class _ProofThumbnail extends StatelessWidget {
  const _ProofThumbnail({required this.completion});

  final Completion completion;

  @override
  Widget build(BuildContext context) {
    final path = completion.proofPhotoPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.proofThumb),
      child: SizedBox(
        width: 46,
        height: 46,
        child: path == null
            ? const _ProofPlaceholder()
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const _ProofPlaceholder(),
              ),
      ),
    );
  }
}

class _ProofPlaceholder extends StatelessWidget {
  const _ProofPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.stoneShadowMuted),
      child: CustomPaint(
        painter: const _DiagonalStripesPainter(),
        child: Material(
          type: MaterialType.transparency,
          child: Align(
            alignment: AlignmentDirectional.bottomCenter,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 3),
              child: Text(
                l10n.proofThumbnailPlaceholderLabel,
                style: const TextStyle(
                  // Explicit, not inherited: the source file sets
                  // `font-family:ui-monospace,monospace` for this caption,
                  // but the app bundles no monospace family, so naming one
                  // that doesn't exist would render as a missing-glyph box
                  // (the same failure PlusGlyph's doc comment describes) -
                  // every TextStyle in this app must name one of the two
                  // families actually bundled (Zilla Slab / Work Sans).
                  // Work Sans, not the monospace the design asks for, is
                  // the closest bundled substitute for a small caption.
                  fontFamily: AppFontFamilies.workSans,
                  fontSize: 7,
                  color: AppColors.accountIconStroke,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reproduces the placeholder swatch's
/// `repeating-linear-gradient(135deg,#cfc6b4 0 6px,#c4baa7 6px 12px)`: hard
/// alternating diagonal stripes, which Flutter's gradient APIs can't
/// express directly (no hard-stop tiling primitive), so this paints them
/// by hand instead.
class _DiagonalStripesPainter extends CustomPainter {
  const _DiagonalStripesPainter();

  static const double _bandWidth = 6;
  static const Color _light = Color(0xFFCFC6B4);
  static const Color _dark = Color(0xFFC4BAA7);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _light);
    final paint = Paint()..color = _dark;
    // 135deg stripes: draw dark parallelogram bands running from
    // bottom-left to top-right, spaced two band-widths apart along the
    // diagonal, wide enough to cover the whole tile at any aspect ratio.
    final diagonal = size.width + size.height;
    for (double offset = -diagonal; offset < diagonal; offset += _bandWidth * 2) {
      final path = Path()
        ..moveTo(offset, 0)
        ..lineTo(offset + _bandWidth, 0)
        ..lineTo(offset + _bandWidth - size.height, size.height)
        ..lineTo(offset - size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DiagonalStripesPainter oldDelegate) => false;
}

/// Minimal camera glyph on the "Prove it" button, matching the source
/// file's nested-div camera icon (a rounded rect body, a circular lens, and
/// a small viewfinder bump on top).
class _CameraGlyph extends StatelessWidget {
  const _CameraGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 15,
      height: 15,
      child: CustomPaint(painter: _CameraGlyphPainter()),
    );
  }
}

class _CameraGlyphPainter extends CustomPainter {
  const _CameraGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.buttonText
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final bodyRect = Rect.fromLTWH(0, size.height - 13, 15, 13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(3.5)),
      stroke,
    );

    final bumpRect = Rect.fromLTWH(3, size.height - 16, 5, 3);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        bumpRect,
        topLeft: const Radius.circular(1.5),
        topRight: const Radius.circular(1.5),
      ),
      stroke,
    );

    canvas.drawCircle(
      Offset(bodyRect.center.dx, bodyRect.center.dy),
      2.5,
      stroke,
    );
  }

  @override
  bool shouldRepaint(_CameraGlyphPainter oldDelegate) => false;
}
