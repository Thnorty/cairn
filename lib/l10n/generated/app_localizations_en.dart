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
  String get cairnCompleteHeaderLabel => 'CAIRN COMPLETE';

  @override
  String cairnCompleteHeadline(int cairnNumber) {
    return 'Cairn $cairnNumber complete';
  }

  @override
  String get cairnCompleteSubline => 'Ten stones stacked and sealed.';

  @override
  String cairnCompleteBonusAmount(String metres) {
    return '+$metres m';
  }

  @override
  String get cairnCompleteBonusLabel => 'cairn bonus';

  @override
  String get cairnCompleteTeachingLead =>
      'Every 10 stones caps a cairn and earns a bonus.';

  @override
  String cairnCompleteTeachingNext(int nextCairnNumber) {
    return 'Cairn $nextCairnNumber starts with your next stone.';
  }

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
      'Tap to create an account and back up your trail to any device.';

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

  @override
  String get profileHowCairnsWorkRow => 'How cairns work';

  @override
  String get trailHeaderEyebrow => 'TRAIL OF';

  @override
  String trailRankMetresLabel(String metres) {
    return '$metres m';
  }

  @override
  String get trailGrowingNowBadge => 'GROWING NOW';

  @override
  String trailCairnStoneCount(int cairnNumber, num stoneCount) {
    String _temp0 = intl.Intl.pluralLogic(
      stoneCount,
      locale: localeName,
      other: '$stoneCount stones',
      one: '1 stone',
    );
    return 'Cairn $cairnNumber · $_temp0';
  }

  @override
  String trailCairnLabel(int cairnNumber) {
    return 'Cairn $cairnNumber';
  }

  @override
  String trailCappedCaption(num stoneCount) {
    String _temp0 = intl.Intl.pluralLogic(
      stoneCount,
      locale: localeName,
      other: '$stoneCount stones',
      one: '1 stone',
    );
    return '$_temp0 · capped';
  }

  @override
  String trailBrokenCaption(num stoneCount) {
    String _temp0 = intl.Intl.pluralLogic(
      stoneCount,
      locale: localeName,
      other: '$stoneCount stones',
      one: '1 stone',
    );
    return 'broken · $_temp0';
  }

  @override
  String trailTrailheadCaption(String date) {
    return 'The trailhead · $date';
  }

  @override
  String get trailWhereYouStartedLabel => 'WHERE YOU STARTED';

  @override
  String get trailEmptyTrailBody => 'Your first stone starts the trail.';

  @override
  String get howCairnsWorkHeaderLabel => 'HOW CAIRNS WORK';

  @override
  String get howCairnsWorkTitle => 'Every stone builds a cairn';

  @override
  String get howCairnsWorkSubhead =>
      'A cairn is a stack of stones that marks a trail. Yours grows one proof at a time.';

  @override
  String get howCairnsWorkLegendGrowing => 'Growing';

  @override
  String get howCairnsWorkLegendCapped => 'Capped';

  @override
  String get howCairnsWorkLegendBroken => 'Broken';

  @override
  String get howCairnsWorkRow1Title => 'One proof, one stone';

  @override
  String get howCairnsWorkRow1Body =>
      'Every verified photo places a stone on the cairn you are building now.';

  @override
  String get howCairnsWorkRow2Title => 'Ten stones cap a cairn';

  @override
  String get howCairnsWorkRow2Lead =>
      'Fill a cairn to ten and it is sealed for good, with a';

  @override
  String howCairnsWorkRow2Bonus(String bonus) {
    return '+$bonus m';
  }

  @override
  String get howCairnsWorkRow2Trail =>
      'bonus. The next stone starts a new one.';

  @override
  String get howCairnsWorkRow3Title => 'A missed day breaks it';

  @override
  String get howCairnsWorkRow3Body =>
      'Skip a scheduled day and the current cairn seals early as broken. A fresh one begins next time.';

  @override
  String get howCairnsWorkRow4Title => 'Stones lift your rank';

  @override
  String get howCairnsWorkRow4Body =>
      'Each stone earns metres, more on a streak, a perfect day, or a cap. Metres raise your rank, and rank never falls.';

  @override
  String get howCairnsWorkGotItButton => 'Got it';

  @override
  String get statsHeaderEyebrow => 'YOUR GROUND';

  @override
  String get statsStonesPlacedLabel => 'Stones placed';

  @override
  String get statsCairnsBuiltLabel => 'Cairns built';

  @override
  String get statsProofsUsedTodayLabel => 'Proofs used today';

  @override
  String statsProofsUsedCount(int used, int cap) {
    return '$used of $cap';
  }

  @override
  String get statsThisWeekLabel => 'This week';

  @override
  String get statsCurrentStreaksLabel => 'CURRENT STREAKS';

  @override
  String statsStreakDaysCount(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get statsNoActiveStreaksLabel => 'No active streaks yet';

  @override
  String get statsDeeperInsightsTitle => 'Deeper insights';

  @override
  String get statsDeeperInsightsSubtitle =>
      'Consistency curves, best times of day, rank projections.';

  @override
  String get statsPremiumBadge => 'PREMIUM';

  @override
  String get statsComingSoonSnackbar => 'Coming soon';

  @override
  String get premiumEyebrow => 'CAIRN PREMIUM';

  @override
  String get premiumHeadline => 'Keep every stone, on every peak';

  @override
  String get premiumValueUnlimitedProofsTitle => 'Unlimited AI proofs';

  @override
  String get premiumValueUnlimitedProofsSubtitle =>
      'No daily cap. Prove as many habits as you keep.';

  @override
  String get premiumValueCloudBackupTitle => 'Cloud photo backup';

  @override
  String get premiumValueCloudBackupSubtitle =>
      'Every proof photo saved and restorable on any phone.';

  @override
  String get premiumValueWidgetsTitle => 'Home-screen widgets';

  @override
  String get premiumValueWidgetsSubtitle =>
      'Your cairn on your home screen. Tap to prove.';

  @override
  String get premiumValueStoneStylesTitle => 'Stone styles';

  @override
  String get premiumValueStoneStylesSubtitle =>
      'Slate, granite, basalt. Make your cairn yours.';

  @override
  String get premiumYearlyPlanTitle => 'Yearly';

  @override
  String get premiumYearlyPlanSubtitle => '\$27.99/yr · \$2.33/mo';

  @override
  String get premiumYearlyPlanPrice => '\$27.99';

  @override
  String get premiumMonthlyPlanTitle => 'Monthly';

  @override
  String get premiumMonthlyPlanSubtitle => 'Billed every month';

  @override
  String get premiumMonthlyPlanPrice => '\$3.99';

  @override
  String get premiumBestValueRibbon => 'BEST VALUE · SAVE 42%';

  @override
  String get premiumStartTrialButton => 'Start 7-day free trial';

  @override
  String get premiumTrialSubtitle => 'Then \$27.99/yr · cancel anytime';

  @override
  String get premiumTermsLink => 'Terms';

  @override
  String get premiumPrivacyLink => 'Privacy';

  @override
  String get premiumComingSoonSnackbar => 'Coming soon';

  @override
  String get onboardingWelcomeHeadlineLine1 => 'Don\'t just check it off.';

  @override
  String get onboardingWelcomeHeadlineAccent => 'Prove it.';

  @override
  String get onboardingWelcomeSubhead =>
      'Cairn turns real effort into something you can see grow: one verified stone at a time.';

  @override
  String get onboardingWelcomeClarifier =>
      'A cairn is a small stack of stones that hikers build to mark a trail.';

  @override
  String get onboardingStep1Title => 'Do the thing.';

  @override
  String get onboardingStep1Body => 'Your habit, in the real world.';

  @override
  String get onboardingStep2Title => 'Snap a photo.';

  @override
  String get onboardingStep2Body => 'A quick proof of what you did.';

  @override
  String get onboardingStep3Title => 'AI verifies.';

  @override
  String get onboardingStep3Body => 'A stone settles on your cairn.';

  @override
  String get onboardingStartClimbingButton => 'Start climbing';

  @override
  String get onboardingAlreadyHaveAccountButton => 'I already have an account';

  @override
  String get onboardingSignInComingSoonSnackbar =>
      'Signing in to an existing account is coming soon.';

  @override
  String get onboardingHowItWorksTitle => 'How it works';

  @override
  String get onboardingContinueButton => 'Continue';

  @override
  String get onboardingVerificationTitle => 'How verification works';

  @override
  String get onboardingVerificationSubhead =>
      'A quick check keeps every stone honest. Here\'s exactly what happens to your photo.';

  @override
  String get onboardingPoint1Title => 'Sent only to be checked';

  @override
  String get onboardingPoint1Body =>
      'Your photo is sent to an AI (Google Gemini) to confirm it matches your habit, nothing else.';

  @override
  String get onboardingPoint2Title => 'Never stored in the cloud';

  @override
  String get onboardingPoint2Body =>
      'We don\'t keep your photos on our servers. They\'re checked, then discarded.';

  @override
  String get onboardingPoint3Title => 'Your archive lives on your phone';

  @override
  String get onboardingPoint3Body =>
      'Proof photos are saved on your device. Cloud backup is optional with Premium.';

  @override
  String get onboardingCameraPermissionLead => 'Cairn needs your camera';

  @override
  String get onboardingCameraPermissionBody =>
      'to capture proof of each habit.';

  @override
  String get onboardingAllowCameraButton => 'Allow camera';

  @override
  String get onboardingLearnMorePrivacyLink => 'Learn more about privacy';

  @override
  String get onboardingPrivacyComingSoonSnackbar =>
      'A privacy details page is coming soon.';

  @override
  String get accountEyebrowLabel => 'ACCOUNT';

  @override
  String get accountCreateTitle => 'Keep your trail safe';

  @override
  String get accountCreateBody =>
      'Create an account and your stones, cairns, and rank move with you to any device. Nothing you\'ve climbed is lost.';

  @override
  String get accountFreeTrailChip => 'Free. Your trail stays exactly as it is.';

  @override
  String get accountEmailLabel => 'Email';

  @override
  String get accountEmailHint => 'you@example.com';

  @override
  String get accountPasswordLabel => 'Password';

  @override
  String accountPasswordHintCreate(int min) {
    return 'At least $min characters';
  }

  @override
  String get accountPasswordHintSignIn => 'Your password';

  @override
  String get accountCreateButton => 'Create account';

  @override
  String get accountCreatingAccountLoading => 'Creating account...';

  @override
  String get accountAlreadyHaveAccountLead => 'Already have an account?';

  @override
  String get accountSignInLink => 'Sign in';

  @override
  String get accountSignInTitle => 'Welcome back';

  @override
  String get accountSignInBody =>
      'Sign in to pick up your trail on this device.';

  @override
  String get accountForgotPasswordLink => 'Forgot password?';

  @override
  String get accountForgotPasswordNeedsEmailError =>
      'Enter your email above first, then tap Forgot password.';

  @override
  String get accountForgotPasswordTitle => 'Forgot your password?';

  @override
  String get accountForgotPasswordBody =>
      'Enter your account email and we\'ll send you a 6-digit code to reset it.';

  @override
  String get accountSendCodeButton => 'Send code';

  @override
  String get accountSendingCodeLoading => 'Sending code...';

  @override
  String get accountRememberedItLead => 'Remembered it?';

  @override
  String get accountInvalidEmailError => 'Enter a valid email address.';

  @override
  String get accountSigningInLoading => 'Signing in...';

  @override
  String get accountNewHereLead => 'New here?';

  @override
  String get accountCreateAccountLink => 'Create an account';

  @override
  String get accountEnterCodeEyebrow => 'Verify';

  @override
  String get accountEnterCodeTitle => 'Enter the code';

  @override
  String accountEnterCodeBodyVerify(String email) {
    return 'We sent a 6-digit code to $email. Your trail is safe on this device in the meantime.';
  }

  @override
  String accountEnterCodeBodyReset(String email) {
    return 'We sent a 6-digit code to $email to reset your password.';
  }

  @override
  String get accountVerifyButton => 'Verify';

  @override
  String get accountVerifyingLoading => 'Verifying...';

  @override
  String accountResendCodeCountdown(String time) {
    return 'Resend code in $time';
  }

  @override
  String get accountResendCodeButton => 'Resend code';

  @override
  String get accountEnterCodeSpamHint =>
      'Can\'t find it? Check your spam folder.';

  @override
  String get accountSetNewPasswordEyebrow => 'Reset password';

  @override
  String get accountSetNewPasswordTitle => 'Set a new password';

  @override
  String accountSetNewPasswordBody(String email) {
    return 'Choose a new password for $email and you\'re back on your trail.';
  }

  @override
  String get accountNewPasswordLabel => 'New password';

  @override
  String get accountSavePasswordButton => 'Save password';

  @override
  String get accountSavingPasswordLoading => 'Saving...';

  @override
  String get accountKeepWhichTrailEyebrow => 'One last step';

  @override
  String get accountKeepWhichTrailTitle => 'Keep which trail?';

  @override
  String get accountKeepWhichTrailBody =>
      'This device and this account both have a trail. Keep one, the other is replaced. Nothing merges.';

  @override
  String get accountThisDeviceLabel => 'This device';

  @override
  String get accountThisAccountLabel => 'This account';

  @override
  String accountStonesLastClimbDateTime(num count, String dateTime) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stones',
      one: '1 stone',
    );
    return '$_temp0 · last climb $dateTime';
  }

  @override
  String get accountNoActivityYet => 'No activity yet';

  @override
  String accountConsequenceKeepDevice(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stones',
      one: '1 stone',
    );
    return 'Keeping this device replaces the account\'s $_temp0 everywhere. This can\'t be undone.';
  }

  @override
  String accountConsequenceKeepAccount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stones',
      one: '1 stone',
    );
    return 'Using this account replaces this device\'s $_temp0. This can\'t be undone.';
  }

  @override
  String get accountKeepDeviceButton => 'Keep this device\'s trail';

  @override
  String get accountKeepAccountButton => 'Keep this account\'s trail';

  @override
  String get accountApplyingLoading => 'Applying...';

  @override
  String get accountSignedInTitle => 'Signed in';

  @override
  String get accountTrailBackedUpLabel => 'Your trail is backed up.';

  @override
  String get accountSignOutButton => 'Sign out';

  @override
  String get accountSignOutConfirmTitle => 'Sign out?';

  @override
  String get accountSignOutConfirmBody =>
      'Your trail stays on this device. Sign back in anytime to sync it to your account again.';

  @override
  String get accountEmailInUseError => 'That email is already in use.';

  @override
  String get accountSignInInsteadLink => 'Sign in instead?';

  @override
  String get accountPasswordRequirements =>
      'Use at least 8 characters, with an uppercase letter, a lowercase letter, and a number.';

  @override
  String get accountRuleMinLength => 'At least 8 characters';

  @override
  String get accountRuleUppercase => 'An uppercase letter';

  @override
  String get accountRuleLowercase => 'A lowercase letter';

  @override
  String get accountRuleDigit => 'A number';

  @override
  String get accountSamePasswordError =>
      'Your new password must be different from your current password.';

  @override
  String get accountInvalidCodeError =>
      'That code didn\'t match. Check it and try again.';

  @override
  String get accountInvalidCredentialsError => 'Incorrect email or password.';

  @override
  String get accountRateLimitedError =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get accountUnknownError => 'Something went wrong. Please try again.';

  @override
  String get accountOfflineBannerCreate =>
      'You\'re offline. Connect to create your account.';

  @override
  String get accountOfflineBannerGeneric =>
      'You\'re offline. Try again once you\'re connected.';
}
