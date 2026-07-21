/// Shared chrome for the verification-flow outcome screens (Result, Failed,
/// Failed - No Retries, Pending): the header row (close button + the
/// "VERIFICATION" label, all four `Cairn Verify *.dc.html` files share this
/// exact treatment), the circular seal/icon, the proof-photo pebble, and the
/// reason/info banner. Factored out here rather than duplicated four times,
/// since the four screens differ only in seal colour/icon, banner copy/tint,
/// and footer actions - not in this shared shell.
///
/// Deliberately does *not* attempt to reproduce each design file's mockup
/// phone frame (the fake status bar / rounded device bezel / home-indicator
/// bar): those are the `.dc.html` preview's own presentation chrome, not
/// real UI - exactly like `HomeScreen` and every other Phase 3 screen so
/// far, which render only the actual app content below the OS's own status
/// bar.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart'
    show Material, MaterialLocalizations, MaterialType;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/status_chip.dart';

/// Top bar shared by Result/Failed/Pending: a close (X) button, the
/// centered uppercase "VERIFICATION" label, and a matching spacer on the
/// other side so the label stays visually centered.
class VerificationHeader extends StatelessWidget {
  const VerificationHeader({
    super.key,
    required this.onClose,
    this.label,
    this.labelColor,
  });

  final VoidCallback onClose;

  /// Overrides the centered label, defaulting to
  /// [AppLocalizations.verificationHeaderLabel]. The Camera Unavailable
  /// screen reuses this exact header shell with its own "PROVE IT" label
  /// (`Cairn Camera Unavailable.dc.html`'s header row is structurally
  /// identical to the verification-flow screens', just a different word)
  /// rather than duplicating the close-button/spacer layout for one string.
  final String? label;

  /// Overrides [AppTextStyles.sectionLabel]'s default [AppColors.labelGrey]
  /// tint, defaulting to null (the plain grey). `Cairn Verify Result - Cairn
  /// Complete.dc.html`'s own header label is sage-tinted
  /// ([AppColors.sageText]) rather than the neutral grey every other header
  /// (VERIFICATION, PROVE IT, HOW CAIRNS WORK) uses, so this stays an
  /// opt-in override rather than changing the shared default.
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = labelColor == null
        ? AppTextStyles.sectionLabel
        : AppTextStyles.sectionLabel.copyWith(color: labelColor);
    return Padding(
      // Symmetric top-left corner inset so the close (X) button sits the
      // same distance from the top and the left edge (16/16), shared by
      // every screen that uses this header.
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CloseCircleButton(onTap: onClose),
          Text(label ?? l10n.verificationHeaderLabel, style: style),
          const SizedBox(width: 38),
        ],
      ),
    );
  }
}

/// The circular close (X) button reused by the verification header and by
/// the Daily Limit screen's own top-right-only close control.
class CloseCircleButton extends StatelessWidget {
  const CloseCircleButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // MaterialLocalizations' own closeButtonLabel, not a new ARB string:
    // this is a framework-provided, already-localized label for a
    // decorative icon-only affordance with no visible text of its own.
    final closeLabel = MaterialLocalizations.of(context).closeButtonLabel;
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        label: closeLabel,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.awaitingChipBg, // rgba(120,108,88,.14)
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const CloseGlyph(color: AppColors.iconMuted, size: 16),
          ),
        ),
      ),
    );
  }
}

/// The circular gradient seal with a small icon glyph inside, used at the
/// top of the Result/Failed/Pending body (sage/clay/pending-toned per
/// screen). The 8px halo ring and drop shadow colours are supplied by the
/// caller since each screen tints them slightly differently.
class SealCircle extends StatelessWidget {
  const SealCircle({
    super.key,
    required this.gradientColors,
    required this.ringColor,
    required this.shadowColor,
    required this.icon,
    this.size = 60,
  });

  final List<Color> gradientColors;
  final Color ringColor;
  final Color shadowColor;
  final Widget icon;

  /// Diameter in logical pixels. 60 (the default) matches every
  /// Result/Failed/Pending screen; the Camera Unavailable screen's own seal
  /// is a shade larger (64px in `Cairn Camera Unavailable.dc.html`).
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: const Alignment(-0.64, -1),
          end: const Alignment(0.64, 1),
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(color: ringColor, spreadRadius: 8),
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 10),
            blurRadius: 18,
            spreadRadius: -8,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: icon,
    );
  }
}

/// The proof-photo pebble shown on every verification outcome screen: the
/// just-captured/picked photo (see `ProofFlowService`'s doc comment on why
/// this is in-memory bytes, not a re-read from disk), an optional status
/// chip overlaid in its top-left corner, or a neutral placeholder when no
/// photo bytes are available at all (the only real case: the Failed - No
/// Retries screen reached directly from Home's precheck, before any photo
/// was ever captured this time).
class ProofPhotoPebble extends StatelessWidget {
  const ProofPhotoPebble({
    super.key,
    required this.imageBytes,
    this.overlay,
    this.height = 180,
  });

  final Uint8List? imageBytes;
  final Widget? overlay;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bytes = imageBytes;
    return Container(
      width: double.infinity,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.proofPhoto),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.proofPhoto,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          bytes == null
              ? const _ProofPhotoPlaceholder()
              : Image.memory(bytes, fit: BoxFit.cover),
          if (overlay != null)
            Positioned(top: 12, left: 12, child: overlay!),
        ],
      ),
    );
  }
}

class _ProofPhotoPlaceholder extends StatelessWidget {
  const _ProofPhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.stoneShadowMuted),
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Text(
            l10n.proofThumbnailPlaceholderLabel,
            style: const TextStyle(
              fontFamily: AppFontFamilies.workSans,
              fontSize: 11,
              color: AppColors.accountIconStroke,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// The tinted icon+text info/reason banner shared by every verification
/// outcome screen: an accepted reason ("Looks good. ..."), a rejection
/// reason (the verifier's own text, or the stale-photo/no-retries client
/// copy), or the offline reassurance message. [leadText], when given,
/// renders bold ahead of [bodyText] in the same paragraph (matching each
/// design file's `<strong>` span) rather than as a separate widget.
class ReasonBanner extends StatelessWidget {
  const ReasonBanner({
    super.key,
    required this.backgroundColor,
    required this.iconColor,
    this.leadText,
    this.bodyText,
    required this.textColor,
    this.leadColor,
    this.spans,
  }) : assert(
          spans != null || bodyText != null,
          'ReasonBanner needs either bodyText (with an optional leadText) '
          'or a fully custom spans list',
        );

  final Color backgroundColor;
  final Color iconColor;
  final String? leadText;
  final String? bodyText;
  final Color textColor;
  final Color? leadColor;

  /// Fully custom rich-text content, for a design whose bold span sits in
  /// the *middle* of the sentence rather than as a simple lead-then-body
  /// (e.g. `Cairn Camera Unavailable.dc.html`'s Settings hint: "...allow
  /// Cairn camera access in **Settings › Privacy**. Gallery proofs...").
  /// When given, this replaces the [leadText]/[bodyText] composition
  /// entirely; callers still get this banner's icon/box chrome and base
  /// text style (family/size/colour), since child spans with no [TextStyle]
  /// of their own inherit it.
  final List<InlineSpan>? spans;

  @override
  Widget build(BuildContext context) {
    final lead = leadText;
    final content = spans ??
        [
          if (lead != null)
            TextSpan(
              text: '$lead ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: leadColor ?? textColor,
              ),
            ),
          TextSpan(text: bodyText),
        ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 1),
            child: SizedBox(
              width: 17,
              height: 17,
              child: CustomPaint(painter: _InfoGlyphPainter(color: iconColor)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            // Text.rich (not a bare RichText): same rendering, but
            // discoverable by `find.text()` in widget tests without the
            // `findRichText: true` opt-in a raw RichText would require -
            // consistent with every other text widget in this app.
            child: Material(
              type: MaterialType.transparency,
              child: Text.rich(
                TextSpan(
                  style: AppTextStyles.body.copyWith(color: textColor, height: 1.5),
                  children: content,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The soft parchment "info card" treatment for a remaining-attempts figure:
/// a small icon circle inside a rounded gradient card
/// (`Cairn Verify Too Old.dc.html`'s "doesn't use a try" card), reused as-is
/// by [VerifyFailedScreen] for its own tries-left figure - that screen used
/// to render it as a small muted footer caption, easy to miss (see this
/// run's spec), so it now gets this same clear card treatment instead of an
/// invented new component style.
///
/// [leadText], when given, renders in the banner's plain body weight ahead
/// of the always-bold [emphasisText] (matching the too-old screen's own
/// "This didn't use a try. **You still have N left today.**" two-tone
/// split); when omitted, [emphasisText] is the whole line, rendered bold in
/// full (the too-old screen never needs this - `VerifyFailedScreen`'s own
/// copy is already one complete sentence with no separate lead clause).
class AttemptsInfoCard extends StatelessWidget {
  const AttemptsInfoCard({
    super.key,
    required this.icon,
    required this.iconBackground,
    this.leadText,
    required this.emphasisText,
  });

  final Widget icon;
  final Color iconBackground;
  final String? leadText;
  final String emphasisText;

  @override
  Widget build(BuildContext context) {
    final lead = leadText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontFamily: AppFontFamilies.workSans,
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.reasonBannerText,
                  ),
                  children: [
                    if (lead != null) TextSpan(text: '$lead '),
                    TextSpan(
                      text: emphasisText,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.cardEmphasisText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A generic "info" glyph (circle + short vertical stroke + dot), matching
/// the reason-banner SVGs in every verification design file
/// (`<circle r="9"/><path d="M12 11v5"/><circle r="0.4" fill=".../>`).
class _InfoGlyphPainter extends CustomPainter {
  const _InfoGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - stroke.strokeWidth / 2;
    canvas.drawCircle(center, radius, stroke);
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.15),
      Offset(center.dx, center.dy + radius * 0.5),
      stroke,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius * 0.55),
      0.6,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_InfoGlyphPainter oldDelegate) => color != oldDelegate.color;
}

/// The thick checkmark glyph inside the Verify Result screen's sage seal
/// (`M5 12.5l4.2 4.2L19 7`).
class SealCheckmarkIcon extends StatelessWidget {
  const SealCheckmarkIcon({super.key, this.color = AppColors.richCream, this.size = 28});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CheckmarkPainter(color: color)),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  const _CheckmarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.093
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.76)
      ..lineTo(size.width * 0.82, size.height * 0.25);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) => color != oldDelegate.color;
}

/// The exclamation-mark glyph inside the Verify Failed screens' clay seal
/// (`M12 8v5` + a small dot below).
class SealExclamationIcon extends StatelessWidget {
  const SealExclamationIcon({super.key, this.color = const Color(0xFFF4ECE3), this.size = 26});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ExclamationPainter(color: color)),
    );
  }
}

class _ExclamationPainter extends CustomPainter {
  const _ExclamationPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.3),
      Offset(size.width * 0.5, size.height * 0.62),
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.82),
      size.width * 0.045,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_ExclamationPainter oldDelegate) => color != oldDelegate.color;
}

/// The clock glyph inside the Verify Pending screen's muted seal (circle +
/// hands, `M12 7v5l3.4 2.1`).
class SealClockIcon extends StatelessWidget {
  const SealClockIcon({super.key, this.color = AppColors.richCream, this.size = 28});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SealClockPainter(color: color)),
    );
  }
}

class _SealClockPainter extends CustomPainter {
  const _SealClockPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - paint.strokeWidth / 2 - 1;
    canvas.drawCircle(center, radius, paint);
    final path = Path()
      ..moveTo(center.dx, center.dy - radius * 0.6)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx + radius * 0.5, center.dy + radius * 0.35);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SealClockPainter oldDelegate) => color != oldDelegate.color;
}

/// The clock-rewind/history glyph inside the Verify Too Old screen's muted
/// seal (a near-full circular arrow with clock hands inside, matching
/// `Cairn Verify Too Old.dc.html`'s `M3.5 10a8.5 8.5 0 1 1 .8 4.5` +
/// `M3.2 5v4.4h4.4` + `M12 8.4v4.1l2.9 1.8`): a hand-approximated reading of
/// that SVG rather than a literal path replication, matching this file's
/// existing icon painters (e.g. [SealClockIcon], [SealExclamationIcon]).
class SealHistoryIcon extends StatelessWidget {
  const SealHistoryIcon({super.key, this.color = AppColors.richCream, this.size = 27});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SealHistoryPainter(color: color)),
    );
  }
}

class _SealHistoryPainter extends CustomPainter {
  const _SealHistoryPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.0875
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;

    // Near-full circle (the "rewind" ring), leaving a small gap at the
    // upper-left for the arrow tip below.
    final center = Offset(12 * w, 10.9 * h);
    final radius = 8.5 * w;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      200 * (3.1415926535 / 180),
      350 * (3.1415926535 / 180),
      false,
      paint,
    );

    // Arrow tip at the gap.
    canvas.drawPath(
      Path()
        ..moveTo(3.2 * w, 5 * h)
        ..lineTo(3.2 * w, 9.4 * h)
        ..lineTo(7.6 * w, 9.4 * h),
      paint,
    );

    // Clock hands inside the ring.
    canvas.drawPath(
      Path()
        ..moveTo(12 * w, 8.4 * h)
        ..lineTo(12 * w, 12.5 * h)
        ..lineTo(14.9 * w, 14.3 * h),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SealHistoryPainter oldDelegate) => color != oldDelegate.color;
}

/// Standard footer padding/background fade shared by every full-width
/// verification-screen footer button block (matches every design file's
/// `padding:14px 24px 30px;background:linear-gradient(0deg,...)` footer).
class VerificationFooter extends StatelessWidget {
  const VerificationFooter({super.key, required this.children, this.backgroundTop = AppColors.screenBackground});

  final List<Widget> children;
  final Color backgroundTop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// The shared outer skeleton every proof-outcome screen builds on top of
/// (Verify Result, Verify Failed / Failed - No Retries, Verify Pending,
/// Verify Too Old, Cairn Complete): a transparent [Scaffold] over a
/// [ScreenBackground] over a [SafeArea] containing [VerificationHeader], a
/// centered scrolling [body], and an optional [VerificationFooter]. Each
/// screen still supplies its own wash/contour tint, header label/colour,
/// body content, and footer buttons - factored out here because this shell
/// (the scaffold/background/safe-area nesting, the shared scroll padding,
/// and the header/footer widgets themselves) was previously hand-rolled
/// identically five times over, not because these screens should look any
/// more alike than they already do.
class ProofOutcomeScaffold extends StatelessWidget {
  const ProofOutcomeScaffold({
    super.key,
    required this.washes,
    required this.contourOrigin,
    required this.contourRingColor,
    required this.onClose,
    this.headerLabel,
    this.headerLabelColor,
    required this.body,
    this.footer,
  });

  /// [ScreenBackground.washes] - each screen tints these differently (e.g.
  /// sage-forward for Result, terracotta-forward for Failed), so this stays
  /// a required per-screen value rather than a hardcoded default.
  final List<RadialGradient> washes;

  /// [ScreenBackground.contourOrigin].
  final Alignment contourOrigin;

  /// [ScreenBackground.contourRingColor].
  final Color contourRingColor;

  /// [VerificationHeader.onClose].
  final VoidCallback onClose;

  /// [VerificationHeader.label]; null keeps that widget's own default.
  final String? headerLabel;

  /// [VerificationHeader.labelColor].
  final Color? headerLabelColor;

  /// The screen's own body content, placed inside the shared
  /// [SingleChildScrollView]'s padding (`EdgeInsetsDirectional.fromSTEB(24,
  /// 14, 24, 0)`, identical across every screen this wraps) - typically a
  /// `Column(crossAxisAlignment: CrossAxisAlignment.center, children: [...])`
  /// supplied by the caller, exactly as each screen built it before this was
  /// factored out.
  final Widget body;

  /// [VerificationFooter.children], or null when a screen has no footer at
  /// all (none of today's five do, but kept optional per this run's spec).
  final List<Widget>? footer;

  @override
  Widget build(BuildContext context) {
    // Builds on [ModalScaffold] - the same three-layer `Scaffold` +
    // `ScreenBackground` + `SafeArea` wrapper every pushed/modal screen in
    // this app shares - adding only this family's own further chrome
    // (`VerificationHeader`/`VerificationFooter`) around [body].
    return ModalScaffold(
      washes: washes,
      contourOrigin: contourOrigin,
      contourRingColor: contourRingColor,
      child: Column(
        children: [
          VerificationHeader(
            onClose: onClose,
            label: headerLabel,
            labelColor: headerLabelColor,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 0),
              child: body,
            ),
          ),
          if (footer != null) VerificationFooter(children: footer!),
        ],
      ),
    );
  }
}

/// Converts a CSS percentage-based radial-gradient/background position like
/// "50% -6%" into the [Alignment] the topographic contour painter expects
/// (-1..1 per axis, 0,0 = center), matching the conversion every screen's
/// contour origin already needs.
Alignment percentPositionToAlignment(double xPercent, double yPercent) {
  return Alignment((xPercent / 100) * 2 - 1, (yPercent / 100) * 2 - 1);
}

/// Uniform size multiplier for the "hero" cairn illustration on the
/// Result/Failed screens (visually larger than the ~60px mini-cairn used on
/// Home/Trail task cards): derived by eye against
/// `Cairn Verify Result.dc.html`'s 5-stone example (top stone ~30px wide vs.
/// [CairnStack]'s own unscaled ~23px top width at n=5), not a value taken
/// verbatim from the CSS (there is no single literal "scale" in the source).
const double heroCairnScale = 1.3;
