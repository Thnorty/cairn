import 'package:flutter/material.dart'
    show CircularProgressIndicator, Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../services/account_error.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/cairn_dialog.dart';
import '../widgets/glyphs.dart';
import '../widgets/message_snack_bar.dart';
import '../widgets/screen_header.dart';
import 'account_chrome.dart';
import 'password_field.dart';

/// Screen for in-app account deletion (`Cairn Account - Delete.dc.html`).
///
/// Reached from Profile > SETTINGS > Delete account, a row that only exists
/// while signed in with a real email account.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({
    super.key,
    required this.email,
    required this.onClose,
  });

  final String email;
  final VoidCallback onClose;

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _passwordError;
  String? _offlineMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final password = _passwordController.text;
    if (password.isEmpty) return;

    // Password-then-dialog: the dialog is the final gate.
    final confirmed = await showCairnDialog(
      context: context,
      tone: CairnDialogTone.destructive,
      icon: const TrashGlyph(color: AppColors.deleteIconStroke, size: 22),
      title: l10n.accountDeleteDialogTitle,
      body: l10n.accountDeleteDialogBody,
      cancelLabel: l10n.cancelButton,
      confirmLabel: l10n.accountDeleteDialogConfirm,
    );

    if (!confirmed) return;

    setState(() {
      _passwordError = null;
      _offlineMessage = null;
      _isLoading = true;
    });

    try {
      await ref.read(accountServiceProvider).deleteAccount(password);
      if (!mounted) return;
      ref.invalidate(accountStateProvider);
      widget.onClose();
      context.showMessageSnackBar(
        l10n.accountDeleteSuccessSnackbar,
        tone: MessageTone.success,
      );
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.error) {
          case AccountError.invalidCredentials:
            _passwordError = l10n.accountInvalidCredentialsError;
          case AccountError.offline:
            _offlineMessage = l10n.accountOfflineBannerGeneric;
          case AccountError.rateLimited:
            _offlineMessage = l10n.accountRateLimitedError;
          case AccountError.emailInUse:
          case AccountError.weakPassword:
          case AccountError.invalidCode:
          case AccountError.samePassword:
          case AccountError.unknown:
            _offlineMessage = l10n.accountUnknownError;
        }
      });
    } catch (_) {
      if (!mounted) return;
      context.showMessageSnackBar(
        l10n.accountDeleteFailedSnackbar,
        tone: MessageTone.neutral,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final busy = _isLoading;
    final passwordText = _passwordController.text;
    final canSubmit = passwordText.isNotEmpty && !busy;

    return ModalScaffold(
      washes: accountFormWashes,
      contourOrigin: accountFormContourOrigin,
      child: Column(
        children: [
          AccountCloseButtonRow(onClose: widget.onClose),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(
                kScreenEdgePadding.start,
                14,
                kScreenEdgePadding.end,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AccountHeaderBlock(
                    eyebrow: l10n.accountEyebrowLabel,
                    title: l10n.accountDeleteTitle,
                  ),
                  const SizedBox(height: 11),
                  Text(
                    l10n.accountDeleteSignedInAs(widget.email),
                    style: AppTextStyles.accountSignedInEmail,
                  ),
                  const SizedBox(height: 20),
                  if (_offlineMessage != null)
                    AccountOfflineBanner(message: _offlineMessage!),
                  const _WhatIsDestroyedBanner(),
                  const SizedBox(height: 11),
                  const _WhatSurvivesBanner(),
                  const SizedBox(height: 22),
                  PasswordField(
                    label: l10n.accountDeleteConfirmPasswordLabel,
                    controller: _passwordController,
                    hintText: l10n.accountDeletePasswordHint,
                    enabled: !busy,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: canSubmit ? (_) => _handleDelete() : null,
                    error: _passwordError == null
                        ? null
                        : AccountFieldErrorRow(message: _passwordError!),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              kScreenEdgePadding.start,
              12,
              kScreenEdgePadding.end,
              30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryButton(
                  label: busy
                      ? l10n.accountDeletingLoading
                      : l10n.accountDeleteButton,
                  onPressed: canSubmit ? _handleDelete : null,
                  color: PrimaryButtonColor.delete,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.buttonText,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 11),
                Text(
                  l10n.accountDeleteFooterNotice,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.labelGrey,
                    fontSize: 11.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The clay "This cannot be undone" banner on Delete account screen.
class _WhatIsDestroyedBanner extends StatelessWidget {
  const _WhatIsDestroyedBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppColors.deleteWarningBannerBg,
        border: Border.all(color: AppColors.deleteWarningBannerBorder),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.deleteWarningIconBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const TrashGlyph(
              color: AppColors.deleteIconStroke,
              size: 17,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.accountDeleteCannotBeUndoneTitle,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: AppColors.deleteWarningTitle,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    l10n.accountDeleteCannotBeUndoneBody,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.deleteWarningBody,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sage "Your trail stays on this phone" banner on Delete account screen.
class _WhatSurvivesBanner extends StatelessWidget {
  const _WhatSurvivesBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppColors.onboardingSageCardBg,
        border: Border.all(color: AppColors.onboardingSageCardBorder),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.achievedTierIconBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 17,
              height: 17,
              child: CustomPaint(
                painter: _CheckmarkPainter(color: AppColors.sageText),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.accountDeleteTrailStaysTitle,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: AppColors.sageReasonBody,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    l10n.accountDeleteTrailStaysBody,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.sageReasonBody,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;

    final path = Path()
      ..moveTo(5 * w, 12.5 * h)
      ..lineTo(9.5 * w, 17 * h)
      ..lineTo(19 * w, 7.5 * h);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) =>
      color != oldDelegate.color;
}
