import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// Which confirm gradient and icon tint [CairnDialog] paints.
///
/// [sage] is the default tone for ordinary or affirmative confirmations;
/// [clay] is the terracotta tone for destructive actions or evident alerts
/// (e.g. Profile Sign out).
enum CairnDialogTone { sage, clay }

/// Reusable Cairn-styled confirmation dialog card matching `Cairn Dialog.dc.html`.
///
/// Displays a parchment card with an optional icon circle, a Zilla Slab title,
/// a muted Work Sans body, and a row of two compact buttons (bordered Cancel
/// and filled-gradient confirm).
class CairnDialog extends StatelessWidget {
  const CairnDialog({
    super.key,
    this.icon,
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
    this.tone = CairnDialogTone.sage,
    this.onCancel,
    this.onConfirm,
  });

  final Widget? icon;
  final String title;
  final String body;
  final String cancelLabel;
  final String confirmLabel;
  final CairnDialogTone tone;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final (iconBg, iconBorder) = tone == CairnDialogTone.sage
        ? (AppColors.dialogSageIconBg, AppColors.dialogSageIconBorder)
        : (AppColors.dialogClayIconBg, AppColors.dialogClayIconBorder);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 310),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.premiumBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.panelBorder),
              boxShadow: AppShadows.dialogCard,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
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
                    padding: const EdgeInsetsDirectional.fromSTEB(22, 26, 22, 20),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: iconBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: iconBorder),
                              ),
                              alignment: Alignment.center,
                              child: icon,
                            ),
                            const SizedBox(height: 14),
                          ],
                          Text(
                            title,
                            style: AppTextStyles.dialogTitle,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            body,
                            style: AppTextStyles.accountHeaderSubtitle,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: _DialogButton(
                                  label: cancelLabel,
                                  onPressed: onCancel,
                                  isSecondary: true,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DialogButton(
                                  label: confirmLabel,
                                  onPressed: onConfirm,
                                  tone: tone,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onPressed,
    this.isSecondary = false,
    this.tone = CairnDialogTone.sage,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final CairnDialogTone tone;

  @override
  Widget build(BuildContext context) {
    final BoxDecoration decoration;
    final TextStyle textStyle;

    if (isSecondary) {
      decoration = BoxDecoration(
        color: AppColors.dialogCancelBg,
        border: Border.all(color: AppColors.dialogCancelBorder),
        borderRadius: BorderRadius.circular(14),
      );
      textStyle = AppTextStyles.buttonLabelMedium.copyWith(
        color: AppColors.textMuted,
      );
    } else {
      final gradient = tone == CairnDialogTone.sage
          ? AppGradients.sageButton
          : AppGradients.terracottaButton;
      final shadows = tone == CairnDialogTone.sage
          ? AppShadows.sageButtonSmall
          : AppShadows.buttonSmall;
      decoration = BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: shadows,
        border: Border.all(
          color: AppColors.buttonInsetHighlight,
          width: 0.5,
        ),
      );
      textStyle = AppTextStyles.buttonLabelMedium;
    }

    final enabled = onPressed != null;
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: onPressed,
            behavior: HitTestBehavior.opaque,
            child: Opacity(
              opacity: enabled ? 1.0 : 0.5,
              child: Container(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: decoration,
                child: Text(
                  label,
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays a Cairn-styled confirmation dialog over the current screen.
///
/// Returns [Future<bool>] resolving to `true` if the user tapped the confirm
/// button, or `false` if they cancelled, tapped the backdrop scrim, or
/// dismissed via the system back button.
Future<bool> showCairnDialog({
  required BuildContext context,
  Widget? icon,
  required String title,
  required String body,
  String? cancelLabel,
  required String confirmLabel,
  CairnDialogTone tone = CairnDialogTone.sage,
}) async {
  final l10n = AppLocalizations.of(context);
  final effectiveCancelLabel = cancelLabel ?? l10n?.cancelButton ?? 'Cancel';

  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: effectiveCancelLabel,
    barrierColor: AppColors.dialogScrim,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return CairnDialog(
        icon: icon,
        title: title,
        body: body,
        cancelLabel: effectiveCancelLabel,
        confirmLabel: confirmLabel,
        tone: tone,
        onCancel: () => Navigator.of(context).pop(false),
        onConfirm: () => Navigator.of(context).pop(true),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );

  return result ?? false;
}
