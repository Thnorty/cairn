import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// App brand wordmark / MaterialApp title. A proper noun, included for completeness even though it is not expected to need translation.
  ///
  /// In en, this message translates to:
  /// **'Cairn'**
  String get appTitle;

  /// Bottom navigation tab label for the Today (home) screen.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// Bottom navigation tab label for the Trail screen.
  ///
  /// In en, this message translates to:
  /// **'Trail'**
  String get navTrail;

  /// Bottom navigation tab label for the Stats screen.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// Bottom navigation tab label for the profile (You) screen.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get navYou;

  /// Button label (paired with a leading '+' icon glyph, not part of this string) that opens the new-habit flow. Appears in the Home app bar and the Empty Today state.
  ///
  /// In en, this message translates to:
  /// **'New habit'**
  String get newHabitButton;

  /// Home screen greeting header. Only the morning variant appears in the design files seeded so far; afternoon/evening variants are not invented here and should be added as sibling keys once their canonical copy is confirmed.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String goodMorningGreeting(String name);

  /// Small all-caps section label above the day's occurrence list on the Home screen. Stored already uppercased rather than uppercased at runtime: Dart's String.toUpperCase() maps lowercase 'i' to 'I', but Turkish requires the dotted 'İ', so calling .toUpperCase() on a translated string would render incorrectly in Turkish. Do not "simplify" this back to toUpperCase().
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get todaySectionLabel;

  /// All-caps header label shown on every verification-flow screen (pending, result, failed, failed-no-retries). Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'VERIFICATION'**
  String get verificationHeaderLabel;

  /// Home screen summary of how many of today's occurrences are complete, e.g. '2 of 4 done'. The total is expressed as an ICU plural so languages whose grammar needs to change around the count (unlike English, where both categories read the same) have somewhere to do it.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total, plural, one{{total} done} other{{total} done}}'**
  String tasksDoneCount(int done, num total);

  /// Home screen weekly stone total, e.g. '17 stones this week'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 stone this week} other{{count} stones this week}}'**
  String stonesThisWeek(num count);

  /// Verified-status chip on a completed task card, e.g. 'Verified · 7:14 AM'. time is pre-formatted by the caller with an intl DateFormat, not built by hand.
  ///
  /// In en, this message translates to:
  /// **'Verified · {time}'**
  String verifiedAt(String time);

  /// Per-task progress line on a completed/verified task card, e.g. 'Cairn 2 · 9 stones · new stone placed'.
  ///
  /// In en, this message translates to:
  /// **'Cairn {cairnNumber} · {stoneCount, plural, one{1 stone} other{{stoneCount} stones}} · new stone placed'**
  String taskSummaryVerifiedNewStone(int cairnNumber, num stoneCount);

  /// Per-task progress line on a task card whose completion is still pending verification, e.g. 'Cairn 2 · 9 stones · 13 m when verified'. metres is pre-formatted by the caller (thousands separator) via NumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Cairn {cairnNumber} · {stoneCount, plural, one{1 stone} other{{stoneCount} stones}} · {metres} m when verified'**
  String taskSummaryAwaitingVerification(
    int cairnNumber,
    num stoneCount,
    String metres,
  );

  /// Per-task progress line on a not-yet-done task card, e.g. 'Due today · Cairn 1 · 4 stones'.
  ///
  /// In en, this message translates to:
  /// **'Due today · Cairn {cairnNumber} · {stoneCount, plural, one{1 stone} other{{stoneCount} stones}}'**
  String taskSummaryDueToday(int cairnNumber, num stoneCount);

  /// Per-task progress line on a card for a task scheduled later today, e.g. 'Cairn 1 · 6 stones'.
  ///
  /// In en, this message translates to:
  /// **'Cairn {cairnNumber} · {stoneCount, plural, one{1 stone} other{{stoneCount} stones}}'**
  String taskSummaryScheduled(int cairnNumber, num stoneCount);

  /// Per-task progress line shown after a rejected verification, e.g. 'Cairn 1 · 4 stones · no stone placed'.
  ///
  /// In en, this message translates to:
  /// **'Cairn {cairnNumber} · {stoneCount, plural, one{1 stone} other{{stoneCount} stones}} · no stone placed'**
  String taskSummaryNoStonePlaced(int cairnNumber, num stoneCount);

  /// Status chip shown on a task card and on the proof photo while a completion is pending verification.
  ///
  /// In en, this message translates to:
  /// **'Awaiting verification'**
  String get awaitingVerificationChip;

  /// Tiny caption drawn on the placeholder swatch that stands in for a task card's proof thumbnail when the completion has no local photo file to show (e.g. a Phase 1 debug-inserted completion). A real proof photo, when present, is shown instead of this placeholder.
  ///
  /// In en, this message translates to:
  /// **'proof'**
  String get proofThumbnailPlaceholderLabel;

  /// Stand-in for the Home screen greeting ('Good morning, {name}') and its avatar initial until Phase 4 adds real account display names (there is no profile/display-name system yet). Not a real user's name; deliberately generic rather than inventing a fake specific person.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get fallbackDisplayName;

  /// Button label on a due-now task card that opens the camera capture flow.
  ///
  /// In en, this message translates to:
  /// **'Prove it'**
  String get proveItButton;

  /// Status pill on a task card scheduled later today, e.g. 'Scheduled · 8:00 PM'. time is pre-formatted by the caller via intl.
  ///
  /// In en, this message translates to:
  /// **'Scheduled · {time}'**
  String scheduledAt(String time);

  /// Title shown on the Home screen when the user has no tasks yet.
  ///
  /// In en, this message translates to:
  /// **'Your first stone is waiting'**
  String get emptyTodayTitle;

  /// Body copy shown under emptyTodayTitle on the empty Home screen.
  ///
  /// In en, this message translates to:
  /// **'Add a habit, prove it once, and watch your cairn begin to rise.'**
  String get emptyTodayBody;

  /// Title on the verification screen when a completion was saved but verification hasn't run yet (e.g. offline).
  ///
  /// In en, this message translates to:
  /// **'Saved. We\'ll verify it soon.'**
  String get verifyPendingTitle;

  /// Subtitle line shared by the verification pending/result/failed screens, e.g. 'Meditate 10 min · 7:16 AM'. time is pre-formatted by the caller via intl.
  ///
  /// In en, this message translates to:
  /// **'{taskName} · {time}'**
  String taskNameAtTime(String taskName, String time);

  /// Bold lead-in sentence of the reassurance banner on the verification-pending screen when offline. Split out from the rest of the sentence (see offlineReassuranceBody) so the widget can render just this part bold, matching the design's <strong> span, rather than bolding a hardcoded prefix of one combined string.
  ///
  /// In en, this message translates to:
  /// **'No connection right now.'**
  String get offlineReassuranceLead;

  /// Regular-weight remainder of the reassurance banner on the verification-pending screen, following offlineReassuranceLead. The design's em dash (U+2014) was replaced with ' - ' per this project's house style (CLAUDE.md bans that character).
  ///
  /// In en, this message translates to:
  /// **'Your proof is saved on this device - we\'ll verify it automatically the moment you\'re back online.'**
  String get offlineReassuranceBody;

  /// Label in the streak-safe info chip on the verification-pending screen.
  ///
  /// In en, this message translates to:
  /// **'Streak safe'**
  String get streakSafeLabel;

  /// Second line of the streak-safe info chip on the verification-pending screen.
  ///
  /// In en, this message translates to:
  /// **'counts today'**
  String get streakSafeSubtext;

  /// First line of the held-metres info chip on the verification-pending screen, e.g. '13 m held'. metres is pre-formatted by the caller via NumberFormat.
  ///
  /// In en, this message translates to:
  /// **'{metres} m held'**
  String heldMetresLabel(String metres);

  /// Second line of the held-metres info chip on the verification-pending screen.
  ///
  /// In en, this message translates to:
  /// **'lands on verify'**
  String get landsOnVerifyLabel;

  /// Footer button on the verification-pending screen.
  ///
  /// In en, this message translates to:
  /// **'Back to Today'**
  String get backToTodayButton;

  /// Title on the verification-result screen when the proof was accepted.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifiedTitle;

  /// Static bold lead-in preceding the verifier's freeform reason text on an accepted verification-result screen. The reason text itself is server-generated (Gemini's explanation) and is not part of this string catalogue.
  ///
  /// In en, this message translates to:
  /// **'Looks good.'**
  String get verifyReasonPositiveLead;

  /// Footer button on the verification-result screen (accepted case).
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneButton;

  /// All-caps header label on the Cairn Complete celebration screen (Cairn Verify Result - Cairn Complete.dc.html), shown after a verified proof caps a per-task cairn (its 10th live stone). Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel/verificationHeaderLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'CAIRN COMPLETE'**
  String get cairnCompleteHeaderLabel;

  /// Headline on the Cairn Complete screen, e.g. 'Cairn 6 complete'. cairnNumber is the just-capped cairn's own index (CompletionRepository.currentCairnFor's index, re-read after the capping stone was recorded).
  ///
  /// In en, this message translates to:
  /// **'Cairn {cairnNumber} complete'**
  String cairnCompleteHeadline(int cairnNumber);

  /// Static subline under the Cairn Complete headline. 'Ten' is deliberately static copy, not derived from PointsService.cairnCapStones - there is no design for a non-10 cap count.
  ///
  /// In en, this message translates to:
  /// **'Ten stones stacked and sealed.'**
  String get cairnCompleteSubline;

  /// The bonus-metres pill's own bold figure on the Cairn Complete screen, e.g. '+25 m'. metres is pre-formatted by the caller via NumberFormat (the value itself comes from PointsService.cairnCapBonus, never hardcoded).
  ///
  /// In en, this message translates to:
  /// **'+{metres} m'**
  String cairnCompleteBonusAmount(String metres);

  /// Trailing label beside the bold figure in the Cairn Complete screen's bonus pill, e.g. '+25 m cairn bonus'.
  ///
  /// In en, this message translates to:
  /// **'cairn bonus'**
  String get cairnCompleteBonusLabel;

  /// Plain lead clause of the Cairn Complete screen's teaching card, immediately preceding the bold cairnCompleteTeachingNext clause in the same paragraph.
  ///
  /// In en, this message translates to:
  /// **'Every 10 stones caps a cairn and earns a bonus.'**
  String get cairnCompleteTeachingLead;

  /// Bold trailing clause of the Cairn Complete screen's teaching card, following cairnCompleteTeachingLead. nextCairnNumber is the just-capped cairn's index + 1.
  ///
  /// In en, this message translates to:
  /// **'Cairn {nextCairnNumber} starts with your next stone.'**
  String cairnCompleteTeachingNext(int nextCairnNumber);

  /// Title on the verification-result screen when the proof was rejected (with or without retries remaining).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t verify'**
  String get couldntVerifyTitle;

  /// Status chip on the proof photo on a rejected verification screen.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get notVerifiedChip;

  /// Primary footer button on the verification-failed screen when retries remain.
  ///
  /// In en, this message translates to:
  /// **'Retake photo'**
  String get retakePhotoButton;

  /// Caption under the retake-photo button showing remaining attempts for this task today.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 try left today} other{{count} tries left today}}'**
  String triesLeftToday(num count);

  /// Secondary footer button that dismisses the verification-failed screen.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// Bold lead-in sentence on the verification-failed screen once the per-task daily attempt cap is reached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used all {maxAttempts} attempts for this task today.'**
  String allAttemptsUsedLead(int maxAttempts);

  /// Detail sentence following allAttemptsUsedLead on the verification-failed (no retries) screen, as shown in the canonical design. This is captured verbatim from the design and may need to become dynamic per rejection reason once Phase 2b/3 wire up the real verifier.
  ///
  /// In en, this message translates to:
  /// **'The last photo looked like a screenshot rather than a live capture. Try again tomorrow with a photo of the page directly.'**
  String get allAttemptsUsedDetail;

  /// Disabled footer button on the verification-failed screen once retries are exhausted for the day.
  ///
  /// In en, this message translates to:
  /// **'Try again tomorrow'**
  String get tryAgainTomorrowButton;

  /// Caption under the disabled tryAgainTomorrowButton.
  ///
  /// In en, this message translates to:
  /// **'Attempts reset at midnight'**
  String get attemptsResetMidnight;

  /// Title on the daily-limit screen shown once the daily successful-proof cap is reached.
  ///
  /// In en, this message translates to:
  /// **'That\'s today\'s five'**
  String get dailyLimitTitle;

  /// Body copy on the daily-limit screen. The design's em dash (U+2014) was replaced with ' - ' per this project's house style (CLAUDE.md bans that character). Apostrophes are left as plain literal characters: this project's l10n.yaml does not set use-escaping, so gen_l10n treats ' as literal text even inside a plural construct rather than as ICU quoting syntax.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used all {count, plural, one{1 free AI proof} other{{count} free AI proofs}} for today. This stone is ready - it\'ll settle onto your cairn as soon as your proofs reset.'**
  String dailyLimitBody(num count);

  /// Caption pill on the daily-limit screen. Reused verbatim (identical literal English text and meaning) as the lead clause of the Stats screen's daily-proofs card caption, 'Resets at midnight · Go unlimited', rather than a duplicate key.
  ///
  /// In en, this message translates to:
  /// **'Resets at midnight'**
  String get resetsAtMidnight;

  /// Primary footer button on the daily-limit screen (premium upsell). Reused verbatim as the tappable Premium-upsell link on the Stats screen's daily-proofs card caption, 'Resets at midnight · Go unlimited', rather than a duplicate key.
  ///
  /// In en, this message translates to:
  /// **'Go unlimited'**
  String get goUnlimitedButton;

  /// Secondary footer button on the daily-limit screen.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get maybeLaterButton;

  /// All-caps label above the task name in the camera capture viewfinder overlay. Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'PROVING'**
  String get provingLabel;

  /// Camera capture screen control: opens the photo gallery picker instead of the live camera.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryButton;

  /// Camera capture screen control: switches between front and rear camera.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get flipCameraButton;

  /// Title shown while a captured photo is being sent for verification.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get verifyingTitle;

  /// Subtitle shown while a captured photo is being sent for verification.
  ///
  /// In en, this message translates to:
  /// **'Checking your proof for “{taskName}”'**
  String verifyingSubtitle(String taskName);

  /// All-caps header label on the Camera Unavailable screen (Cairn Camera Unavailable.dc.html's header row). Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel/verificationHeaderLabel; do not uppercase at runtime. Distinct from proveItButton ('Prove it'), which is a button label stored in mixed case for a different context.
  ///
  /// In en, this message translates to:
  /// **'PROVE IT'**
  String get proveItHeaderLabel;

  /// Title on the Verify Too Old screen (Cairn Verify Too Old.dc.html), shown for a proof photo rejected for being outside the recency window.
  ///
  /// In en, this message translates to:
  /// **'This photo is too old'**
  String get verifyTooOldTitle;

  /// Subtitle on the Verify Too Old screen showing the task name and the photo's own capture time, e.g. 'Read 20 pages · taken 7:15 AM'. Distinct from taskNameAtTime (which has no 'taken' wording and is used for the completion/rejection event time on the other verification screens): this screen specifically calls out that the time shown is when the PHOTO was taken, per the canonical design. time is pre-formatted by the caller via intl.
  ///
  /// In en, this message translates to:
  /// **'{taskName} · taken {time}'**
  String taskNameTakenAt(String taskName, String time);

  /// Age badge overlaid on the proof photo on the Verify Too Old screen, e.g. '17 min old'. Deliberately identical one/other text (English doesn't inflect 'min'), same pattern as tasksDoneCount, so a language whose grammar needs to change around the count has somewhere to do it.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{{minutes} min old} other{{minutes} min old}}'**
  String stalePhotoAgeBadge(num minutes);

  /// Bold lead-in sentence of the reassurance banner on the Verify Too Old screen.
  ///
  /// In en, this message translates to:
  /// **'Proof has to be taken in the moment.'**
  String get stalePhotoReassuranceLead;

  /// Regular-weight remainder of the reassurance banner on the Verify Too Old screen, following stalePhotoReassuranceLead. minutes is ProofPolicy.recencyWindow in whole minutes, sourced from policy rather than hardcoded.
  ///
  /// In en, this message translates to:
  /// **'Photos more than {minutes} minutes old can\'t be verified, so snap a fresh one right as you finish.'**
  String stalePhotoReassuranceBody(int minutes);

  /// Plain lead-in clause of the 'doesn't cost an attempt' info card on the Verify Too Old screen, immediately preceding the bold stalePhotoAttemptsCount clause. The canonical design's own copy is 'This didn't use a try [em dash, U+2014] you still have {n} left today.'; CLAUDE.md bans that character, so the em dash is replaced here with a period and the sentence continues ('This didn't use a try. You still have...') - the wording is unchanged, only the punctuation. Do not restore the em dash.
  ///
  /// In en, this message translates to:
  /// **'This didn\'t use a try. You still have'**
  String get stalePhotoAttemptsIntro;

  /// Bold clause of the 'doesn't cost an attempt' info card on the Verify Too Old screen, following stalePhotoAttemptsIntro, e.g. 'This didn't use a try. You still have 3 left today.' count is the task's full remaining attempts today (attemptsPerTaskPerDay - attemptsUsedToday), unaffected by this rejection since a stale photo never burns an attempt.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 left today} other{{count} left today}}'**
  String stalePhotoAttemptsCount(num count);

  /// Primary footer button on the Verify Too Old screen. Distinct wording from retakePhotoButton ('Retake photo') on the Verify Failed screen, per the canonical design.
  ///
  /// In en, this message translates to:
  /// **'Take a new photo'**
  String get takeNewPhotoButton;

  /// Title on the Camera Unavailable screen (Cairn Camera Unavailable.dc.html), shown when the live camera can't be started at all.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get cameraUnavailableTitle;

  /// Plain lead clause of the Camera Unavailable screen's body copy, immediately preceding the bold task name, e.g. 'Cairn couldn't open your camera. You can prove **Read 20 pages** with a photo from your gallery instead.' Split into lead/task-name/trail fragments (the task name is interpolated as its own bold TextSpan by the widget, not part of any ARB string) to reproduce the design's <strong> span around the task name - the same rationale as ReasonBanner's leadText/bodyText split elsewhere in this app.
  ///
  /// In en, this message translates to:
  /// **'Cairn couldn\'t open your camera. You can prove'**
  String get cameraUnavailableBodyLead;

  /// Plain trailing clause of the Camera Unavailable screen's body copy, following the bold task name - see cameraUnavailableBodyLead.
  ///
  /// In en, this message translates to:
  /// **'with a photo from your gallery instead.'**
  String get cameraUnavailableBodyTrail;

  /// All-caps section label above the recent-photos quick-pick grid on the Camera Unavailable screen. Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'RECENT PHOTOS'**
  String get recentPhotosLabel;

  /// Accessibility label read by screen readers for each tappable thumbnail in the Camera Unavailable screen's recent-photos grid (the grid itself has no per-photo visible caption).
  ///
  /// In en, this message translates to:
  /// **'Recent photo'**
  String get recentPhotoThumbnailLabel;

  /// Plain lead clause of the Camera Unavailable screen's Settings hint banner, immediately preceding the bold settingsHintEmphasis clause.
  ///
  /// In en, this message translates to:
  /// **'To use the camera, allow Cairn camera access in'**
  String get settingsHintLead;

  /// Bold middle clause of the Camera Unavailable screen's Settings hint banner, between settingsHintLead and settingsHintTrail, matching the design's own <strong> span in the middle of the sentence. This is the Android system Settings path to this app's permissions screen (Settings > Apps > Cairn > Permissions), where camera access is actually granted.
  ///
  /// In en, this message translates to:
  /// **'Settings › Apps › Cairn › Permissions'**
  String get settingsHintEmphasis;

  /// Plain trailing clause of the Camera Unavailable screen's Settings hint banner, immediately following settingsHintEmphasis. The leading period is deliberate: it closes the sentence right after the bold span, matching the design's own punctuation placement.
  ///
  /// In en, this message translates to:
  /// **'. Gallery proofs still need a recent, in-the-moment photo.'**
  String get settingsHintTrail;

  /// Button label that opens the photo gallery picker: the Camera Unavailable screen's primary footer action, and also its own fallback body button shown in place of the recent-photos grid when the photo library can't be read or has no photos.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGalleryButton;

  /// Secondary footer button on the Camera Unavailable screen that opens the OS app-settings screen so the user can grant camera permission.
  ///
  /// In en, this message translates to:
  /// **'Open camera settings'**
  String get openCameraSettingsButton;

  /// Header title on the New Habit screen (Cairn New Habit.dc.html and its Once/Monthly variants). Distinct from newHabitButton ('New habit'), which is a button label paired with a '+' icon in a different context (Home's app bar / Empty Today CTA) - same pattern as proveItButton vs proveItHeaderLabel elsewhere in this catalogue, kept separate in case a translation ever needs to phrase a screen title differently from a button that opens it.
  ///
  /// In en, this message translates to:
  /// **'New habit'**
  String get newHabitScreenTitle;

  /// Section label above the habit-title input on the New Habit screen. The source file is mixed-case with a CSS text-transform:uppercase; stored already uppercased here for the same Turkish dotted-i reason as todaySectionLabel - do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'WHAT ARE YOU PROVING?'**
  String get whatAreYouProvingLabel;

  /// Section label above the recurrence-type selector on the New Habit screen. Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'HOW OFTEN?'**
  String get howOftenLabel;

  /// Recurrence-type chip label on the New Habit screen: a one-off habit due on a single date.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get recurrenceOnceLabel;

  /// Recurrence-type chip label on the New Habit screen: a habit scheduled every day.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurrenceDailyLabel;

  /// Recurrence-type chip label on the New Habit screen: a habit scheduled on chosen days of the week.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurrenceWeeklyLabel;

  /// Recurrence-type chip label on the New Habit screen: a habit scheduled monthly, either by day-of-month or by nth weekday.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get recurrenceMonthlyLabel;

  /// Label above the day-of-week picker in the Weekly recurrence panel on the New Habit screen.
  ///
  /// In en, this message translates to:
  /// **'On these days'**
  String get onTheseDaysLabel;

  /// Label above the 1-31 day grid in the Monthly (day-of-month mode) recurrence panel on the New Habit screen.
  ///
  /// In en, this message translates to:
  /// **'Day of the month'**
  String get dayOfTheMonthLabel;

  /// Info note under the day-of-month grid on the New Habit screen, describing the hand-rolled clamping generator's behaviour (day = min(monthDay, lastDayOfMonth)) in user-facing terms; the generator itself is not reimplemented here, only its behaviour surfaced.
  ///
  /// In en, this message translates to:
  /// **'Months without this day will use the last day of the month.'**
  String get monthlyClampHelpText;

  /// Label above the 1st/2nd/3rd/4th/Last ordinal chip row in the Monthly (nth-weekday mode) recurrence panel on the New Habit screen.
  ///
  /// In en, this message translates to:
  /// **'Which week'**
  String get whichWeekLabel;

  /// Label above the day-of-week row in the Monthly (nth-weekday mode) recurrence panel on the New Habit screen.
  ///
  /// In en, this message translates to:
  /// **'Which day'**
  String get whichDayLabel;

  /// Left segment of the Monthly mode toggle, summarizing the currently chosen day-of-month, e.g. 'On the 31st'. day is pre-formatted by the caller as an English ordinal (e.g. '31st') - see monthly_ordinal.dart's englishOrdinal, which is deliberately English-only (intl has no public ordinal-number API and this app currently ships a single locale).
  ///
  /// In en, this message translates to:
  /// **'On the {day}'**
  String monthlyDayToggleLabel(String day);

  /// Right segment of the Monthly mode toggle, summarizing the currently chosen nth-weekday, e.g. 'On the 3rd Friday'. Both nth and weekday are pre-formatted by the caller (nth via englishOrdinal or monthlyWeekLastLabel for month_nth = -1; weekday via the date_number_formatting.dart weekdayFullName intl helper).
  ///
  /// In en, this message translates to:
  /// **'On the {nth} {weekday}'**
  String monthlyNthWeekdayToggleLabel(String nth, String weekday);

  /// Ordinal chip label for month_nth = -1 (the last occurrence of the chosen weekday in the month), and the nth value substituted into monthlyNthWeekdayToggleLabel in that same case.
  ///
  /// In en, this message translates to:
  /// **'Last'**
  String get monthlyWeekLastLabel;

  /// Label above the date-picker row in the Once recurrence panel on the New Habit screen.
  ///
  /// In en, this message translates to:
  /// **'On this date'**
  String get onThisDateLabel;

  /// Section label above the due-times editor for the Daily/Weekly/Monthly recurrence variants of the New Habit screen (plural: more than one time slot is expected to be common). Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime. Distinct from timeOfDayLabel (singular), used by the Once variant.
  ///
  /// In en, this message translates to:
  /// **'TIMES OF DAY'**
  String get timesOfDayLabel;

  /// Section label above the due-times editor for the Once recurrence variant of the New Habit screen (singular: capped at a single optional reminder time). Stored already uppercased for the same reason as timesOfDayLabel.
  ///
  /// In en, this message translates to:
  /// **'TIME OF DAY'**
  String get timeOfDayLabel;

  /// Helper copy under timesOfDayLabel on the Daily/Weekly/Monthly variants of the New Habit screen. The design's em dash (U+2014) was replaced with ' - ' per this project's house style (CLAUDE.md bans that character).
  ///
  /// In en, this message translates to:
  /// **'Each time is one proof - two times means a twice-a-day habit.'**
  String get timesOfDayHelpText;

  /// Helper copy under timeOfDayLabel on the Once variant of the New Habit screen. The design's em dash (U+2014) was replaced with ' - ' per this project's house style (CLAUDE.md bans that character).
  ///
  /// In en, this message translates to:
  /// **'Optional - a reminder to prove it on the day.'**
  String get onceTimeHelpText;

  /// Dashed-outline affordance that appends a new due-time slot on the New Habit screen. Hidden once the Once variant already has its one allowed slot.
  ///
  /// In en, this message translates to:
  /// **'Add a time'**
  String get addTimeButton;

  /// Primary footer button on the New Habit screen that submits the form via TaskRepository.createTask.
  ///
  /// In en, this message translates to:
  /// **'Create habit'**
  String get createHabitButton;

  /// Primary footer button on the Photo Review screen (Cairn Photo Review.dc.html), shown after a photo is captured/picked and before it is ever submitted for verification. Accepts the photo and proceeds to submit it.
  ///
  /// In en, this message translates to:
  /// **'Use this photo'**
  String get usePhotoButton;

  /// Secondary footer button on the Photo Review screen for a just-shot camera photo: discards the capture and returns to the live camera. Distinct from retakePhotoButton ('Retake photo'), the Verify Failed screen's wording for reopening the camera after a rejection - this screen's own canonical design says just 'Retake'.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retakeButton;

  /// Secondary footer button on the Photo Review screen for a gallery-picked photo: reopens the gallery picker so the user can pick a different photo. This is the gallery-path equivalent of retakeButton ('Retake'), shown instead when the reviewed photo came from the gallery rather than the live camera; the canonical design only shows the camera variant ('Retake'), so this wording was chosen to fill the same slot for a picked (rather than shot) photo.
  ///
  /// In en, this message translates to:
  /// **'Choose another'**
  String get chooseAnotherPhotoButton;

  /// Prompt pill on the Photo Review screen, above the accept/retake actions, asking the user to check the photo before submitting it for verification.
  ///
  /// In en, this message translates to:
  /// **'Does this show your proof clearly?'**
  String get photoReviewPrompt;

  /// Small all-caps section label above the 'You' title on the Profile screen (Cairn Profile.dc.html). Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get profileHeaderLabel;

  /// All-caps label on the Profile screen's rank hero card, above the current rank tier name. Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'CURRENT RANK'**
  String get profileCurrentRankLabel;

  /// Profile rank hero's total-altitude line, e.g. '840 m gained'. metres is pre-formatted by the caller via NumberFormat (formatMetresNumber).
  ///
  /// In en, this message translates to:
  /// **'{metres} m gained'**
  String profileMetresGainedLabel(String metres);

  /// Profile rank hero's withheld-metres line, shown only while CompletionRepository.pendingAltitude() > 0, e.g. '+13 m awaiting verification'. metres is pre-formatted by the caller via NumberFormat.
  ///
  /// In en, this message translates to:
  /// **'+{metres} m awaiting verification'**
  String profilePendingMetresLabel(String metres);

  /// Profile rank hero's progress-row trailing label, e.g. '260 m to Crag'. metres is pre-formatted by the caller via NumberFormat; tier is the next RankTier's own label (domain vocabulary, not translated - see profile_screen.dart's doc comment).
  ///
  /// In en, this message translates to:
  /// **'{metres} m to {tier}'**
  String profileMetresToNextTier(String metres, String tier);

  /// Marks the user's current tier row in the Profile rank ladder.
  ///
  /// In en, this message translates to:
  /// **'You\'re here'**
  String get profileYoureHereLabel;

  /// Trailing label on the rank-ladder row for the tier immediately after the user's current one, e.g. '1,100 m · next'. metres is pre-formatted by the caller via NumberFormat.
  ///
  /// In en, this message translates to:
  /// **'{metres} m · next'**
  String profileNextTierMetres(String metres);

  /// Trailing label on a Profile rank-ladder row for any tier that isn't the user's current one or the very next one, e.g. '2,400 m'. metres is pre-formatted by the caller via NumberFormat.
  ///
  /// In en, this message translates to:
  /// **'{metres} m'**
  String profileTierMetres(String metres);

  /// Title of the Profile screen's account-status row, shown while there is no upgraded account (Phase 4).
  ///
  /// In en, this message translates to:
  /// **'Climbing anonymously'**
  String get profileClimbingAnonymouslyTitle;

  /// Subtitle of the Profile screen's account-status row.
  ///
  /// In en, this message translates to:
  /// **'Create an account so your trail is never lost.'**
  String get profileCreateAccountBody;

  /// Action label on the Profile screen's account-status row. Phase 4 wires this to the real email/password upgrade flow; for now it is a no-op-for-now (see profileComingSoonSnackbar).
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get profileCreateButton;

  /// Title of the Profile screen's Cairn Premium upsell row.
  ///
  /// In en, this message translates to:
  /// **'Cairn Premium'**
  String get profilePremiumTitle;

  /// Subtitle of the Profile screen's Cairn Premium upsell row.
  ///
  /// In en, this message translates to:
  /// **'Unlimited proofs, backup, deeper insights.'**
  String get profilePremiumSubtitle;

  /// Snackbar shown when tapping the Profile screen's 'Create' account action or its Cairn Premium row, both of which are out of scope for this phase (Phase 4 accounts, post-MVP Premium) and are deliberate no-ops-for-now rather than a fake/invented flow.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get profileComingSoonSnackbar;

  /// All-caps section label above the Profile screen's settings list. Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get profileSettingsSectionLabel;

  /// Row label in the Profile screen's settings list. A navigational placeholder for now - later phases wire a real destination.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileNotificationsRow;

  /// Row label in the Profile screen's settings list. A navigational placeholder for now - later phases wire a real destination.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get profilePrivacyRow;

  /// Row label in the Profile screen's settings list. A navigational placeholder for now - later phases wire a real destination. Reused verbatim as the Premium screen's own footer 'Restore purchase' link (identical text/meaning), rather than a duplicate key.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get profileRestorePurchaseRow;

  /// Small all-caps eyebrow label above the selected task's title on the Trail screen (Cairn Trail.dc.html), e.g. 'TRAIL OF' above 'Read 20 pages'. Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'TRAIL OF'**
  String get trailHeaderEyebrow;

  /// Bare metres line under the tier name in the Trail screen's per-task rank pill, e.g. '840 m'. Distinct from profileMetresGainedLabel ('840 m gained'): the Trail rank pill's canonical design shows just the bare number. metres is pre-formatted by the caller via NumberFormat (formatMetresNumber).
  ///
  /// In en, this message translates to:
  /// **'{metres} m'**
  String trailRankMetresLabel(String metres);

  /// All-caps badge shown above the task's currently-growing cairn on the Trail screen. Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'GROWING NOW'**
  String get trailGrowingNowBadge;

  /// Caption under the growing cairn on the Trail screen, e.g. 'Cairn 6 · 4 stones'. Same pattern as taskSummaryScheduled on the Home screen.
  ///
  /// In en, this message translates to:
  /// **'Cairn {cairnNumber} · {stoneCount, plural, one{1 stone} other{{stoneCount} stones}}'**
  String trailCairnStoneCount(int cairnNumber, num stoneCount);

  /// Title line above a capped or broken cairn on the Trail screen, e.g. 'Cairn 5'.
  ///
  /// In en, this message translates to:
  /// **'Cairn {cairnNumber}'**
  String trailCairnLabel(int cairnNumber);

  /// Caption under a capped cairn on the Trail screen, e.g. '14 stones · capped'.
  ///
  /// In en, this message translates to:
  /// **'{stoneCount, plural, one{1 stone} other{{stoneCount} stones}} · capped'**
  String trailCappedCaption(num stoneCount);

  /// Caption under a broken cairn on the Trail screen, e.g. 'broken · 5 stones'.
  ///
  /// In en, this message translates to:
  /// **'broken · {stoneCount, plural, one{1 stone} other{{stoneCount} stones}}'**
  String trailBrokenCaption(num stoneCount);

  /// Caption under the first cairn (index 1) on the Trail screen, replacing that cairn's usual status caption, e.g. 'The trailhead · Apr 2'. date is pre-formatted by the caller via formatShortMonthDay.
  ///
  /// In en, this message translates to:
  /// **'The trailhead · {date}'**
  String trailTrailheadCaption(String date);

  /// All-caps marker below the trailhead cairn at the very bottom of the Trail screen's scrollable history. Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'WHERE YOU STARTED'**
  String get trailWhereYouStartedLabel;

  /// Body copy shown in place of the winding trail when the selected task has active tasks overall but this particular task has zero completions yet (its cairn history is empty). Not part of the canonical Cairn Trail.dc.html design (which has no such example) - this exact wording was specified as the state's copy since no static mockup covers it.
  ///
  /// In en, this message translates to:
  /// **'Your first stone starts the trail.'**
  String get trailEmptyTrailBody;

  /// Accessible (semantics) label for the small circular '?' info button on the Trail screen's header that opens the How Cairns Work explainer sheet. No visible text of its own - an icon-only affordance, same reasoning as newHabitButton's reuse as the '+' chip's semantic label.
  ///
  /// In en, this message translates to:
  /// **'How cairns work'**
  String get howCairnsWorkInfoButtonLabel;

  /// All-caps header label on the How Cairns Work explainer sheet (Cairn How Cairns Work.dc.html). Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel/verificationHeaderLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'HOW CAIRNS WORK'**
  String get howCairnsWorkHeaderLabel;

  /// Title on the How Cairns Work explainer sheet.
  ///
  /// In en, this message translates to:
  /// **'Every stone builds a cairn'**
  String get howCairnsWorkTitle;

  /// Subhead under the How Cairns Work explainer sheet's title.
  ///
  /// In en, this message translates to:
  /// **'A cairn is a stack of stones that marks a trail. Yours grows one proof at a time.'**
  String get howCairnsWorkSubhead;

  /// Label under the 'growing' mini-cairn in the How Cairns Work explainer sheet's three-state legend card.
  ///
  /// In en, this message translates to:
  /// **'Growing'**
  String get howCairnsWorkLegendGrowing;

  /// Label under the 'capped' mini-cairn in the How Cairns Work explainer sheet's three-state legend card.
  ///
  /// In en, this message translates to:
  /// **'Capped'**
  String get howCairnsWorkLegendCapped;

  /// Label (paired with a small lightning glyph) under the 'broken' mini-cairn in the How Cairns Work explainer sheet's three-state legend card.
  ///
  /// In en, this message translates to:
  /// **'Broken'**
  String get howCairnsWorkLegendBroken;

  /// Title of the first explainer row on the How Cairns Work sheet.
  ///
  /// In en, this message translates to:
  /// **'One proof, one stone'**
  String get howCairnsWorkRow1Title;

  /// Body copy of the first explainer row on the How Cairns Work sheet.
  ///
  /// In en, this message translates to:
  /// **'Every verified photo places a stone on the cairn you are building now.'**
  String get howCairnsWorkRow1Body;

  /// Title of the second explainer row on the How Cairns Work sheet.
  ///
  /// In en, this message translates to:
  /// **'Ten stones cap a cairn'**
  String get howCairnsWorkRow2Title;

  /// Plain lead clause of the second explainer row's body, immediately preceding the bold howCairnsWorkRow2Bonus clause in the same sentence.
  ///
  /// In en, this message translates to:
  /// **'Fill a cairn to ten and it is sealed for good, with a'**
  String get howCairnsWorkRow2Lead;

  /// Bold middle clause of the second explainer row's body, between howCairnsWorkRow2Lead and howCairnsWorkRow2Trail, e.g. '+25 m'. bonus is pre-formatted by the caller via NumberFormat (the value comes from PointsService.cairnCapBonus, never hardcoded).
  ///
  /// In en, this message translates to:
  /// **'+{bonus} m'**
  String howCairnsWorkRow2Bonus(String bonus);

  /// Plain trailing clause of the second explainer row's body, immediately following howCairnsWorkRow2Bonus.
  ///
  /// In en, this message translates to:
  /// **'bonus. The next stone starts a new one.'**
  String get howCairnsWorkRow2Trail;

  /// Title of the third explainer row on the How Cairns Work sheet.
  ///
  /// In en, this message translates to:
  /// **'A missed day breaks it'**
  String get howCairnsWorkRow3Title;

  /// Body copy of the third explainer row on the How Cairns Work sheet.
  ///
  /// In en, this message translates to:
  /// **'Skip a scheduled day and the current cairn seals early as broken. A fresh one begins next time.'**
  String get howCairnsWorkRow3Body;

  /// Title of the fourth explainer row on the How Cairns Work sheet.
  ///
  /// In en, this message translates to:
  /// **'Stones lift your rank'**
  String get howCairnsWorkRow4Title;

  /// Body copy of the fourth explainer row on the How Cairns Work sheet.
  ///
  /// In en, this message translates to:
  /// **'Each stone earns metres, more on a streak, a perfect day, or a cap. Metres raise your rank, and rank never falls.'**
  String get howCairnsWorkRow4Body;

  /// Footer button on the How Cairns Work explainer sheet. Pops the sheet.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get howCairnsWorkGotItButton;

  /// Small all-caps eyebrow label above the 'Stats' title on the Stats screen (Cairn Stats.dc.html), e.g. 'YOUR GROUND' above 'Stats'. Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime. The screen's own title reuses navStats ('Stats') rather than a duplicate key, the same pattern profileHeaderLabel's screen reuses navYou.
  ///
  /// In en, this message translates to:
  /// **'YOUR GROUND'**
  String get statsHeaderEyebrow;

  /// Caption under the Stats screen's 'stones placed' top stat tile, e.g. '248' above 'Stones placed'.
  ///
  /// In en, this message translates to:
  /// **'Stones placed'**
  String get statsStonesPlacedLabel;

  /// Caption under the Stats screen's 'cairns built' top stat tile, e.g. '6' above 'Cairns built'. Counts only capped (fully finished, 10-stone) cairns across active tasks - a growing or broken cairn does not count as 'built'.
  ///
  /// In en, this message translates to:
  /// **'Cairns built'**
  String get statsCairnsBuiltLabel;

  /// Heading on the Stats screen's daily-proofs card.
  ///
  /// In en, this message translates to:
  /// **'Proofs used today'**
  String get statsProofsUsedTodayLabel;

  /// Trailing count on the Stats screen's daily-proofs card, e.g. '3 of 5'. The canonical design bolds just the 'used' number (matching Home's own 'N of M done' summary, tasksDoneCount), but is rendered here in one uniform style, the same simplification tasksDoneCount's own Home usage already makes.
  ///
  /// In en, this message translates to:
  /// **'{used} of {cap}'**
  String statsProofsUsedCount(int used, int cap);

  /// Heading on the Stats screen's weekly bar-chart card. The trailing 'N of M done' summary next to it reuses tasksDoneCount rather than a duplicate key: identical ICU shape, e.g. '19 of 21 done'.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get statsThisWeekLabel;

  /// All-caps section label above the Stats screen's list of active per-task streaks. Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'CURRENT STREAKS'**
  String get statsCurrentStreaksLabel;

  /// Trailing count on a Stats screen current-streak row, e.g. '9 days'.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{1 day} other{{days} days}}'**
  String statsStreakDaysCount(num days);

  /// Calm empty-state line shown in place of the current-streaks list when no active task has a live streak of at least one day. Not part of the canonical Cairn Stats.dc.html design (which has no such example) - this exact wording was specified as the state's copy since no static mockup covers it, the same scope note trailEmptyTrailBody's doc comment makes for its own screen.
  ///
  /// In en, this message translates to:
  /// **'No active streaks yet'**
  String get statsNoActiveStreaksLabel;

  /// Title of the Stats screen's locked 'Deeper insights' Premium upsell card. Reused verbatim (identical literal text and meaning) as the Premium screen's own 'Deeper insights' value-row title, rather than a duplicate key.
  ///
  /// In en, this message translates to:
  /// **'Deeper insights'**
  String get statsDeeperInsightsTitle;

  /// Subtitle of the Stats screen's locked 'Deeper insights' Premium upsell card. Reused verbatim as the Premium screen's own 'Deeper insights' value-row subtitle, rather than a duplicate key.
  ///
  /// In en, this message translates to:
  /// **'Consistency curves, best times of day, rank projections.'**
  String get statsDeeperInsightsSubtitle;

  /// All-caps badge on the Stats screen's locked 'Deeper insights' card. Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'PREMIUM'**
  String get statsPremiumBadge;

  /// Snackbar shown when tapping the Stats screen's 'Go unlimited' link or its 'Deeper insights' card, both Premium affordances that are out of scope for this phase (post-MVP Premium) and are deliberate no-ops-for-now rather than a fake/invented flow - same pattern as profileComingSoonSnackbar for the Profile screen's own Premium affordances.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get statsComingSoonSnackbar;

  /// All-caps eyebrow label above the headline on the Premium screen (Cairn Premium.dc.html), under its small 3-stone crest. Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'CAIRN PREMIUM'**
  String get premiumEyebrow;

  /// Headline on the Premium screen's crest. The canonical design hard-wraps this across two lines with a <br> at a fixed mockup width ('Keep every stone,' / 'on every peak'); reproduced here as one sentence and left to wrap naturally at whatever width the real device renders, rather than baking in a manual line break - the same treatment every other headline in this catalogue gets (e.g. emptyTodayTitle, dailyLimitTitle).
  ///
  /// In en, this message translates to:
  /// **'Keep every stone, on every peak'**
  String get premiumHeadline;

  /// Title of the first row in the Premium screen's value list.
  ///
  /// In en, this message translates to:
  /// **'Unlimited AI proofs'**
  String get premiumValueUnlimitedProofsTitle;

  /// Subtitle of the first row in the Premium screen's value list.
  ///
  /// In en, this message translates to:
  /// **'No daily cap. Prove as many habits as you keep.'**
  String get premiumValueUnlimitedProofsSubtitle;

  /// Title of the second row in the Premium screen's value list.
  ///
  /// In en, this message translates to:
  /// **'Cloud photo backup'**
  String get premiumValueCloudBackupTitle;

  /// Subtitle of the second row in the Premium screen's value list.
  ///
  /// In en, this message translates to:
  /// **'Every proof photo saved and restorable on any phone.'**
  String get premiumValueCloudBackupSubtitle;

  /// Title of the fourth row in the Premium screen's value list.
  ///
  /// In en, this message translates to:
  /// **'Home-screen widgets'**
  String get premiumValueWidgetsTitle;

  /// Subtitle of the fourth row in the Premium screen's value list.
  ///
  /// In en, this message translates to:
  /// **'Your cairn on your home screen. Tap to prove.'**
  String get premiumValueWidgetsSubtitle;

  /// Title of the fifth row in the Premium screen's value list.
  ///
  /// In en, this message translates to:
  /// **'Stone styles'**
  String get premiumValueStoneStylesTitle;

  /// Subtitle of the fifth row in the Premium screen's value list. The design's own copy uses an em dash (U+2014 between 'basalt' and 'make your cairn yours'); CLAUDE.md bans that character, so it is replaced here with a period, splitting the line into two short sentences rather than restoring the dash.
  ///
  /// In en, this message translates to:
  /// **'Slate, granite, basalt. Make your cairn yours.'**
  String get premiumValueStoneStylesSubtitle;

  /// Title of the Premium screen's Yearly plan card (selected by default).
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get premiumYearlyPlanTitle;

  /// Subtitle of the Premium screen's Yearly plan card.
  ///
  /// In en, this message translates to:
  /// **'\$27.99/yr · \$2.33/mo'**
  String get premiumYearlyPlanSubtitle;

  /// Trailing price figure on the Premium screen's Yearly plan card.
  ///
  /// In en, this message translates to:
  /// **'\$27.99'**
  String get premiumYearlyPlanPrice;

  /// Title of the Premium screen's Monthly plan card.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get premiumMonthlyPlanTitle;

  /// Subtitle of the Premium screen's Monthly plan card.
  ///
  /// In en, this message translates to:
  /// **'Billed every month'**
  String get premiumMonthlyPlanSubtitle;

  /// Trailing price figure on the Premium screen's Monthly plan card.
  ///
  /// In en, this message translates to:
  /// **'\$3.99'**
  String get premiumMonthlyPlanPrice;

  /// Ribbon badge on the Premium screen's Yearly plan card. Stored already uppercased for the same Turkish dotted-i reason as todaySectionLabel; do not uppercase at runtime.
  ///
  /// In en, this message translates to:
  /// **'BEST VALUE · SAVE 42%'**
  String get premiumBestValueRibbon;

  /// Primary footer button on the Premium screen. Premium is post-MVP with no billing/IAP integration yet, so this is a no-op-for-now that shows premiumComingSoonSnackbar rather than starting a real trial.
  ///
  /// In en, this message translates to:
  /// **'Start 7-day free trial'**
  String get premiumStartTrialButton;

  /// Caption under the Premium screen's primary trial button. Kept static (matching the Yearly default selection) rather than reflecting whichever plan card is currently selected - the canonical design shows only this one static line, and switching it to the Monthly price/cadence when that card is selected would be inventing copy the design doesn't have.
  ///
  /// In en, this message translates to:
  /// **'Then \$27.99/yr · cancel anytime'**
  String get premiumTrialSubtitle;

  /// Footer link on the Premium screen. A legal-destination placeholder for now (no Terms screen exists yet) - a later phase wires a real destination.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get premiumTermsLink;

  /// Footer link on the Premium screen. A legal-destination placeholder for now (no Privacy screen exists yet) - a later phase wires a real destination.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get premiumPrivacyLink;

  /// Snackbar shown when tapping the Premium screen's 'Start 7-day free trial' button, which is out of scope for this phase (no billing/IAP integration - Premium is presentational only) and is a deliberate no-op-for-now rather than a fake/invented purchase flow - same pattern as profileComingSoonSnackbar/statsComingSoonSnackbar for their own screens' Premium affordances.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get premiumComingSoonSnackbar;

  /// First line of the two-line headline on the first-launch onboarding welcome screen (Cairn Onboarding.dc.html).
  ///
  /// In en, this message translates to:
  /// **'Don\'t just check it off.'**
  String get onboardingWelcomeHeadlineLine1;

  /// Second, sage-coloured accent line of the onboarding welcome screen's headline, immediately following onboardingWelcomeHeadlineLine1.
  ///
  /// In en, this message translates to:
  /// **'Prove it.'**
  String get onboardingWelcomeHeadlineAccent;

  /// Subhead under the headline on the onboarding welcome screen. The design's em dash (U+2014) was replaced with ':' per this project's house style (CLAUDE.md bans that character).
  ///
  /// In en, this message translates to:
  /// **'Cairn turns real effort into something you can see grow: one verified stone at a time.'**
  String get onboardingWelcomeSubhead;

  /// One-line authored addition directly under onboardingWelcomeSubhead on the onboarding welcome screen, explaining the 'cairn' metaphor in plain terms for a first-time user. Deliberately does not mention the 10-stone cap, streaks, or bonus points - those are taught later, in context, not on this first screen.
  ///
  /// In en, this message translates to:
  /// **'A cairn is a small stack of stones that hikers build to mark a trail.'**
  String get onboardingWelcomeClarifier;

  /// Bold lead-in of the first of three step cards on the onboarding welcome screen, immediately followed by onboardingStep1Body in the same line.
  ///
  /// In en, this message translates to:
  /// **'Do the thing.'**
  String get onboardingStep1Title;

  /// Muted remainder of the first onboarding welcome step card's line, following onboardingStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Your habit, in the real world.'**
  String get onboardingStep1Body;

  /// Bold lead-in of the second of three step cards on the onboarding welcome screen, immediately followed by onboardingStep2Body in the same line.
  ///
  /// In en, this message translates to:
  /// **'Snap a photo.'**
  String get onboardingStep2Title;

  /// Muted remainder of the second onboarding welcome step card's line, following onboardingStep2Title.
  ///
  /// In en, this message translates to:
  /// **'A quick proof of what you did.'**
  String get onboardingStep2Body;

  /// Bold lead-in of the third of three step cards on the onboarding welcome screen (the sage-tinted card with the check-circle icon), immediately followed by onboardingStep3Body in the same line.
  ///
  /// In en, this message translates to:
  /// **'AI verifies.'**
  String get onboardingStep3Title;

  /// Muted remainder of the third onboarding welcome step card's line, following onboardingStep3Title.
  ///
  /// In en, this message translates to:
  /// **'A stone settles on your cairn.'**
  String get onboardingStep3Body;

  /// Primary footer button on the onboarding welcome screen; advances to the onboarding verification screen.
  ///
  /// In en, this message translates to:
  /// **'Start climbing'**
  String get onboardingStartClimbingButton;

  /// Ghost footer button on the onboarding welcome screen. Signing in to an existing account is a Phase 4 concern (accounts/sync) and is out of scope here, so this is a deliberate no-op-for-now that shows onboardingSignInComingSoonSnackbar.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get onboardingAlreadyHaveAccountButton;

  /// Snackbar shown when tapping onboardingAlreadyHaveAccountButton, same no-op-for-now pattern as profileComingSoonSnackbar/premiumComingSoonSnackbar for their own screens' out-of-scope affordances.
  ///
  /// In en, this message translates to:
  /// **'Signing in to an existing account is coming soon.'**
  String get onboardingSignInComingSoonSnackbar;

  /// Title on the onboarding verification screen (Cairn Onboarding Verification.dc.html), the second and final screen of the first-launch onboarding flow.
  ///
  /// In en, this message translates to:
  /// **'How verification works'**
  String get onboardingVerificationTitle;

  /// Subhead under the title on the onboarding verification screen. The design's em dash (U+2014) was replaced with '.' per this project's house style (CLAUDE.md bans that character).
  ///
  /// In en, this message translates to:
  /// **'A quick check keeps every stone honest. Here\'s exactly what happens to your photo.'**
  String get onboardingVerificationSubhead;

  /// Title of the first of three point cards on the onboarding verification screen.
  ///
  /// In en, this message translates to:
  /// **'Sent only to be checked'**
  String get onboardingPoint1Title;

  /// Body copy of the first point card on the onboarding verification screen. The design's em dash (U+2014) was replaced with ',' per this project's house style (CLAUDE.md bans that character).
  ///
  /// In en, this message translates to:
  /// **'Your photo is sent to an AI (Google Gemini) to confirm it matches your habit, nothing else.'**
  String get onboardingPoint1Body;

  /// Title of the second of three point cards on the onboarding verification screen.
  ///
  /// In en, this message translates to:
  /// **'Never stored in the cloud'**
  String get onboardingPoint2Title;

  /// Body copy of the second point card on the onboarding verification screen.
  ///
  /// In en, this message translates to:
  /// **'We don\'t keep your photos on our servers. They\'re checked, then discarded.'**
  String get onboardingPoint2Body;

  /// Title of the third of three point cards on the onboarding verification screen.
  ///
  /// In en, this message translates to:
  /// **'Your archive lives on your phone'**
  String get onboardingPoint3Title;

  /// Body copy of the third point card on the onboarding verification screen.
  ///
  /// In en, this message translates to:
  /// **'Proof photos are saved on your device. Cloud backup is optional with Premium.'**
  String get onboardingPoint3Body;

  /// Bold lead-in clause of the onboarding verification screen's footer permission-primer card, immediately preceding onboardingCameraPermissionBody in the same line.
  ///
  /// In en, this message translates to:
  /// **'Cairn needs your camera'**
  String get onboardingCameraPermissionLead;

  /// Plain remainder of the onboarding verification screen's footer permission-primer card's line, following onboardingCameraPermissionLead.
  ///
  /// In en, this message translates to:
  /// **'to capture proof of each habit.'**
  String get onboardingCameraPermissionBody;

  /// Primary button on the onboarding verification screen's footer permission-primer card. Fires the real OS camera-permission prompt (via CameraPermissionRequester), then marks onboarding complete and enters the app regardless of the prompt's outcome - see the onboarding flow's own doc comment.
  ///
  /// In en, this message translates to:
  /// **'Allow camera'**
  String get onboardingAllowCameraButton;

  /// Text link below the footer permission-primer card on the onboarding verification screen. No privacy page exists yet in this app, so this is a deliberate no-op-for-now that shows onboardingPrivacyComingSoonSnackbar, same pattern as premiumTermsLink/premiumPrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'Learn more about privacy'**
  String get onboardingLearnMorePrivacyLink;

  /// Snackbar shown when tapping onboardingLearnMorePrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'A privacy details page is coming soon.'**
  String get onboardingPrivacyComingSoonSnackbar;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
