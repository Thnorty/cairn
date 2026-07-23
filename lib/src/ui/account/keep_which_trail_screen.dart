import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../../models/trail_summary.dart';
import '../../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/screen_header.dart';
import 'account_chrome.dart';

enum _TrailSide { device, account }

/// Frame 5 of `Cairn Account.dc.html`: the replace-not-merge chooser shown
/// on sign-in when both this device and the signed-in account have their
/// own trail (see `AccountService.signIn`'s doc comment). Selecting a side
/// updates the clay consequence line and the CTA label to match; tapping
/// the CTA calls [AccountService.keepThisDevice] or
/// [AccountService.useAccount] and then [onDone].
class KeepWhichTrailScreen extends ConsumerStatefulWidget {
  const KeepWhichTrailScreen({
    super.key,
    required this.onClose,
    required this.local,
    required this.remote,
    required this.onDone,
  });

  final VoidCallback onClose;
  final TrailSummary local;
  final TrailSummary remote;

  /// Called once the replace operation completes (regardless of which side
  /// was kept); the caller closes the whole flow.
  final VoidCallback onDone;

  @override
  ConsumerState<KeepWhichTrailScreen> createState() =>
      _KeepWhichTrailScreenState();
}

class _KeepWhichTrailScreenState extends ConsumerState<KeepWhichTrailScreen> {
  _TrailSide _selected = _TrailSide.account;
  bool _isApplying = false;

  Future<void> _apply() async {
    setState(() => _isApplying = true);
    final accountService = ref.read(accountServiceProvider);
    try {
      if (_selected == _TrailSide.device) {
        await accountService.keepThisDevice();
      } else {
        await accountService.useAccount();
      }
    } finally {
      // The real app flow always unmounts this screen immediately once
      // onDone() closes the whole account flow, so this reset is normally
      // moot - but a test (or any future caller) that keeps this screen
      // mounted past onDone() must not see a permanently spinning button.
      if (mounted) setState(() => _isApplying = false);
    }
    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final keepingDevice = _selected == _TrailSide.device;
    final consequence = keepingDevice
        ? l10n.accountConsequenceKeepDevice(widget.remote.stones)
        : l10n.accountConsequenceKeepAccount(widget.local.stones);
    final ctaLabel = keepingDevice
        ? l10n.accountKeepDeviceButton
        : l10n.accountKeepAccountButton;

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
                24,
                kScreenEdgePadding.end,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AccountHeaderBlock(
                    eyebrow: l10n.accountKeepWhichTrailEyebrow,
                    title: l10n.accountKeepWhichTrailTitle,
                    body: l10n.accountKeepWhichTrailBody,
                  ),
                  const SizedBox(height: 22),
                  _TrailOptionCard(
                    icon: const _CloudGlyph(),
                    title: l10n.accountThisAccountLabel,
                    summary: widget.remote,
                    selected: !keepingDevice,
                    onTap: () => setState(() => _selected = _TrailSide.account),
                  ),
                  const SizedBox(height: 12),
                  _TrailOptionCard(
                    icon: const _DeviceGlyph(),
                    title: l10n.accountThisDeviceLabel,
                    summary: widget.local,
                    selected: keepingDevice,
                    onTap: () => setState(() => _selected = _TrailSide.device),
                  ),
                  const SizedBox(height: 16),
                  _ConsequenceBanner(text: consequence),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              kScreenEdgePadding.start,
              16,
              kScreenEdgePadding.end,
              30,
            ),
            child: AccountSubmitButton(
              label: ctaLabel,
              loadingLabel: l10n.accountApplyingLoading,
              isLoading: _isApplying,
              onPressed: _isApplying ? null : _apply,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailOptionCard extends StatelessWidget {
  const _TrailOptionCard({
    required this.icon,
    required this.title,
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final TrailSummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    final String subtitle;
    final TextStyle subtitleStyle;
    if (summary.stones == 0) {
      subtitle = l10n.accountNoActivityYet;
      subtitleStyle = AppTextStyles.accountTrailOptionSubtitle.copyWith(
        color: AppColors.labelGrey,
        fontStyle: FontStyle.italic,
      );
    } else {
      subtitle = l10n.accountStonesLastClimbDateTime(
        summary.stones,
        formatDateTimeWithYear(summary.lastClimbAt!, locale),
      );
      subtitleStyle = AppTextStyles.accountTrailOptionSubtitle;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        selected: selected,
        label: title,
        child: Container(
          padding: const EdgeInsetsDirectional.all(16),
          decoration: BoxDecoration(
            gradient: selected ? null : AppGradients.premiumBg,
            color: selected ? AppColors.onboardingSageCardBg : null,
            border: Border.all(
              color: selected
                  ? AppColors.accountSageButtonLight
                  : AppColors.panelBorder,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          begin: Alignment(-0.64, -1),
                          end: Alignment(0.64, 1),
                          colors: [AppColors.sageLight, AppColors.sage],
                        )
                      : AppGradients.card,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: icon,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppTextStyles.accountTrailOptionTitle),
                    const SizedBox(height: 2),
                    Text(subtitle, style: subtitleStyle),
                  ],
                ),
              ),
              _SelectionDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.futureTierBorder, width: 2),
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.sageButton,
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 12,
        height: 12,
        child: CustomPaint(painter: _CheckmarkPainter()),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  const _CheckmarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.richCream
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.55)
      ..lineTo(size.width * 0.4, size.height * 0.9)
      ..lineTo(size.width * 0.95, size.height * 0.15);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) => false;
}

class _ConsequenceBanner extends StatelessWidget {
  const _ConsequenceBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accountStatusBg,
        border: Border.all(color: AppColors.accountWarningBannerBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(top: 1),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CustomPaint(painter: _WarningTrianglePainter()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: AppFontFamilies.workSans,
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.accountWarningText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningTrianglePainter extends CustomPainter {
  const _WarningTrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.terracotta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    final path = Path()
      ..moveTo(10.3 * w, 3.2 * h)
      ..lineTo(1.8 * w, 18 * h)
      ..cubicTo(1.4 * w, 18.7 * h, 1.9 * w, 21 * h, 3.5 * w, 21 * h)
      ..lineTo(20.5 * w, 21 * h)
      ..cubicTo(22.1 * w, 21 * h, 22.6 * w, 18.7 * h, 22.2 * w, 18 * h)
      ..lineTo(13.7 * w, 3.2 * h)
      ..cubicTo(12.9 * w, 1.8 * h, 11.1 * w, 1.8 * h, 10.3 * w, 3.2 * h)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(Offset(12 * w, 9.5 * h), Offset(12 * w, 13.5 * h), paint);
    canvas.drawCircle(Offset(12 * w, 17 * h), 0.6, Paint()..color = AppColors.terracotta);
  }

  @override
  bool shouldRepaint(_WarningTrianglePainter oldDelegate) => false;
}

/// The device/phone glyph on "This device"'s option card: a rounded
/// rectangle body (`x=6 y=2.5 width=12 height=19 rx=2.6`) plus a short
/// home-button line (`x1=10.5 y1=18.5 x2=13.5 y2=18.5`).
class _DeviceGlyph extends StatelessWidget {
  const _DeviceGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 21,
      height: 21,
      child: CustomPaint(painter: _DeviceGlyphPainter()),
    );
  }
}

class _DeviceGlyphPainter extends CustomPainter {
  const _DeviceGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accountDeviceIconStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6 * w, 2.5 * h, 12 * w, 19 * h),
        Radius.circular(2.6 * w),
      ),
      paint,
    );
    canvas.drawLine(Offset(10.5 * w, 18.5 * h), Offset(13.5 * w, 18.5 * h), paint);
  }

  @override
  bool shouldRepaint(_DeviceGlyphPainter oldDelegate) => false;
}

/// The cloud glyph on "This account"'s option card
/// (`<path d="M7 18h10a3.5 3.5 0 0 0 .4-6.98 5 5 0 0 0-9.6-1.4A4 4 0 0 0 7
/// 18z">`).
class _CloudGlyph extends StatelessWidget {
  const _CloudGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _CloudGlyphPainter()),
    );
  }
}

class _CloudGlyphPainter extends CustomPainter {
  const _CloudGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    final path = Path()
      ..moveTo(7 * w, 18 * h)
      ..lineTo(17 * w, 18 * h)
      ..cubicTo(19 * w, 18 * h, 20.9 * w, 16.3 * h, 20.4 * w, 11 * h)
      ..cubicTo(19.8 * w, 6.5 * h, 15.4 * w, 4.8 * h, 11.7 * w, 6.6 * h)
      ..cubicTo(9.3 * w, 4.6 * h, 5.9 * w, 6.4 * h, 3 * w, 10 * h)
      ..cubicTo(0.5 * w, 13 * h, 3.5 * w, 18 * h, 7 * w, 18 * h)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CloudGlyphPainter oldDelegate) => false;
}
