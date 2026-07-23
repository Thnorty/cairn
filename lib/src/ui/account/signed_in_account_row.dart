import 'package:flutter/material.dart'
    show AlertDialog, TextButton, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/tab_icons.dart';

/// Frame 6 of `Cairn Account.dc.html`: the Profile screen's signed-in
/// account row, replacing the anonymous "Climbing anonymously / Create"
/// row once the account upgrade completes - avatar with a sage check
/// badge, "Signed in", the email, "Your trail is backed up.", and a clay
/// "Sign out" pill (styled as a button, not body text, per the design's own
/// variant note: it's a clickable action).
class SignedInAccountRow extends ConsumerWidget {
  const SignedInAccountRow({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    Future<void> confirmSignOut() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.accountSignOutConfirmTitle),
          content: Text(l10n.accountSignOutConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancelButton),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.accountSignOutButton),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await ref.read(accountServiceProvider).signOut();
      ref.invalidate(accountStateProvider);
    }

    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppColors.onboardingSageCardBg,
        border: Border.all(color: AppColors.onboardingSageCardBorder),
        borderRadius: BorderRadius.circular(AppRadii.rowCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _SignedInAvatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.accountSignedInTitle, style: AppTextStyles.accountSignedInTitle),
                const SizedBox(height: 1),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.accountSignedInEmail,
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.accountTrailBackedUpLabel,
                  style: AppTextStyles.accountBackedUpLabel,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: confirmSignOut,
            behavior: HitTestBehavior.opaque,
            child: Semantics(
              button: true,
              label: l10n.accountSignOutButton,
              child: Container(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accountSignOutBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.accountSignOutButton,
                  style: AppTextStyles.accountSignOutLabel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedInAvatar extends StatelessWidget {
  const _SignedInAvatar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppGradients.accountAvatar,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const TabBarIcon(
              shape: TabIconShape.you,
              color: AppColors.accountIconStroke,
              size: 20,
            ),
          ),
          PositionedDirectional(
            end: -2,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                gradient: AppGradients.sageButton,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.screenBackground, width: 2),
              ),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 10,
                height: 10,
                child: CustomPaint(painter: _CheckPainter()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.richCream
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.55)
      ..lineTo(size.width * 0.4, size.height * 0.9)
      ..lineTo(size.width * 0.95, size.height * 0.15);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => false;
}
