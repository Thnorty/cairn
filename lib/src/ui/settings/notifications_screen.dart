import 'dart:async';

import 'package:flutter/material.dart'
    show MaterialPageRoute, TimeOfDay, showTimePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../../models/occurrence.dart' show timeOfDayFromHHmm;
import '../../providers.dart';
import '../../repo/settings_repository.dart' show SettingsRepository;
import '../onboarding/onboarding_notifications_screen.dart' show StruckBellIcon;
import '../proof/verification_chrome.dart' show CloseCircleButton;
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/cairn_switch.dart';
import '../widgets/settings_panel.dart';

/// Pushes [NotificationsScreen] on top of the current route. Mirrors
/// `stone_style_screen.dart`'s `openStoneStyleScreen` so every settings
/// destination navigates identically.
void openNotificationsScreen(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => const NotificationsScreen(),
  ));
}

/// `Cairn Notifications.dc.html`: the Notifications settings screen, reached
/// from Profile > Settings > Notifications (the first row).
///
/// A master switch, the default reminder time for habits with no `due_times`
/// of their own, and a separate switch for streak warnings. Per-habit times
/// are deliberately NOT settable here - they already come from each task's
/// own `due_times`, set in New Habit, and duplicating that control in two
/// places would let them disagree. The caption under the panel says so, so
/// the absence reads as deliberate rather than missing.
///
/// The default-time and streak rows are dimmed and inert while the master
/// switch is off, because they control nothing in that state; only the master
/// stays live, so there is always exactly one obvious way back on.
///
/// THE BLOCKED STATE is the one worth being careful about. When the OS
/// permission is refused, the in-app switches are NOT quietly flipped off and
/// left looking broken: the app's own preference is remembered and shown, but
/// the whole panel is capped by a clay notice explaining that Android is
/// blocking delivery, with a button into system settings. "You turned this
/// off" and "Android turned this off" are different problems with different
/// fixes, and a switch that snaps back when tapped explains neither.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // The one thing on this screen that can change while it is open without
    // the app touching it: the user takes the "Open system settings" button,
    // flips notifications on over in Android's own settings, and comes back.
    // Re-reading the permission on resume is what makes the blocked notice
    // disappear on return instead of lying until the screen is reopened.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref.invalidate(notificationPermissionGrantedProvider),
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  /// Every write follows the same three steps: persist, invalidate the
  /// provider that reads it back, then re-plan. The re-plan is not optional -
  /// [NotificationTrigger] only watches the `tasks`/`completions` tables and
  /// app foreground, so a settings change would otherwise not reach the
  /// scheduler until the next time the app came back from the background.
  Future<void> _persist(
    Future<void> Function() write,
    VoidCallback invalidate,
  ) async {
    await write();
    invalidate();
    await ref.read(notificationTriggerProvider).runOnce();
  }

  Future<void> _setRemindersEnabled(bool enabled) async {
    // Turning reminders ON asks for the permission if it is not already
    // held. The preference is saved either way: if the prompt is refused the
    // switch stays on and the blocked notice appears, which is the honest
    // reading of "I want reminders, but Android won't deliver them" - see
    // this class's doc comment.
    if (enabled) {
      final granted = await ref.read(notificationPermissionGrantedProvider.future);
      if (!granted) {
        await ref.read(notificationPermissionRequesterProvider).request();
        ref.invalidate(notificationPermissionGrantedProvider);
      }
    }
    final settings = ref.read(settingsRepositoryProvider);
    await _persist(
      () => settings.setRemindersEnabled(enabled),
      () => ref.invalidate(remindersEnabledProvider),
    );
  }

  Future<void> _setStreakWarningsEnabled(bool enabled) {
    final settings = ref.read(settingsRepositoryProvider);
    return _persist(
      () => settings.setStreakWarningsEnabled(enabled),
      () => ref.invalidate(streakWarningsEnabledProvider),
    );
  }

  Future<void> _pickDefaultTime(String current) async {
    final parsed = timeOfDayFromHHmm(current);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: parsed.hour, minute: parsed.minute),
    );
    if (picked == null || !mounted) return;
    final hhmm = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    final settings = ref.read(settingsRepositoryProvider);
    await _persist(
      () => settings.setDefaultReminderTime(hhmm),
      () => ref.invalidate(defaultReminderTimeProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    // Each of these reads back a near-instant local settings row. While any
    // is still loading the screen renders its default rather than a spinner,
    // matching how OnboardingGate treats the same kind of read: a flash of
    // "off" for one frame is less jarring than a loading state on a settings
    // list.
    final remindersEnabled =
        ref.watch(remindersEnabledProvider).asData?.value ?? false;
    final streakWarningsEnabled =
        ref.watch(streakWarningsEnabledProvider).asData?.value ?? true;
    final defaultTime = ref.watch(defaultReminderTimeProvider).asData?.value ??
        SettingsRepository.defaultReminderTimeFallback;
    final permissionGranted =
        ref.watch(notificationPermissionGrantedProvider).asData?.value ?? true;

    // The notice is about *delivery* being blocked, so it only means anything
    // once the user has actually asked for reminders. With them off, a denied
    // permission is simply irrelevant and saying so would be noise.
    final showBlockedNotice = remindersEnabled && !permissionGranted;

    return ModalScaffold(
      // The design's phone screen is a flat parchment field: no washes and
      // no contour rings at all (see the file's own inner screen div, which
      // has neither a radial-gradient nor a repeating-radial-gradient layer)
      // - the same choice `Cairn Stone Styles.dc.html` makes.
      washes: const [],
      showContour: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(26, 16, 26, 0),
            child: CloseCircleButton(onTap: () => Navigator.of(context).pop()),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(26, 14, 26, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.profileSettingsSectionLabel, style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 5),
                  Text(l10n.notificationsScreenTitle, style: AppTextStyles.screenTitle),
                  if (showBlockedNotice) ...[
                    const SizedBox(height: 22),
                    _BlockedNotice(
                      l10n: l10n,
                      onOpenSettings: () => unawaited(
                        ref.read(appSettingsOpenerProvider).openAppSettings(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 24),
                  Opacity(
                    // The whole panel dims when nothing in it can be
                    // delivered, while staying fully legible and still
                    // showing the user's real saved choices.
                    opacity: showBlockedNotice ? 0.55 : 1.0,
                    child: SettingsPanel(
                      child: Column(
                        children: [
                          _SwitchRow(
                            key: const ValueKey('notifications-master-row'),
                            title: l10n.notificationsMasterRowTitle,
                            subtitle: l10n.notificationsMasterRowSubtitle,
                            value: remindersEnabled,
                            onChanged: (v) => unawaited(_setRemindersEnabled(v)),
                          ),
                          const HairlineDivider(),
                          _DefaultTimeRow(
                            key: const ValueKey('notifications-default-time-row'),
                            title: l10n.notificationsDefaultTimeRowTitle,
                            subtitle: l10n.notificationsDefaultTimeRowSubtitle,
                            value: formatTimeOfDay(
                              timeOfDayFromHHmm(defaultTime),
                              locale,
                            ),
                            enabled: remindersEnabled,
                            onTap: () => unawaited(_pickDefaultTime(defaultTime)),
                          ),
                          const HairlineDivider(),
                          _SwitchRow(
                            key: const ValueKey('notifications-streak-row'),
                            title: l10n.notificationsStreakRowTitle,
                            subtitle: l10n.notificationsStreakRowSubtitle,
                            value: streakWarningsEnabled,
                            enabled: remindersEnabled,
                            onChanged: (v) =>
                                unawaited(_setStreakWarningsEnabled(v)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                    child: Text(
                      l10n.notificationsFooterCaption,
                      style: AppTextStyles.notificationsFooterCaption,
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

// ---------------------------------------------------------------------------
// Rows
// ---------------------------------------------------------------------------

/// The label/subtitle half every row on this screen shares, plus the
/// design's `opacity:.42` dim for a row the master switch has made inert.
/// The dim lives on the whole row rather than on the control alone, so the
/// title, subtitle and control fade together.
class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.notificationsRowTitle),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.notificationsRowSubtitle),
              ],
            ),
          ),
          const SizedBox(width: 14),
          trailing,
        ],
      ),
    );

    final dimmed = enabled ? row : Opacity(opacity: 0.42, child: row);
    final tap = onTap;
    if (tap == null || !enabled) return dimmed;
    return GestureDetector(
      onTap: tap,
      behavior: HitTestBehavior.opaque,
      child: dimmed,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      trailing: CairnSwitch(
        value: value,
        semanticLabel: title,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _DefaultTimeRow extends StatelessWidget {
  const _DefaultTimeRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      onTap: onTap,
      trailing: Semantics(
        button: true,
        enabled: enabled,
        label: '$title, $value',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: AppTextStyles.notificationsRowValue),
            const SizedBox(width: 7),
            const SizedBox(
              width: 17,
              height: 17,
              child: CustomPaint(painter: _RowChevronPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small chevron-right glyph (`M9 6l6 6-6 6`) on the default-time row.
/// Duplicated privately rather than shared with
/// `new_habit_recurrence_panel.dart`'s identical private painter, per this
/// codebase's existing precedent for small one-off glyphs (the two differ in
/// stroke colour and width anyway: `#a19785` at 2.2 here).
class _RowChevronPainter extends CustomPainter {
  const _RowChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 24;
    final h = size.height / 24;
    canvas.drawPath(
      Path()
        ..moveTo(9 * w, 6 * h)
        ..lineTo(15 * w, 12 * h)
        ..lineTo(9 * w, 18 * h),
      Paint()
        ..color = AppColors.rowChevron
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_RowChevronPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Blocked notice
// ---------------------------------------------------------------------------

/// The clay "Android is blocking these" cap over the preferences panel.
class _BlockedNotice extends StatelessWidget {
  const _BlockedNotice({required this.l10n, required this.onOpenSettings});

  final AppLocalizations l10n;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppColors.notificationsBlockedBg,
        border: Border.all(color: AppColors.notificationsBlockedBorder),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.notificationsBlockedIconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const StruckBellIcon(size: 17, color: AppColors.terracotta),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.notificationsBlockedTitle,
                      style: AppTextStyles.notificationsBlockedTitle,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.notificationsBlockedBody,
                      style: AppTextStyles.notificationsBlockedBody,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          PrimaryButton(
            label: l10n.notificationsOpenSystemSettingsButton,
            size: PrimaryButtonSize.medium,
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}
