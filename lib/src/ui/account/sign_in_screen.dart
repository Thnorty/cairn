import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../models/trail_summary.dart';
import '../../providers.dart';
import '../../services/account_error.dart';
import '../../services/account_service.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/screen_header.dart';
import 'account_chrome.dart';
import 'email_field.dart';
import 'password_field.dart';

/// Frame 2 of `Cairn Account.dc.html`: email + password, "Forgot
/// password?", and the "Sign in" sage CTA.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({
    super.key,
    required this.onClose,
    required this.onSignInComplete,
    required this.onNeedsTrailChoice,
    required this.onForgotPassword,
    required this.onCreateAccount,
    this.initialEmail,
  });

  final VoidCallback onClose;

  /// The account had nothing to lose: [AccountService.signIn] already
  /// replaced local data with the account's cloud data.
  final VoidCallback onSignInComplete;

  /// Both sides have data; the caller pushes the Keep which trail chooser.
  final void Function(TrailSummary local, TrailSummary remote)
      onNeedsTrailChoice;

  /// "Forgot password?" tapped: the caller sends the reset code for
  /// [email] and pushes Enter Code (purpose = reset).
  final void Function(String email) onForgotPassword;

  /// "New here? Create an account" tapped.
  final VoidCallback onCreateAccount;

  /// Pre-fills the email field (the "Sign in instead?" link from the
  /// Create account screen's email-in-use error uses this).
  final String? initialEmail;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final _emailController =
      TextEditingController(text: widget.initialEmail ?? '');
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isSendingReset = false;
  String? _passwordError;
  String? _offlineMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _passwordError = null;
      _offlineMessage = null;
      _isLoading = true;
    });

    try {
      final outcome = await ref
          .read(accountServiceProvider)
          .signIn(email: email, password: password);
      if (!mounted) return;
      switch (outcome) {
        case SignInComplete():
          widget.onSignInComplete();
        case SignInNeedsTrailChoice(:final local, :final remote):
          widget.onNeedsTrailChoice(local, remote);
      }
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
          case AccountError.unknown:
            _offlineMessage = l10n.accountUnknownError;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty || _isSendingReset) return;

    setState(() {
      _offlineMessage = null;
      _isSendingReset = true;
    });
    try {
      await ref.read(accountServiceProvider).sendPasswordResetCode(email);
      if (!mounted) return;
      widget.onForgotPassword(email);
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() {
        _offlineMessage = e.error == AccountError.offline
            ? l10n.accountOfflineBannerGeneric
            : l10n.accountUnknownError;
      });
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final busy = _isLoading || _isSendingReset;

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
                    eyebrow: l10n.accountEyebrowLabel,
                    title: l10n.accountSignInTitle,
                    body: l10n.accountSignInBody,
                  ),
                  const SizedBox(height: 30),
                  if (_offlineMessage != null)
                    AccountOfflineBanner(message: _offlineMessage!),
                  EmailField(
                    label: l10n.accountEmailLabel,
                    controller: _emailController,
                    hintText: l10n.accountEmailHint,
                    enabled: !busy,
                  ),
                  const SizedBox(height: 15),
                  PasswordField(
                    label: l10n.accountPasswordLabel,
                    controller: _passwordController,
                    hintText: l10n.accountPasswordHintSignIn,
                    enabled: !busy,
                    error: _passwordError == null
                        ? null
                        : AccountFieldErrorRow(message: _passwordError!),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 11),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: AccountInlineLink(
                        label: l10n.accountForgotPasswordLink,
                        onTap: busy ? () {} : _forgotPassword,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  AccountSubmitButton(
                    label: l10n.accountSignInLink,
                    loadingLabel: l10n.accountSigningInLoading,
                    isLoading: _isLoading,
                    onPressed: busy ? null : _submit,
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        Text(
                          '${l10n.accountNewHereLead} ',
                          style: AppTextStyles.body.copyWith(fontSize: 14),
                        ),
                        AccountInlineLink(
                          label: l10n.accountCreateAccountLink,
                          onTap: widget.onCreateAccount,
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
