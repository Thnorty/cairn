import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_text_styles.dart';
import '../widgets/buttons.dart';
import '../widgets/status_chip.dart';
import 'verification_chrome.dart';

/// `Cairn Verify Pending.dc.html`: shown for [CompletionPendingVerification]
/// (offline, or the verifier was otherwise unreachable). Per CLAUDE.md's
/// pending-completion rule, the stone is already placed and the streak
/// already counts today; only the metres are held back until the retry
/// resolves - [heldMetres] is `completion.pointsAwarded`, computed and
/// stored by the repository at insert time, not recomputed here.
class VerifyPendingScreen extends StatelessWidget {
  const VerifyPendingScreen({
    super.key,
    required this.taskTitle,
    required this.completedAtMillis,
    required this.imageBytes,
    required this.heldMetres,
    required this.onBackToToday,
  });

  final String taskTitle;
  final int completedAtMillis;
  final Uint8List imageBytes;
  final int heldMetres;
  final VoidCallback onBackToToday;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final time = formatTimeOfDay(
      DateTime.fromMillisecondsSinceEpoch(completedAtMillis),
      locale,
    );
    final metres = formatMetresNumber(heldMetres, locale);

    return ProofOutcomeScaffold(
      washes: const [
        RadialGradient(
          center: Alignment(0, -1.16),
          radius: 1.15,
          colors: [Color(0x3D968368), Color(0x00968368)],
        ),
        RadialGradient(
          center: Alignment(1, -1),
          radius: 0.9,
          colors: [Color(0x29968368), Color(0x00968368)],
        ),
      ],
      contourOrigin: percentPositionToAlignment(50, -6),
      contourRingColor: const Color(0x0D5A4E3A),
      onClose: onBackToToday,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SealCircle(
            gradientColors: [
              AppColors.pendingSealLight,
              AppColors.pendingSealDark,
            ],
            ringColor: Color(0x29A0947E),
            shadowColor: Color(0x735A503C),
            icon: SealClockIcon(),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.verifyPendingTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.resultTitle.copyWith(
              color: AppColors.pendingHeading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.taskNameAtTime(taskTitle, time),
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 18),
          ProofPhotoPebble(
            imageBytes: imageBytes,
            height: 166,
            overlay: StatusChip(
              variant: StatusChipVariant.awaiting,
              onPhoto: true,
              label: l10n.awaitingVerificationChip,
            ),
          ),
          const SizedBox(height: 14),
          ReasonBanner(
            backgroundColor: const Color(0x1F786C58),
            iconColor: const Color(0xFF8A7F6C),
            leadText: l10n.offlineReassuranceLead,
            leadColor: const Color(0xFF463F31),
            bodyText: l10n.offlineReassuranceBody,
            textColor: const Color(0xFF544D40),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoChipCard(
                  icon: const _StreakSafeIcon(),
                  title: l10n.streakSafeLabel,
                  subtitle: l10n.streakSafeSubtext,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoChipCard(
                  icon: const _HeldMetresIcon(),
                  title: l10n.heldMetresLabel(metres),
                  subtitle: l10n.landsOnVerifyLabel,
                ),
              ),
            ],
          ),
        ],
      ),
      footer: [
        PrimaryButton(
          label: l10n.backToTodayButton,
          onPressed: onBackToToday,
        ),
      ],
    );
  }
}

/// One of the two info cards on the pending screen (streak-safe / held
/// metres): an icon plus a bold title and a muted subtitle line.
class _InfoChipCard extends StatelessWidget {
  const _InfoChipCard({required this.icon, required this.title, required this.subtitle});

  final Widget icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppFontFamilies.workSans,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF3F3A2F),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: AppFontFamilies.workSans,
                    fontSize: 12,
                    color: Color(0xFF5A5346),
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

/// The lightning-bolt "streak" glyph (`M13 2L5 13h6l-1 9 8-11h-6z`).
class _StreakSafeIcon extends StatelessWidget {
  const _StreakSafeIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 17,
      height: 17,
      child: CustomPaint(painter: _StreakSafeIconPainter()),
    );
  }
}

class _StreakSafeIconPainter extends CustomPainter {
  const _StreakSafeIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7D8A5F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 24;
    final h = size.height / 24;
    final path = Path()
      ..moveTo(13 * w, 2 * h)
      ..lineTo(5 * w, 13 * h)
      ..lineTo(11 * w, 13 * h)
      ..lineTo(10 * w, 22 * h)
      ..lineTo(18 * w, 11 * h)
      ..lineTo(12 * w, 11 * h)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StreakSafeIconPainter oldDelegate) => false;
}

/// A tiny 3-stone mini-cairn glyph for the "held metres" info card.
class _HeldMetresIcon extends StatelessWidget {
  const _HeldMetresIcon();

  static const _bars = [
    (width: 8.0, color: Color(0xFFB7A98F)),
    (width: 14.0, color: Color(0xFFC8BBA1)),
    (width: 19.0, color: Color(0xFFB7A98F)),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final bar in _bars) ...[
            Container(
              width: bar.width,
              height: 5,
              margin: const EdgeInsets.only(bottom: 0.5),
              decoration: BoxDecoration(color: bar.color, borderRadius: BorderRadius.circular(2.5)),
            ),
          ],
        ],
      ),
    );
  }
}
