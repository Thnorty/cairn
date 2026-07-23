import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../services/account_error.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/screen_header.dart';
import 'account_chrome.dart';
import 'email_field.dart';

/// Frame 1 of `Cairn Account - Forgot Password & Rules.dc.html`: email entry
/// for password reset, "Send code" sage CTA, and "Remembered it? Sign in".
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.onClose,
    required this.onBack,
    required this.onCodeSent,
    this.initialEmail,
  });

  final VoidCallback onClose;
  final VoidCallback onBack;
  final void Function(String email) onCodeSent;
  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final _emailController =
      TextEditingController(text: widget.initialEmail ?? '');

  bool _isSendingCode = false;
  String? _emailError;
  String? _offlineMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSendingCode) return;

    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final atIndex = email.indexOf('@');
    final isWellFormed = email.isNotEmpty &&
        atIndex > 0 &&
        atIndex == email.lastIndexOf('@') &&
        atIndex < email.length - 1;

    if (!isWellFormed) {
      setState(() {
        _emailError = l10n.accountInvalidEmailError;
      });
      return;
    }

    setState(() {
      _emailError = null;
      _offlineMessage = null;
      _isSendingCode = true;
    });

    try {
      await ref.read(accountServiceProvider).sendPasswordResetCode(email);
      if (!mounted) return;
      widget.onCodeSent(email);
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.error) {
          case AccountError.offline:
            _offlineMessage = l10n.accountOfflineBannerGeneric;
          case AccountError.rateLimited:
            _offlineMessage = l10n.accountRateLimitedError;
          case AccountError.invalidCredentials:
          case AccountError.emailInUse:
          case AccountError.weakPassword:
          case AccountError.invalidCode:
          case AccountError.samePassword:
          case AccountError.unknown:
            _offlineMessage = l10n.accountUnknownError;
        }
      });
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ModalScaffold(
      washes: accountFormWashes,
      contourOrigin: accountFormContourOrigin,
      child: Column(
        children: [
          AccountBackButtonRow(onBack: widget.onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(
                kScreenEdgePadding.start,
                22,
                kScreenEdgePadding.end,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AccountHeaderBlock(
                    eyebrow: l10n.accountSetNewPasswordEyebrow,
                    title: l10n.accountForgotPasswordTitle,
                    body: l10n.accountForgotPasswordBody,
                  ),
                  const SizedBox(height: 30),
                  if (_offlineMessage != null)
                    AccountOfflineBanner(message: _offlineMessage!),
                  EmailField(
                    label: l10n.accountEmailLabel,
                    controller: _emailController,
                    hintText: l10n.accountEmailHint,
                    enabled: !_isSendingCode,
                    error: _emailError == null
                        ? null
                        : AccountFieldErrorRow(message: _emailError!),
                    onChanged: _emailError == null
                        ? null
                        : (_) {
                            if (_emailError != null) {
                              setState(() => _emailError = null);
                            }
                          },
                  ),
                  const SizedBox(height: 24),
                  AccountSubmitButton(
                    label: l10n.accountSendCodeButton,
                    loadingLabel: l10n.accountSendingCodeLoading,
                    isLoading: _isSendingCode,
                    onPressed: _isSendingCode ? null : _submit,
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        Text(
                          '${l10n.accountRememberedItLead} ',
                          style: AppTextStyles.body.copyWith(fontSize: 14),
                        ),
                        AccountInlineLink(
                          label: l10n.accountSignInLink,
                          onTap: widget.onBack,
                        ),
                      ],
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
