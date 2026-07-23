import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../services/account_error.dart';
import '../../services/account_policy.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/screen_header.dart';
import 'account_chrome.dart';
import 'password_field.dart';

/// Frame 4 of `Cairn Account.dc.html`: a single new-password field and the
/// "Save password" sage CTA. Reached only from the password-reset flow
/// (after `Enter Code` verifies the reset OTP).
class SetNewPasswordScreen extends ConsumerStatefulWidget {
  const SetNewPasswordScreen({
    super.key,
    required this.onClose,
    required this.email,
    required this.onSaved,
  });

  final VoidCallback onClose;
  final String email;

  /// Called once `AccountService.setNewPassword` succeeds; the caller
  /// closes the whole flow (the user is now signed in with the new
  /// password).
  final VoidCallback onSaved;

  @override
  ConsumerState<SetNewPasswordScreen> createState() =>
      _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends ConsumerState<SetNewPasswordScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _passwordError;
  String? _offlineMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final password = _passwordController.text;

    setState(() {
      _passwordError = null;
      _offlineMessage = null;
    });

    if (password.length < kMinPasswordLength) {
      setState(() {
        _passwordError = l10n.accountPasswordTooShortError(kMinPasswordLength);
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(accountServiceProvider).setNewPassword(password);
      if (!mounted) return;
      widget.onSaved();
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.error) {
          case AccountError.weakPassword:
            _passwordError =
                l10n.accountPasswordTooShortError(kMinPasswordLength);
          case AccountError.offline:
            _offlineMessage = l10n.accountOfflineBannerGeneric;
          case AccountError.rateLimited:
            _offlineMessage = l10n.accountRateLimitedError;
          case AccountError.emailInUse:
          case AccountError.invalidCode:
          case AccountError.invalidCredentials:
          case AccountError.unknown:
            _offlineMessage = l10n.accountUnknownError;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          AccountCloseButtonRow(onClose: widget.onClose),
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
                    title: l10n.accountSetNewPasswordTitle,
                    body: l10n.accountSetNewPasswordBody(widget.email),
                  ),
                  const SizedBox(height: 26),
                  if (_offlineMessage != null)
                    AccountOfflineBanner(message: _offlineMessage!),
                  PasswordField(
                    label: l10n.accountNewPasswordLabel,
                    controller: _passwordController,
                    hintText:
                        l10n.accountPasswordHintCreate(kMinPasswordLength),
                    enabled: !_isLoading,
                    error: _passwordError == null
                        ? null
                        : AccountFieldErrorRow(message: _passwordError!),
                  ),
                  const SizedBox(height: 26),
                  AccountSubmitButton(
                    label: l10n.accountSavePasswordButton,
                    loadingLabel: l10n.accountSavingPasswordLoading,
                    isLoading: _isLoading,
                    onPressed: _submit,
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
