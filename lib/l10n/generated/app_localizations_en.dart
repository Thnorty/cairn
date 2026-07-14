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
  String get offlineReassuranceMessage =>
      'No connection right now. Your proof is saved on this device - we\'ll verify it automatically the moment you\'re back online.';

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
}
