import 'package:cairn/src/services/notification_strings.dart';

/// Fixed sentinel copy for [NotificationPlanner]'s tests.
///
/// Deliberately NOT the real ARB strings: the planner's tests are about
/// *which* notifications get planned and *when*, and pinning them to product
/// copy would make an innocuous wording change fail unrelated scheduling
/// tests. The interpolations are still exercised (both bodies embed their
/// arguments), so a test that does care can assert on these.
const NotificationStrings testNotificationStrings = NotificationStrings(
  reminderTitle: 'reminder-title',
  reminderBody: _reminderBody,
  streakWarningTitle: 'streak-title',
  streakWarningBody: _streakWarningBody,
);

String _reminderBody(String taskTitle) => 'reminder-body:$taskTitle';

String _streakWarningBody(String taskTitle, int streakDays) =>
    'streak-body:$taskTitle:$streakDays';
