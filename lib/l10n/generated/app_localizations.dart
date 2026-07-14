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

  /// Caption pill on the daily-limit screen.
  ///
  /// In en, this message translates to:
  /// **'Resets at midnight'**
  String get resetsAtMidnight;

  /// Primary footer button on the daily-limit screen (premium upsell).
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

  /// Reason banner text shown on the Verify Failed layout when a photo is rejected for being too old (its own capture timestamp fell outside the recency window), reused because there is no dedicated canonical design for this outcome (a noted design gap - see the phase-3 implementation report). Unlike a verifier rejection's reason, this is client-side policy copy, not server-generated text, and this rejection does not burn an attempt.
  ///
  /// In en, this message translates to:
  /// **'This photo looks too old to count as fresh proof. Try capturing it again right now.'**
  String get stalePhotoReason;

  /// Shown on the Camera Capture screen in place of the live preview when the device camera can't be started (no hardware, permission denied, or the plugin is unavailable), so the gallery path stays reachable instead of dead-ending on a broken viewfinder. Not part of any canonical design (a noted design gap - see the phase-3 implementation report).
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable. Choose a photo from your gallery instead.'**
  String get cameraUnavailableMessage;
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
