// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Cairn';

  @override
  String get navToday => 'Today';

  @override
  String get navTrail => 'Trail';

  @override
  String get navStats => 'Stats';

  @override
  String get navYou => 'You';

  @override
  String get newHabitButton => 'New habit';

  @override
  String goodMorningGreeting(String name) {
    return 'Good morning, $name';
  }

  @override
  String get todaySectionLabel => 'TODAY';

  @override
  String get verificationHeaderLabel => 'VERIFICATION';

  @override
  String tasksDoneCount(int done, num total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total done',
      one: '$total done',
    );
    return '$done of $_temp0';
  }

  @override
  String stonesThisWeek(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stones this week',
      one: '1 stone this week',
    );
    return '$_temp0';
  }

  @override
  String verifiedAt(String time) {
    return 'Verified · $time';
  }

  @override
  String taskSummaryVerifiedNewStone(int cairnNumber, num stoneCount) {
    String _temp0 = intl.Intl.pluralLogic(
      stoneCount,
      locale: localeName,
      other: '$stoneCount stones',
      one: '1 stone',
    );
    return 'Cairn $cairnNumber · $_temp0 · new stone placed';
  }

  @override
  String taskSummaryAwaitingVerification(
    int cairnNumber,
    num stoneCount,
    String metres,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      stoneCount,
      locale: localeName,
      other: '$stoneCount stones',
      one: '1 stone',
    );
    return 'Cairn $cairnNumber · $_temp0 · $metres m when verified';
  }

  @override
  String taskSummaryDueToday(int cairnNumber, num stoneCount) {
    String _temp0 = intl.Intl.pluralLogic(
      stoneCount,
      locale: localeName,
      other: '$stoneCount stones',
      one: '1 stone',
    );
    return 'Due today · Cairn $cairnNumber · $_temp0';
  }

  @override
  String taskSummaryScheduled(int cairnNumber, num stoneCount) {
    String _temp0 = intl.Intl.pluralLogic(
      stoneCount,
      locale: localeName,
      other: '$stoneCount stones',
      one: '1 stone',
    );
    return 'Cairn $cairnNumber · $_temp0';
  }

  @override
  String taskSummaryNoStonePlaced(int cairnNumber, num stoneCount) {
    String _temp0 = intl.Intl.pluralLogic(
      stoneCount,
      locale: localeName,
      other: '$stoneCount stones',
      one: '1 stone',
    );
    return 'Cairn $cairnNumber · $_temp0 · no stone placed';
  }

  @override
  String get awaitingVerificationChip => 'Awaiting verification';

  @override
  String get proofThumbnailPlaceholderLabel => 'proof';

  @override
  String get fallbackDisplayName => 'Friend';

  @override
  String get proveItButton => 'Prove it';

  @override
  String scheduledAt(String time) {
    return 'Scheduled · $time';
  }

  @override
  String get emptyTodayTitle => 'Your first stone is waiting';

  @override
  String get emptyTodayBody =>
      'Add a habit, prove it once, and watch your cairn begin to rise.';

  @override
  String get verifyPendingTitle => 'Saved. We\'ll verify it soon.';

  @override
  String taskNameAtTime(String taskName, String time) {
    return '$taskName · $time';
  }

  @override
  String get offlineReassuranceLead => 'No connection right now.';

  @override
  String get offlineReassuranceBody =>
      'Your proof is saved on this device - we\'ll verify it automatically the moment you\'re back online.';

  @override
  String get streakSafeLabel => 'Streak safe';

  @override
  String get streakSafeSubtext => 'counts today';

  @override
  String heldMetresLabel(String metres) {
    return '$metres m held';
  }

  @override
  String get landsOnVerifyLabel => 'lands on verify';

  @override
  String get backToTodayButton => 'Back to Today';

  @override
  String get verifiedTitle => 'Verified';

  @override
  String get verifyReasonPositiveLead => 'Looks good.';

  @override
  String get doneButton => 'Done';

  @override
  String get couldntVerifyTitle => 'Couldn\'t verify';

  @override
  String get notVerifiedChip => 'Not verified';

  @override
  String get retakePhotoButton => 'Retake photo';

  @override
  String triesLeftToday(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tries left today',
      one: '1 try left today',
    );
    return '$_temp0';
  }

  @override
  String get cancelButton => 'Cancel';

  @override
  String allAttemptsUsedLead(int maxAttempts) {
    return 'You\'ve used all $maxAttempts attempts for this task today.';
  }

  @override
  String get allAttemptsUsedDetail =>
      'The last photo looked like a screenshot rather than a live capture. Try again tomorrow with a photo of the page directly.';

  @override
  String get tryAgainTomorrowButton => 'Try again tomorrow';

  @override
  String get attemptsResetMidnight => 'Attempts reset at midnight';

  @override
  String get dailyLimitTitle => 'That\'s today\'s five';

  @override
  String dailyLimitBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free AI proofs',
      one: '1 free AI proof',
    );
    return 'You\'ve used all $_temp0 for today. This stone is ready - it\'ll settle onto your cairn as soon as your proofs reset.';
  }

  @override
  String get resetsAtMidnight => 'Resets at midnight';

  @override
  String get goUnlimitedButton => 'Go unlimited';

  @override
  String get maybeLaterButton => 'Maybe later';

  @override
  String get provingLabel => 'PROVING';

  @override
  String get galleryButton => 'Gallery';

  @override
  String get flipCameraButton => 'Flip';

  @override
  String get verifyingTitle => 'Verifying…';

  @override
  String verifyingSubtitle(String taskName) {
    return 'Checking your proof for “$taskName”';
  }

  @override
  String get proveItHeaderLabel => 'PROVE IT';

  @override
  String get verifyTooOldTitle => 'This photo is too old';

  @override
  String taskNameTakenAt(String taskName, String time) {
    return '$taskName · taken $time';
  }

  @override
  String stalePhotoAgeBadge(num minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min old',
      one: '$minutes min old',
    );
    return '$_temp0';
  }

  @override
  String get stalePhotoReassuranceLead =>
      'Proof has to be taken in the moment.';

  @override
  String stalePhotoReassuranceBody(int minutes) {
    return 'Photos more than $minutes minutes old can\'t be verified, so snap a fresh one right as you finish.';
  }

  @override
  String get stalePhotoAttemptsIntro =>
      'This didn\'t use a try. You still have';

  @override
  String stalePhotoAttemptsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count left today',
      one: '1 left today',
    );
    return '$_temp0';
  }

  @override
  String get takeNewPhotoButton => 'Take a new photo';

  @override
  String get cameraUnavailableTitle => 'Camera unavailable';

  @override
  String get cameraUnavailableBodyLead =>
      'Cairn couldn\'t open your camera. You can prove';

  @override
  String get cameraUnavailableBodyTrail =>
      'with a photo from your gallery instead.';

  @override
  String get recentPhotosLabel => 'RECENT PHOTOS';

  @override
  String get recentPhotoThumbnailLabel => 'Recent photo';

  @override
  String get settingsHintLead =>
      'To use the camera, allow Cairn camera access in';

  @override
  String get settingsHintEmphasis => 'Settings › Apps › Cairn › Permissions';

  @override
  String get settingsHintTrail =>
      '. Gallery proofs still need a recent, in-the-moment photo.';

  @override
  String get chooseFromGalleryButton => 'Choose from gallery';

  @override
  String get openCameraSettingsButton => 'Open camera settings';

  @override
  String get newHabitScreenTitle => 'New habit';

  @override
  String get whatAreYouProvingLabel => 'WHAT ARE YOU PROVING?';

  @override
  String get howOftenLabel => 'HOW OFTEN?';

  @override
  String get recurrenceOnceLabel => 'Once';

  @override
  String get recurrenceDailyLabel => 'Daily';

  @override
  String get recurrenceWeeklyLabel => 'Weekly';

  @override
  String get recurrenceMonthlyLabel => 'Monthly';

  @override
  String get onTheseDaysLabel => 'On these days';

  @override
  String get dayOfTheMonthLabel => 'Day of the month';

  @override
  String get monthlyClampHelpText =>
      'Months without this day will use the last day of the month.';

  @override
  String get whichWeekLabel => 'Which week';

  @override
  String get whichDayLabel => 'Which day';

  @override
  String monthlyDayToggleLabel(String day) {
    return 'On the $day';
  }

  @override
  String monthlyNthWeekdayToggleLabel(String nth, String weekday) {
    return 'On the $nth $weekday';
  }

  @override
  String get monthlyWeekLastLabel => 'Last';

  @override
  String get onThisDateLabel => 'On this date';

  @override
  String get timesOfDayLabel => 'TIMES OF DAY';

  @override
  String get timeOfDayLabel => 'TIME OF DAY';

  @override
  String get timesOfDayHelpText =>
      'Each time is one proof - two times means a twice-a-day habit.';

  @override
  String get onceTimeHelpText =>
      'Optional - a reminder to prove it on the day.';

  @override
  String get addTimeButton => 'Add a time';

  @override
  String get createHabitButton => 'Create habit';

  @override
  String get usePhotoButton => 'Use this photo';

  @override
  String get retakeButton => 'Retake';

  @override
  String get chooseAnotherPhotoButton => 'Choose another';

  @override
  String get photoReviewPrompt => 'Does this show your proof clearly?';

  @override
  String get profileHeaderLabel => 'PROFILE';

  @override
  String get profileCurrentRankLabel => 'CURRENT RANK';

  @override
  String profileMetresGainedLabel(String metres) {
    return '$metres m gained';
  }

  @override
  String profilePendingMetresLabel(String metres) {
    return '+$metres m awaiting verification';
  }

  @override
  String profileMetresToNextTier(String metres, String tier) {
    return '$metres m to $tier';
  }

  @override
  String get profileYoureHereLabel => 'You\'re here';

  @override
  String profileNextTierMetres(String metres) {
    return '$metres m · next';
  }

  @override
  String profileTierMetres(String metres) {
    return '$metres m';
  }

  @override
  String get profileClimbingAnonymouslyTitle => 'Climbing anonymously';

  @override
  String get profileCreateAccountBody =>
      'Create an account so your trail is never lost.';

  @override
  String get profileCreateButton => 'Create';

  @override
  String get profilePremiumTitle => 'Cairn Premium';

  @override
  String get profilePremiumSubtitle =>
      'Unlimited proofs, backup, deeper insights.';

  @override
  String get profileComingSoonSnackbar => 'Coming soon';

  @override
  String get profileSettingsSectionLabel => 'SETTINGS';

  @override
  String get profileNotificationsRow => 'Notifications';

  @override
  String get profilePrivacyRow => 'Privacy';

  @override
  String get profileRestorePurchaseRow => 'Restore purchase';
}
