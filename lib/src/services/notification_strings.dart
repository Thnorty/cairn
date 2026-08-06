/// The localized copy [NotificationPlanner] stamps onto each
/// `PendingNotification` it plans.
///
/// Injected rather than looked up, because the planner lives in the service
/// layer and runs from [NotificationTrigger] - a lifecycle listener and a
/// database subscription, neither of which has a [BuildContext] to resolve
/// `AppLocalizations` from. Passing the resolved strings in keeps the
/// service layer free of any `lib/src/ui/` or `AppLocalizations` import (the
/// same dependency-direction rule `timeOfDayFromHHmm`'s move into
/// `lib/src/models/occurrence.dart` was made to preserve), and lets the
/// planner's own unit tests assert on fixed sentinel copy instead of
/// whatever the ARB currently says.
///
/// The two bodies are functions rather than pre-formatted strings because
/// they take the task title and streak length, which the planner only knows
/// per-notification; `notificationStringsProvider` binds them straight to
/// the generated ICU-aware `AppLocalizations` methods (the streak body is a
/// plural).
class NotificationStrings {
  /// Title of a per-occurrence "this habit is due" reminder.
  final String reminderTitle;

  /// Body of a per-occurrence reminder, naming the task.
  final String Function(String taskTitle) reminderBody;

  /// Title of the evening streak-at-risk warning.
  final String streakWarningTitle;

  /// Body of the streak-at-risk warning, naming the task and how many
  /// consecutive days the streak currently stands at.
  final String Function(String taskTitle, int streakDays) streakWarningBody;

  const NotificationStrings({
    required this.reminderTitle,
    required this.reminderBody,
    required this.streakWarningTitle,
    required this.streakWarningBody,
  });
}
