import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../services/account_error.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/screen_header.dart';
import 'account_chrome.dart';
import 'otp_code_input.dart';

/// Which flow the Enter Code screen (Frame 3 of `Cairn Account.dc.html`) is
/// currently serving: verifying a brand-new account's email (create-account
/// flow) or confirming a password-reset request. One screen, varied
/// subcopy/next-step per the canonical design's own note ("This ONE screen
/// serves BOTH email-verification (create flow) and password-reset
/// (recovery flow); vary its subcopy/next-step by a purpose parameter").
enum AccountCodePurpose { verifyEmail, passwordReset }

const int _resendCooldownSeconds = 30;

/// Frame 3: 6-digit OTP entry, a cooldown-guarded resend action, and a
/// "Verify" CTA.
class EnterCodeScreen extends ConsumerStatefulWidget {
  const EnterCodeScreen({
    super.key,
    required this.onClose,
    required this.purpose,
    required this.email,
    this.password,
    required this.onVerified,
  }) : assert(
          purpose != AccountCodePurpose.verifyEmail || password != null,
          'password is required for the verify-email purpose (needed to '
          're-hold it on resend)',
        );

  final VoidCallback onClose;
  final AccountCodePurpose purpose;
  final String email;

  /// Held only so a resend can re-call `AccountService.startCreateAccount`
  /// (which both re-sends the OTP and re-holds the password server-side).
  /// Required when [purpose] is [AccountCodePurpose.verifyEmail]; unused for
  /// [AccountCodePurpose.passwordReset].
  final String? password;

  /// Called once the code is verified: for [AccountCodePurpose.verifyEmail]
  /// this closes the whole flow (the account is now created and signed
  /// in); for [AccountCodePurpose.passwordReset] this pushes Set a new
  /// password.
  final VoidCallback onVerified;

  @override
  ConsumerState<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends ConsumerState<EnterCodeScreen> {
  String _code = '';
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;
  int _cooldownRemaining = _resendCooldownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownRemaining = _resendCooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownRemaining <= 1) {
        timer.cancel();
        setState(() => _cooldownRemaining = 0);
        return;
      }
      setState(() => _cooldownRemaining -= 1);
    });
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _error = null;
      _isLoading = true;
    });

    final accountService = ref.read(accountServiceProvider);
    try {
      switch (widget.purpose) {
        case AccountCodePurpose.verifyEmail:
          await accountService.confirmCreateAccount(_code);
        case AccountCodePurpose.passwordReset:
          await accountService.verifyPasswordResetCode(
            email: widget.email,
            code: _code,
          );
      }
      if (!mounted) return;
      widget.onVerified();
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.error) {
          case AccountError.invalidCode:
            _error = l10n.accountInvalidCodeError;
          case AccountError.offline:
            _error = l10n.accountOfflineBannerGeneric;
          case AccountError.rateLimited:
            _error = l10n.accountRateLimitedError;
          case AccountError.emailInUse:
          case AccountError.weakPassword:
          case AccountError.invalidCredentials:
          case AccountError.unknown:
            _error = l10n.accountUnknownError;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldownRemaining > 0 || _isResending) return;
    setState(() => _isResending = true);
    final accountService = ref.read(accountServiceProvider);
    try {
      switch (widget.purpose) {
        case AccountCodePurpose.verifyEmail:
          await accountService.startCreateAccount(
            email: widget.email,
            password: widget.password!,
          );
        case AccountCodePurpose.passwordReset:
          await accountService.sendPasswordResetCode(widget.email);
      }
      if (!mounted) return;
      _startCooldown();
    } on AccountException catch (_) {
      // Best-effort resend: the user can simply try again once the cooldown
      // elapses, so no dedicated failure UI is invented here.
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String _formatCooldown(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final body = widget.purpose == AccountCodePurpose.verifyEmail
        ? l10n.accountEnterCodeBodyVerify(widget.email)
        : l10n.accountEnterCodeBodyReset(widget.email);
    final canVerify = _code.length == 6 && !_isLoading;

    return ModalScaffold(
      washes: accountEnterCodeWashes,
      contourOrigin: accountEnterCodeContourOrigin,
      child: Column(
        children: [
          AccountCloseButtonRow(onClose: widget.onClose),
          Expanded(
            // LayoutBuilder + a minHeight-constrained inner Column
            // vertically centers this screen's content (matching the
            // design's mid-screen centered icon/title/OTP block) when it's
            // shorter than the viewport, while still scrolling normally on
            // a shorter/narrower real device where it doesn't fit -
            // SingleChildScrollView alone gives its child unbounded height,
            // so a bare `mainAxisAlignment: center` has no effect (the
            // same fix `OnboardingWelcomeScreen` uses for its own centered
            // content).
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsetsDirectional.only(
                  start: kScreenEdgePadding.start,
                  end: kScreenEdgePadding.end,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _EnvelopeSeal(),
                      const SizedBox(height: 26),
                      Text(l10n.accountEnterCodeEyebrow, style: AppTextStyles.sectionLabel),
                      const SizedBox(height: 5),
                      Text(
                        l10n.accountEnterCodeTitle,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.resultTitle,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.accountHeaderSubtitle,
                      ),
                      const SizedBox(height: 26),
                      OtpCodeInput(onChanged: (code) => setState(() => _code = code)),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(top: 16),
                          child: AccountFieldErrorRow(message: _error!),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              kScreenEdgePadding.start,
              0,
              kScreenEdgePadding.end,
              30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AccountSubmitButton(
                  label: l10n.accountVerifyButton,
                  loadingLabel: l10n.accountVerifyingLoading,
                  isLoading: _isLoading,
                  onPressed: canVerify ? _verify : null,
                ),
                const SizedBox(height: 10),
                _ResendControl(
                  cooldownRemaining: _cooldownRemaining,
                  isResending: _isResending,
                  onResend: _resend,
                  formatCooldown: _formatCooldown,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.accountEnterCodeSpamHint,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.labelGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResendControl extends StatelessWidget {
  const _ResendControl({
    required this.cooldownRemaining,
    required this.isResending,
    required this.onResend,
    required this.formatCooldown,
  });

  final int cooldownRemaining;
  final bool isResending;
  final VoidCallback onResend;
  final String Function(int seconds) formatCooldown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (cooldownRemaining > 0) {
      return Text(
        l10n.accountResendCodeCountdown(formatCooldown(cooldownRemaining)),
        style: AppTextStyles.textGhostButtonLabel.copyWith(
          color: AppColors.labelGrey,
        ),
      );
    }
    return GestureDetector(
      onTap: isResending ? null : onResend,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: l10n.accountResendCodeButton,
        child: Text(
          l10n.accountResendCodeButton,
          style: AppTextStyles.textGhostButtonLabel.copyWith(
            color: AppColors.sageText,
          ),
        ),
      ),
    );
  }
}

/// The layered envelope seal icon at the top of the Enter Code screen,
/// matching `Cairn Account.dc.html`'s two-circle badge with an envelope
/// glyph inside.
class _EnvelopeSeal extends StatelessWidget {
  const _EnvelopeSeal();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: const Alignment(-0.64, -1),
          end: const Alignment(0.64, 1),
          colors: const [AppColors.sageLight, AppColors.sage],
        ),
        boxShadow: AppShadows.sageButtonLarge,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppGradients.sageButton),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CustomPaint(painter: _EnvelopeGlyphPainter()),
        ),
      ),
    );
  }
}

class _EnvelopeGlyphPainter extends CustomPainter {
  const _EnvelopeGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.richCream
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3 * w, 5.5 * h, 18 * w, 13 * h),
        Radius.circular(2.5 * w),
      ),
      paint,
    );
    final flap = Path()
      ..moveTo(3.5 * w, 7 * h)
      ..lineTo(12 * w, 13 * h)
      ..lineTo(20.5 * w, 7 * h);
    canvas.drawPath(flap, paint);
  }

  @override
  bool shouldRepaint(_EnvelopeGlyphPainter oldDelegate) => false;
}
