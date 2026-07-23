/// Shared chrome for the Phase 4b account-upgrade screens (Create account,
/// Sign in, Enter code, Set a new password, Keep which trail): the
/// close-button row, the eyebrow/title/body header block, the parchment
/// field surface every text field/OTP box builds on, the inline
/// field-error row, the offline banner, and a loading-aware submit button.
/// Factored out here rather than duplicated per screen, the same rationale
/// `verification_chrome.dart` documents for its own screen family.
library;

import 'package:flutter/material.dart'
    show CircularProgressIndicator, Material, MaterialLocalizations, MaterialType;
import 'package:flutter/widgets.dart';

import '../proof/verification_chrome.dart'
    show CloseCircleButton, percentPositionToAlignment;
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_text_styles.dart';
import '../widgets/buttons.dart';
import '../widgets/glyphs.dart' show BackChevronGlyph;
import '../widgets/screen_header.dart';

/// The sage-tinted top wash + contour origin shared by the "form" account
/// screens (Create account, Sign in, Set a new password, Keep which trail):
/// `radial-gradient(135% 46% at 50% -6%, rgba(150,166,120,.22), transparent
/// 62%)` plus a contour ring radiating from `82% 4%`.
final List<RadialGradient> accountFormWashes = [
  RadialGradient(
    center: percentPositionToAlignment(50, -6),
    radius: 1.3,
    colors: const [AppColors.premiumSageWash, AppColors.sageWashEnd],
  ),
];
final Alignment accountFormContourOrigin = percentPositionToAlignment(82, 4);

/// The Enter Code screen's own, lower/larger top wash + contour origin:
/// `radial-gradient(135% 50% at 50% 26%, ...)` plus a contour ring radiating
/// from `50% 26%` - its content is vertically centered rather than
/// top-aligned, so the wash sits lower too.
final List<RadialGradient> accountEnterCodeWashes = [
  RadialGradient(
    center: percentPositionToAlignment(50, 26),
    radius: 1.3,
    colors: const [AppColors.premiumSageWash, AppColors.sageWashEnd],
  ),
];
final Alignment accountEnterCodeContourOrigin =
    percentPositionToAlignment(50, 26);

/// The close (X) button row shared by every account-flow screen, always in
/// the same top-left position. The source file's own literal is `padding:
/// 30px(l/r) 12px(top) 0(bottom)`; the horizontal 30px maps to
/// [kScreenEdgePadding]'s shared 24px inset instead of a one-off literal
/// (per this run's spec), which also keeps every account screen's close
/// button, body content, and footer flush to the same left/right margin -
/// this family's own footer buttons already sit at that same 24px.
class AccountCloseButtonRow extends StatelessWidget {
  const AccountCloseButtonRow({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: kScreenEdgePadding.start,
        end: kScreenEdgePadding.end,
        top: 12,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: CloseCircleButton(onTap: onClose),
      ),
    );
  }
}

/// The circular back button reused by account screens that navigate backward.
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backLabel = MaterialLocalizations.of(context).backButtonTooltip;
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        label: backLabel,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.awaitingChipBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const BackChevronGlyph(color: AppColors.iconMuted, size: 16),
          ),
        ),
      ),
    );
  }
}

/// The back button row shared by account-flow screens that pop back,
/// positioned top-left matching [AccountCloseButtonRow].
class AccountBackButtonRow extends StatelessWidget {
  const AccountBackButtonRow({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: kScreenEdgePadding.start,
        end: kScreenEdgePadding.end,
        top: 12,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: BackCircleButton(onTap: onBack),
      ),
    );
  }
}

/// The eyebrow + title + body header block shared by the "form" account
/// screens (Create account, Sign in, Set a new password, Keep which
/// trail): reuses the same [ScreenHeader] every main tab screen
/// (Home/Trail/Stats/Profile) already builds its own eyebrow+title from,
/// plus a muted body paragraph underneath (a slot [ScreenHeader] itself
/// doesn't have), left-aligned.
class AccountHeaderBlock extends StatelessWidget {
  const AccountHeaderBlock({
    super.key,
    required this.eyebrow,
    required this.title,
    this.body,
  });

  final String eyebrow;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(eyebrow: eyebrow, title: title),
        if (body != null) ...[
          const SizedBox(height: 11),
          Text(body!, style: AppTextStyles.accountHeaderSubtitle),
        ],
      ],
    );
  }
}

/// The parchment gradient surface every account-flow field (email,
/// password, each OTP digit box) is built on: `linear-gradient(165deg,
/// #f4efe4, #e6decb)` ([AppGradients.premiumBg]) with a soft border, an
/// error-tinted border when [hasError], and the same top-highlight bevel
/// [CardSurface]/[ParchmentPill] use elsewhere in this app.
class AccountFieldSurface extends StatelessWidget {
  const AccountFieldSurface({
    super.key,
    required this.child,
    this.radius = 14,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: 16,
      vertical: 15,
    ),
    this.hasError = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.premiumBg,
        borderRadius: borderRadius,
        border: Border.all(
          color: hasError
              ? AppColors.accountFieldErrorBorder
              : AppColors.panelBorder,
          width: hasError ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
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
              padding: padding,
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// An inline field-level error line: a small warning-circle glyph plus
/// [message], optionally followed by a tappable [action] link (the Create
/// account screen's "Sign in instead?" affordance).
class AccountFieldErrorRow extends StatelessWidget {
  const AccountFieldErrorRow({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.only(top: 1),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CustomPaint(painter: _WarningGlyphPainter()),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Wrap(
                children: [
                  Text(
                    action == null ? message : '$message ',
                    style: AppTextStyles.accountInlineError,
                  ),
                  if (action != null) action!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The visual style variants supported by [AccountInlineLink].
enum AccountInlineLinkStyle {
  /// Sage green, no underline, weight 600, 14px default - standard navigation links.
  navigation,

  /// Terracotta, underlined, weight 600, 12.5px default - inline field-error links.
  error,
}

/// A tappable text link supporting two visual variants:
/// [AccountInlineLinkStyle.navigation] (sage green, no underline, 14px w600 default)
/// and [AccountInlineLinkStyle.error] (terracotta, underlined, 12.5px w600 default).
class AccountInlineLink extends StatelessWidget {
  const AccountInlineLink({
    super.key,
    required this.label,
    required this.onTap,
    this.style = AccountInlineLinkStyle.navigation,
    this.fontWeight,
    this.fontSize,
  });

  final String label;
  final VoidCallback onTap;
  final AccountInlineLinkStyle style;
  final FontWeight? fontWeight;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle;
    switch (style) {
      case AccountInlineLinkStyle.navigation:
        baseStyle = const TextStyle(
          fontFamily: AppFontFamilies.workSans,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.sage,
          decoration: TextDecoration.none,
        );
      case AccountInlineLinkStyle.error:
        baseStyle = AppTextStyles.accountInlineError.copyWith(
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: label,
        child: Text(
          label,
          style: baseStyle.copyWith(
            fontWeight: fontWeight,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}


class _WarningGlyphPainter extends CustomPainter {
  const _WarningGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accountFieldErrorIcon
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.shortestSide / 2 - 1,
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.3),
      Offset(size.width * 0.5, size.height * 0.58),
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.72),
      0.9,
      Paint()..color = AppColors.accountFieldErrorIcon,
    );
  }

  @override
  bool shouldRepaint(_WarningGlyphPainter oldDelegate) => false;
}

/// The "You're offline" reassurance banner shown on every account-flow
/// screen when the last action failed with [AccountError.offline].
class AccountOfflineBanner extends StatelessWidget {
  const AccountOfflineBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.only(bottom: 16),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.accountOfflineBannerBg,
        border: Border.all(color: AppColors.accountOfflineBannerBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(top: 1),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CustomPaint(painter: _OfflineGlyphPainter()),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: AppFontFamilies.workSans,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.accountWarningText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineGlyphPainter extends CustomPainter {
  const _OfflineGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.terracotta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final w = size.width / 24;
    final h = size.height / 24;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(12 * w, 12.5 * h), radius: 7 * w),
      3.4,
      2.7,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(12 * w, 12.5 * h), radius: 3.5 * w),
      3.6,
      2.3,
      false,
      paint,
    );
    canvas.drawCircle(Offset(12 * w, 19.5 * h), 0.9, Paint()..color = AppColors.terracotta);
    canvas.drawLine(Offset(3 * w, 3 * h), Offset(21 * w, 21 * h), paint);
  }

  @override
  bool shouldRepaint(_OfflineGlyphPainter oldDelegate) => false;
}

/// A [PrimaryButton] (sage, large, full-width) that swaps its label for
/// [loadingLabel] with a small spinner and disables itself while
/// [isLoading] is true - the loading-state variant shown in
/// `Cairn Account.dc.html`'s own variants column, shared by every
/// account-flow screen's primary CTA rather than each hand-rolling its own
/// spinner treatment.
class AccountSubmitButton extends StatelessWidget {
  const AccountSubmitButton({
    super.key,
    required this.label,
    required this.loadingLabel,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final String loadingLabel;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      return PrimaryButton(
        label: label,
        onPressed: onPressed,
        color: PrimaryButtonColor.sage,
      );
    }
    return PrimaryButton(
      label: loadingLabel,
      onPressed: null,
      color: PrimaryButtonColor.sage,
      icon: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation(AppColors.buttonText),
        ),
      ),
    );
  }
}
