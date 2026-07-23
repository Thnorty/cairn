import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../services/account_error.dart';
import '../../services/account_policy.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/screen_header.dart';
import 'account_chrome.dart';
import 'email_field.dart';
import 'password_field.dart';

/// Frame 1 of `Cairn Account.dc.html`: email + password, a free-trail
/// reassurance chip, and the "Create account" sage CTA. Step 1 of the
/// create-account flow (see `AccountFlow`'s doc comment for the whole
/// nested-Navigator flow this is hosted in).
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({
    super.key,
    required this.onClose,
    required this.onCreated,
    required this.onSignInInstead,
    this.initialEmail,
  });

  final VoidCallback onClose;

  /// Called after `AccountService.startCreateAccount` succeeds, with the
  /// email and password just submitted (the caller pushes Enter Code,
  /// purpose = verify, threading the password through for that screen's
  /// own resend action).
  final void Function(String email, String password) onCreated;

  /// Called when the user taps "Sign in instead?" on the email-in-use
  /// inline error; the caller navigates to Sign in with [email] pre-filled.
  final void Function(String email) onSignInInstead;

  /// Pre-fills the email field (unused on this screen today, but mirrors
  /// [SignInScreen]'s own `initialEmail` for symmetry/consistency).
  final String? initialEmail;

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  late final _emailController =
      TextEditingController(text: widget.initialEmail ?? '');
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _emailError;
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
      _emailError = null;
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
      await ref
          .read(accountServiceProvider)
          .startCreateAccount(email: email, password: password);
      if (!mounted) return;
      widget.onCreated(email, password);
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.error) {
          case AccountError.emailInUse:
            _emailError = l10n.accountEmailInUseError;
          case AccountError.weakPassword:
            _passwordError =
                l10n.accountPasswordTooShortError(kMinPasswordLength);
          case AccountError.offline:
            _offlineMessage = l10n.accountOfflineBannerCreate;
          case AccountError.rateLimited:
            _offlineMessage = l10n.accountRateLimitedError;
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
                    eyebrow: l10n.accountEyebrowLabel,
                    title: l10n.accountCreateTitle,
                    body: l10n.accountCreateBody,
                  ),
                  const SizedBox(height: 16),
                  _FreeTrailChip(label: l10n.accountFreeTrailChip),
                  const SizedBox(height: 24),
                  if (_offlineMessage != null)
                    AccountOfflineBanner(message: _offlineMessage!),
                  EmailField(
                    label: l10n.accountEmailLabel,
                    controller: _emailController,
                    hintText: l10n.accountEmailHint,
                    enabled: !_isLoading,
                    error: _emailError == null
                        ? null
                        : AccountFieldErrorRow(
                            message: _emailError!,
                            action: AccountInlineLink(
                              label: l10n.accountSignInInsteadLink,
                              onTap: () => widget
                                  .onSignInInstead(_emailController.text.trim()),
                            ),
                          ),
                  ),
                  const SizedBox(height: 15),
                  PasswordField(
                    label: l10n.accountPasswordLabel,
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
                    label: l10n.accountCreateButton,
                    loadingLabel: l10n.accountCreatingAccountLoading,
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        Text(
                          '${l10n.accountAlreadyHaveAccountLead} ',
                          style: AppTextStyles.body.copyWith(fontSize: 14),
                        ),
                        AccountInlineLink(
                          label: l10n.accountSignInLink,
                          onTap: () => widget.onSignInInstead(
                            _emailController.text.trim(),
                          ),
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

class _FreeTrailChip extends StatelessWidget {
  const _FreeTrailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.onboardingSageCardBg,
          border: Border.all(color: AppColors.onboardingSageCardBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _ShieldCheckGlyph(),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.accountFreeChipLabel),
          ],
        ),
      ),
    );
  }
}

/// The small shield-with-checkmark glyph on the free-trail chip, matching
/// `Cairn Account.dc.html`'s shield path (`M12 2.5l7 2.8v5.5c0 4.2-3
/// 7.2-7 8.7-4-1.5-7-4.5-7-8.7V5.3z`) plus its checkmark
/// (`M9 12l2 2 4-4.2`).
class _ShieldCheckGlyph extends StatelessWidget {
  const _ShieldCheckGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 15,
      height: 15,
      child: CustomPaint(painter: _ShieldCheckGlyphPainter()),
    );
  }
}

class _ShieldCheckGlyphPainter extends CustomPainter {
  const _ShieldCheckGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accountSageButtonDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    final shield = Path()
      ..moveTo(12 * w, 2.5 * h)
      ..lineTo(19 * w, 5.3 * h)
      ..lineTo(19 * w, 10.8 * h)
      ..cubicTo(19 * w, 15 * h, 16 * w, 18 * h, 12 * w, 19.5 * h)
      ..cubicTo(8 * w, 18 * h, 5 * w, 15 * h, 5 * w, 10.8 * h)
      ..lineTo(5 * w, 5.3 * h)
      ..close();
    canvas.drawPath(shield, paint);
    final check = Path()
      ..moveTo(9 * w, 12 * h)
      ..lineTo(11 * w, 14 * h)
      ..lineTo(15 * w, 9.8 * h);
    canvas.drawPath(check, paint);
  }

  @override
  bool shouldRepaint(_ShieldCheckGlyphPainter oldDelegate) => false;
}
