import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Which status a [StatusChip] communicates. Each maps to one pill
/// treatment from the design files.
enum StatusChipVariant {
  /// Sage "Verified · 7:14 AM" pill (Home completed card).
  verified,

  /// Muted "Awaiting verification" pill (Home pending card, and the
  /// darker on-photo treatment on the verify-pending screen).
  awaiting,

  /// Outlined "Scheduled · 8:00 PM" pill with a clock glyph (Home
  /// scheduled card).
  scheduled,

  /// Terracotta-dark "Not verified" pill drawn on top of the proof photo
  /// (verify-failed screen).
  notVerified,
}

/// The status pill/chip family used across task cards and the
/// verification flow: one widget, four variants (see
/// [StatusChipVariant]), matching the exact colours/glyphs from the
/// design files rather than each screen inventing its own pill.
///
/// [label] is plain, already-composed text (e.g. "Verified · 7:14 AM"):
/// this widget only owns presentation, not string composition/l10n - the
/// caller interpolates the time via `intl` and picks the ARB string, same
/// as documented on the `verifiedAt`/`scheduledAt`/etc. ARB entries.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.variant,
    required this.label,
    this.onPhoto = false,
  });

  final StatusChipVariant variant;
  final String label;

  /// Whether this chip sits on top of a photo rather than a card
  /// background. Only [StatusChipVariant.awaiting] has a distinct
  /// on-photo treatment in the source files (a darker, blurred pill so it
  /// reads over an arbitrary photo); the other variants render the same
  /// either way.
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    // Chips get dropped into whichever screen/card a later run builds and
    // must not depend on that caller remembering a `Material` ancestor (see
    // AppShell's build() comment for why: without one, Text falls back to
    // MaterialApp's deliberately-ugly red/yellow-underlined debug style).
    // `MaterialType.transparency` fixes text inheritance without painting
    // anything of its own, so it can't cover the chip's own background.
    return Material(type: MaterialType.transparency, child: _buildChip());
  }

  Widget _buildChip() {
    switch (variant) {
      case StatusChipVariant.verified:
        return _FilledChip(
          background: AppColors.sageChipBg,
          iconBackground: AppColors.sage,
          icon: _CheckGlyph(color: AppColors.richCream),
          label: label,
          textColor: AppColors.sageTextStrong,
        );
      case StatusChipVariant.awaiting:
        return onPhoto
            ? _FilledChip(
                background: AppColors.awaitingChipOnPhotoBg,
                iconBackground: AppColors.pendingSealLight,
                icon: const _ClockGlyph(color: AppColors.inkStrong),
                label: label,
                textColor: AppColors.richCream,
                iconSize: 14,
                fontSize: 11.5,
              )
            : _FilledChip(
                background: AppColors.awaitingChipBg,
                iconBackground: AppColors.pendingIconBg,
                icon: const _ClockGlyph(color: AppColors.richCream),
                label: label,
                textColor: AppColors.textMuted,
              );
      case StatusChipVariant.scheduled:
        return _OutlinedChip(label: label);
      case StatusChipVariant.notVerified:
        return _FilledChip(
          background: AppColors.notVerifiedChipBg,
          iconBackground: AppColors.richCream,
          icon: const CloseGlyph(color: AppColors.clayHeading),
          label: label,
          textColor: AppColors.richCream,
          iconSize: 15,
          fontSize: 11,
          radius: 16,
        );
    }
  }
}

class _FilledChip extends StatelessWidget {
  const _FilledChip({
    required this.background,
    required this.iconBackground,
    required this.icon,
    required this.label,
    required this.textColor,
    this.iconSize = 16,
    this.fontSize = 12.5,
    this.radius = AppRadii.pill,
  });

  final Color background;
  final Color iconBackground;
  final Widget icon;
  final String label;
  final Color textColor;
  final double iconSize;
  final double fontSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 11, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Center(child: icon),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.chipLabel.copyWith(
                color: textColor,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinedChip extends StatelessWidget {
  const _OutlinedChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.scheduledPillBorder, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 11,
              height: 11,
              child: _ClockGlyph(color: AppColors.clockGlyph, filled: false),
            ),
            const SizedBox(width: 7),
            Text(label, style: AppTextStyles.scheduledPillLabel),
          ],
        ),
      ),
    );
  }
}

/// Minimal checkmark glyph, matching the verified-chip SVG path
/// (`M5 12.5l4.2 4.2L19 7`).
class _CheckGlyph extends StatelessWidget {
  const _CheckGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(10, 10),
      painter: _CheckGlyphPainter(color: color),
    );
  }
}

class _CheckGlyphPainter extends CustomPainter {
  const _CheckGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.55)
      ..lineTo(size.width * 0.4, size.height * 0.85)
      ..lineTo(size.width * 0.9, size.height * 0.2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckGlyphPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Minimal clock glyph (circle + hands), matching the awaiting/scheduled
/// chip SVGs (`<circle .../><path d="M12 7.5v5l3.2 2">`).
class _ClockGlyph extends StatelessWidget {
  const _ClockGlyph({required this.color, this.filled = true});

  final Color color;

  /// Whether the circle outline is filled by a background already (chip
  /// icon dot) or stands alone (scheduled pill, no dot behind it).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(9, 9),
      painter: _ClockGlyphPainter(color: color, drawCircle: !filled),
    );
  }
}

class _ClockGlyphPainter extends CustomPainter {
  const _ClockGlyphPainter({required this.color, required this.drawCircle});

  final Color color;
  final bool drawCircle;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - paint.strokeWidth / 2;
    if (drawCircle) {
      canvas.drawCircle(center, radius, paint);
    }
    final path = Path()
      ..moveTo(center.dx, center.dy - radius * 0.7)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx + radius * 0.55, center.dy + radius * 0.35);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ClockGlyphPainter oldDelegate) =>
      color != oldDelegate.color || drawCircle != oldDelegate.drawCircle;
}

/// The gallery/photo-stack glyph (rounded frame + lens dot + mountain
/// silhouette), matching `Cairn Camera Capture.dc.html`'s gallery control
/// and reused verbatim (same SVG path, `Cairn Camera Unavailable.dc.html`
/// draws the identical icon) on the Camera Unavailable screen's "Choose
/// from gallery" buttons - hence public and colour-parameterised here
/// rather than a private painter duplicated in each screen file.
class GalleryGlyph extends StatelessWidget {
  const GalleryGlyph({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GalleryGlyphPainter(color: color)),
    );
  }
}

class _GalleryGlyphPainter extends CustomPainter {
  const _GalleryGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3 * w, 4 * h, 18 * w, 16 * h),
        Radius.circular(3 * w),
      ),
      stroke,
    );
    canvas.drawCircle(Offset(8.5 * w, 9.5 * h), 1.6 * w, stroke);
    final path = Path()
      ..moveTo(3.5 * w, 17 * h)
      ..lineTo(8.5 * w, 12.5 * h)
      ..lineTo(12.5 * w, 16 * h)
      ..lineTo(15.5 * w, 13.5 * h)
      ..lineTo(20.5 * w, 18 * h);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_GalleryGlyphPainter oldDelegate) => color != oldDelegate.color;
}

/// Minimal close/X glyph, matching the not-verified chip SVG
/// (`M6 6l12 12M18 6L6 18`). Public (not just this file's own chip icon) so
/// the verification-flow screens' header close button
/// (`verification_chrome.dart`) can reuse the same glyph at a larger size
/// rather than a near-duplicate painter.
class CloseGlyph extends StatelessWidget {
  const CloseGlyph({super.key, required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CloseGlyphPainter(color: color),
    );
  }
}

class _CloseGlyphPainter extends CustomPainter {
  const _CloseGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.15),
      Offset(size.width * 0.85, size.height * 0.85),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.85, size.height * 0.15),
      Offset(size.width * 0.15, size.height * 0.85),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CloseGlyphPainter oldDelegate) =>
      color != oldDelegate.color;
}
