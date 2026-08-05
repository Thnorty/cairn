import 'dart:async';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'clock.dart';
import 'config.dart';
import 'db/database.dart';
import 'models/proof_verdict.dart';
import 'models/stone_style.dart';
import 'premium/premium_service.dart';
import 'premium/revenuecat_premium_service.dart';
import 'premium/unconfigured_premium_service.dart';
import 'repo/completion_repository.dart';
import 'repo/settings_repository.dart';
import 'repo/task_repository.dart';
import 'services/account_service.dart';
import 'services/app_settings_opener.dart';
import 'services/auth_service.dart';
import 'services/camera_permission_requester.dart';
import 'services/camera_session.dart';
import 'services/home_service.dart';
import 'services/insights_service.dart';
import 'services/occurrence_generator.dart';
import 'services/photo_capture.dart';
import 'services/points_service.dart';
import 'services/profile_service.dart';
import 'services/proof_flow.dart';
import 'services/proof_retry_service.dart';
import 'services/proof_verifier.dart';
import 'services/recent_photo_library.dart';
import 'services/stats_service.dart';
import 'services/streak_service.dart';
import 'services/supabase_proof_verifier.dart';
import 'services/trail_service.dart';
import 'sync/supabase_sync_transport.dart';
import 'sync/sync_service.dart';
import 'sync/sync_transport.dart';
import 'sync/sync_trigger.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'cairn'));
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// Drives the root onboarding gate in `main.dart`: whether the first-launch
/// onboarding flow has already been completed. `ref.invalidate`d by
/// [OnboardingFlow] once its "Allow camera" step finishes, so the gate
/// rebuilds from [OnboardingFlow] into [AppShell] without any manual
/// navigation - see that widget's doc comment.
final onboardingCompleteProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).isOnboardingComplete(),
);

final occurrenceGeneratorProvider =
    Provider<OccurrenceGenerator>((ref) => const OccurrenceGenerator());

final streakServiceProvider = Provider<StreakService>(
  (ref) => StreakService(ref.watch(occurrenceGeneratorProvider)),
);

final pointsServiceProvider =
    Provider<PointsService>((ref) => const PointsService());

final proofPolicyProvider = Provider<ProofPolicy>((ref) {
  final isPremium = ref.watch(premiumStatusProvider);
  // Premium lifts the daily proof cap (the "Unlimited AI proofs" benefit);
  // free tier keeps the default cap of 5. All other policy knobs unchanged.
  return isPremium ? const ProofPolicy(dailyCap: null) : const ProofPolicy();
});

/// Debug affordance: lets the debug screen switch the verifier's behaviour
/// on a real device. `real` is the actual Supabase-backed verifier
/// ([SupabaseProofVerifier]), landed in WO-4; `pass`/`reject`/`offline`
/// stay as in-memory fakes so every branch of the pipeline (a clean pass, a
/// rejection with attempts remaining, an unreachable verifier going
/// pending) can still be exercised on a device without burning a real
/// Gemini call.
enum DebugVerifierMode { real, pass, reject, offline }

final debugVerifierModeProvider =
    StateProvider<DebugVerifierMode>((ref) => DebugVerifierMode.real);

const _debugPassVerdict = ProofVerdict(
  taskShown: true,
  confidence: 1.0,
  isScreenshotOrScreen: false,
  reason: 'Debug mode: pass',
);

const _debugRejectVerdict = ProofVerdict(
  taskShown: false,
  confidence: 0.0,
  isScreenshotOrScreen: false,
  reason: 'Debug mode: reject',
);

/// Real by default (see [DebugVerifierMode]); the debug screen's menu can
/// still switch to one of the fakes to exercise a specific branch on
/// demand. Only the `real` case ever touches the network (and only when
/// [ProofVerifier.verify] is actually called, not at construction time), so
/// building this provider is always safe, including under test.
final proofVerifierProvider = Provider<ProofVerifier>((ref) {
  final mode = ref.watch(debugVerifierModeProvider);
  switch (mode) {
    case DebugVerifierMode.real:
      return SupabaseProofVerifier();
    case DebugVerifierMode.pass:
      return FakeProofVerifier((_) => const VerdictReceived(_debugPassVerdict));
    case DebugVerifierMode.reject:
      return FakeProofVerifier((_) => const VerdictReceived(_debugRejectVerdict));
    case DebugVerifierMode.offline:
      return FakeProofVerifier((_) => const VerifierUnavailable('Debug mode: offline'));
  }
});

/// Thin wrapper around Supabase anonymous auth (WO-4). Never touches the
/// Supabase SDK at build time; see [SupabaseAuthService]'s doc comment.
final authServiceProvider = Provider<AuthService>((ref) => SupabaseAuthService());

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
    // ref.read, not ref.watch: the getter is only *called* at insert time,
    // so this deliberately creates no build-time dependency edge on
    // authServiceProvider (same rationale as proofRetryTriggerProvider's
    // factory below).
    currentUserId: () => ref.read(authServiceProvider).currentUserId,
  );
});

final completionRepositoryProvider = Provider<CompletionRepository>((ref) {
  return CompletionRepository(
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
    generator: ref.watch(occurrenceGeneratorProvider),
    streaks: ref.watch(streakServiceProvider),
    points: ref.watch(pointsServiceProvider),
    verifier: ref.watch(proofVerifierProvider),
    policy: ref.watch(proofPolicyProvider),
    currentUserId: () => ref.read(authServiceProvider).currentUserId,
  );
});

/// The user's *stored* display name, persisted locally in `AppSettings` via
/// [SettingsRepository.displayName]/[SettingsRepository.setDisplayName] -
/// see `Cairn Onboarding Name.dc.html`'s doc comment for the full rationale
/// (local is always the source of truth for rendering, independent of
/// whether an account exists). A plain [FutureProvider] +
/// manual-`ref.invalidate`-on-write, the exact same convention
/// [storedStoneStyleProvider] already uses for `AppSettings`-backed state:
/// every writer (the onboarding "Your name" step's Continue, its Profile
/// edit variant's Save, and the sign-in trail-adoption paths in
/// [AccountService]) must `ref.invalidate(storedDisplayNameProvider)`
/// afterward.
final storedDisplayNameProvider = FutureProvider<String?>((ref) {
  return ref.watch(settingsRepositoryProvider).displayName();
});

/// Display name for the Home greeting and its avatar initial: resolves
/// [storedDisplayNameProvider]'s current value, or null while that first
/// read is still in flight or once it resolves absent (no name set yet -
/// a stale existing install that finished onboarding before this feature
/// existed, per that screen's own "existing installs" decision). Callers
/// keep consuming this exactly as before this run's change (a plain
/// `String?`, `?? l10n.fallbackDisplayName` guarding the null case) - only
/// the resolution mechanism changed, from a hardcoded stub to
/// [storedDisplayNameProvider]'s live `AppSettings` value, mirroring how
/// [effectiveStoneStyleProvider] derives from [storedStoneStyleProvider].
final userDisplayNameProvider = Provider<String?>((ref) {
  return ref.watch(storedDisplayNameProvider).asData?.value;
});

final homeServiceProvider = Provider<HomeService>((ref) {
  return HomeService(
    ref.watch(databaseProvider),
    ref.watch(taskRepositoryProvider),
    ref.watch(completionRepositoryProvider),
    ref.watch(occurrenceGeneratorProvider),
    ref.watch(clockProvider),
  );
});

/// Drives the Home screen. Recomputes automatically on every relevant
/// database change (see [HomeService.watchToday]'s doc comment), so the
/// screen never needs a manual refresh.
final homeSnapshotProvider = StreamProvider<HomeSnapshot>((ref) {
  return ref.watch(homeServiceProvider).watchToday();
});

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(
    ref.watch(databaseProvider),
    ref.watch(completionRepositoryProvider),
    ref.watch(pointsServiceProvider),
  );
});

/// Drives the Profile ("You") screen. Recomputes automatically on every
/// relevant database change (see [ProfileService.watchProfile]'s doc
/// comment), so the screen never needs a manual refresh.
final profileSnapshotProvider = StreamProvider<ProfileSnapshot>((ref) {
  return ref.watch(profileServiceProvider).watchProfile();
});

final trailServiceProvider = Provider<TrailService>((ref) {
  return TrailService(
    ref.watch(databaseProvider),
    ref.watch(taskRepositoryProvider),
    ref.watch(completionRepositoryProvider),
    ref.watch(pointsServiceProvider),
    ref.watch(clockProvider),
  );
});

/// Which task's trail the Trail screen currently shows; null defaults to
/// the first task (by cairn number) - see [TrailService]'s doc comment on
/// effective selection. Tapping a habit-selector chip sets this.
final selectedTrailTaskIdProvider = StateProvider<String?>((ref) => null);

/// Drives the Trail screen. Recomputes automatically on every relevant
/// database change (see [TrailService.watchTrail]'s doc comment, the same
/// reactivity recipe as [homeSnapshotProvider]/[profileSnapshotProvider]),
/// and re-runs whenever [selectedTrailTaskIdProvider] changes.
final trailSnapshotProvider = StreamProvider<TrailSnapshot>((ref) {
  return ref.watch(trailServiceProvider).watchTrail(
        selectedTaskId: ref.watch(selectedTrailTaskIdProvider),
      );
});

final statsServiceProvider = Provider<StatsService>((ref) {
  return StatsService(
    ref.watch(databaseProvider),
    ref.watch(taskRepositoryProvider),
    ref.watch(completionRepositoryProvider),
    ref.watch(occurrenceGeneratorProvider),
    ref.watch(streakServiceProvider),
    ref.watch(clockProvider),
    policy: ref.watch(proofPolicyProvider),
  );
});

/// Drives the Stats screen. Recomputes automatically on every relevant
/// database change (see [StatsService.watchStats]'s doc comment, the same
/// reactivity recipe as [homeSnapshotProvider]/[profileSnapshotProvider]/
/// [trailSnapshotProvider]).
final statsSnapshotProvider = StreamProvider<StatsSnapshot>((ref) {
  return ref.watch(statsServiceProvider).watchStats();
});

/// Computes the Stats screen's "Deeper insights" figures (consistency, best
/// time of day, rank projection - see [InsightsService]'s own doc comment).
/// Deliberately NOT gated on [premiumStatusProvider] here: this service
/// computes unconditionally, and the later work order that builds the
/// "Deeper insights" UI on top of it applies the entitlement gate there.
final insightsServiceProvider = Provider<InsightsService>((ref) {
  return InsightsService(
    ref.watch(taskRepositoryProvider),
    ref.watch(completionRepositoryProvider),
    ref.watch(occurrenceGeneratorProvider),
    ref.watch(pointsServiceProvider),
    ref.watch(clockProvider),
  );
});

/// The Stats screen's "Deeper insights" figures, bundled for its premium
/// section: [InsightsService.consistency]/[InsightsService.bestTimeOfDay]/
/// [InsightsService.rankProjection] plus [isAtTopRank] - a minimal extra
/// signal computed here (via the same already-public
/// [CompletionRepository.totalAltitude]/[PointsService.rankFor] calls
/// [InsightsService.rankProjection] itself makes internally) rather than
/// added to [InsightsService], so the UI can tell apart the two reasons
/// [InsightsSnapshot.rankProjection] can be null: already at the top rank
/// (nothing to project) versus not enough recent pace yet - two different
/// empty-state messages, per `Cairn Stats - Deeper Insights.dc.html`'s own
/// work order.
typedef InsightsSnapshot = ({
  ConsistencySnapshot consistency,
  BestTimeOfDay bestTimeOfDay,
  RankProjection? rankProjection,
  bool isAtTopRank,
});

/// Drives the Stats screen's "Deeper insights" section. A plain
/// [FutureProvider] (InsightsService itself has no `watchX` stream method,
/// per its own doc comment - it computes unconditionally on request) that
/// re-executes whenever [statsSnapshotProvider] emits a new snapshot, which
/// already happens on every relevant tasks/completions change (see that
/// provider's own doc comment): watched here purely as a recompute trigger,
/// its own value is unused, so Deeper Insights never goes stale relative to
/// the rest of the Stats screen without InsightsService needing its own
/// separate watch/stream plumbing.
final insightsSnapshotProvider = FutureProvider<InsightsSnapshot>((ref) async {
  ref.watch(statsSnapshotProvider);
  final insights = ref.watch(insightsServiceProvider);

  final consistency = await insights.consistency();
  final bestTimeOfDay = await insights.bestTimeOfDay();
  final rankProjection = await insights.rankProjection();

  final totalAltitude = await ref.read(completionRepositoryProvider).totalAltitude();
  final isAtTopRank =
      ref.read(pointsServiceProvider).rankFor(totalAltitude).nextTier == null;

  return (
    consistency: consistency,
    bestTimeOfDay: bestTimeOfDay,
    rankProjection: rankProjection,
    isAtTopRank: isAtTopRank,
  );
});

// Photo-library metadata is tried first (its timestamp is harder to forge
// than in-file EXIF); EXIF is the fallback for cases where the library
// lookup can't resolve a match at all, e.g. Android 13+'s system Photo
// Picker handing the app a copy of the asset under a name the library
// lookup can't match (see ExifAssetTimeResolver's doc comment).
final assetTimeResolverProvider = Provider<AssetTimeResolver>(
  (ref) => const ChainedAssetTimeResolver([
    PhotoManagerAssetTimeResolver(),
    ExifAssetTimeResolver(),
  ]),
);

final photoCaptureProvider = Provider<PhotoCapture>((ref) {
  return ImagePickerPhotoCapture(
    ref.watch(clockProvider),
    ref.watch(assetTimeResolverProvider),
  );
});

final imageCompressorProvider =
    Provider<ImageCompressor>((ref) => const FlutterImageCompressor());

final proofPhotoStoreProvider =
    Provider<ProofPhotoStore>((ref) => FileProofPhotoStore());

final proofFlowServiceProvider = Provider<ProofFlowService>((ref) {
  return ProofFlowService(
    capture: ref.watch(photoCaptureProvider),
    compressor: ref.watch(imageCompressorProvider),
    store: ref.watch(proofPhotoStoreProvider),
    completionRepository: ref.watch(completionRepositoryProvider),
  );
});

/// Factory for a fresh [CameraSession] per `CameraCaptureScreen` visit,
/// rather than a single shared provider instance: a live camera resource is
/// strictly scoped to that screen's own lifetime (acquired in its
/// `initState`, released in its `dispose`), so a Riverpod singleton would
/// either leak the camera hardware handle after the screen closes or force
/// every later visit to reuse an already-disposed controller. A widget test
/// overrides this with a factory returning a `FakeCameraSession`, so no
/// widget test ever touches the real plugin's platform channel.
typedef CameraSessionFactory = CameraSession Function();

final cameraSessionFactoryProvider = Provider<CameraSessionFactory>(
  (ref) => PluginCameraSession.new,
);

/// Backs `Cairn Camera Unavailable.dc.html`'s "Recent photos" quick-pick
/// grid. A widget test overrides this with a fake, so no widget test ever
/// touches `photo_manager`'s platform channel for this path either.
final recentPhotoLibraryProvider = Provider<RecentPhotoLibrary>(
  (ref) => const PhotoManagerRecentPhotoLibrary(),
);

/// Backs the Camera Unavailable screen's "Open camera settings" button. A
/// widget test overrides this with a fake, so no widget test ever touches
/// `permission_handler`'s platform channel.
final appSettingsOpenerProvider = Provider<AppSettingsOpener>(
  (ref) => const PermissionHandlerAppSettingsOpener(),
);

/// Backs the onboarding verification screen's "Allow camera" button. A
/// widget test overrides this with a fake, so no widget test ever touches
/// `permission_handler`'s platform channel for this path either.
final cameraPermissionRequesterProvider = Provider<CameraPermissionRequester>(
  (ref) => const PermissionHandlerCameraPermissionRequester(),
);

final proofRetryServiceProvider = Provider<ProofRetryService>((ref) {
  final service = ProofRetryService(
    ref.watch(completionRepositoryProvider),
    ref.watch(proofPhotoStoreProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Wires [ProofRetryTrigger] into the app lifecycle. Built with a factory
/// (`() => ref.read(proofRetryServiceProvider)`) that resolves the current
/// [ProofRetryService] at call time rather than a watched, fixed instance,
/// so this provider has no dependency edge on [proofVerifierProvider] (or
/// anything else [proofRetryServiceProvider] depends on): it is built once,
/// for the life of the app, and its lifecycle listener/connectivity
/// subscription is started exactly once. Watching the service directly used
/// to rebuild this provider (and re-subscribe to connectivity_plus) every
/// time the verifier changed, which is exactly the bug this factory avoids.
/// Nothing constructs the trigger until something watches this provider, so
/// the app root must watch it once at startup.
final proofRetryTriggerProvider = Provider<ProofRetryTrigger>((ref) {
  final trigger = ProofRetryTrigger(() => ref.read(proofRetryServiceProvider));
  trigger.start();
  ref.onDispose(trigger.dispose);
  return trigger;
});

/// Kicks off anonymous sign-in (a no-op if a session already exists) and
/// then the one-time `user_id` backfill (WO-4), exactly once for the life
/// of the app. Built the same way as [proofRetryTriggerProvider]: resolves
/// [authServiceProvider] and the two repositories via `ref.read` inside the
/// async body rather than `ref.watch`, so this provider has no build-time
/// dependency edge on any of them and is never rebuilt by, say, a change to
/// the debug verifier mode. Nothing runs until something watches this
/// provider, so the app root must watch it once at startup.
///
/// Safe to (re)run on every launch without any separate "already ran"
/// flag: [AuthService.ensureSignedIn] is a no-op once a session exists, and
/// each repository's `backfillUserId` only touches rows still matching
/// `user_id IS NULL`, so it becomes a no-op too once every row has been
/// stamped once.
final authBootstrapProvider = Provider<void>((ref) {
  Future<void> run() async {
    final auth = ref.read(authServiceProvider);
    await auth.ensureSignedIn();
    final userId = auth.currentUserId;
    if (userId == null) return; // still offline/unauthenticated: nothing to backfill yet
    await ref.read(taskRepositoryProvider).backfillUserId(userId);
    await ref.read(completionRepositoryProvider).backfillUserId(userId);
    await ref.read(premiumServiceProvider).logIn(userId);
  }

  unawaited(run());
});

/// Seam for the Phase 4a delta-sync engine's remote side (see
/// `lib/src/sync/sync_transport.dart`). Points at the real, network-backed
/// [SupabaseSyncTransport] (Phase 4b) only when a live Supabase project is
/// configured; otherwise falls back to [UnconfiguredSyncTransport] so an
/// offline/unconfigured build - and every existing test that resolves
/// [SyncService] through the provider graph without overriding this - never
/// attempts a network call. Tests needing a working fake "server" instead
/// override this with `test/support/fake_sync_transport.dart`'s
/// `FakeSyncTransport`.
final syncTransportProvider = Provider<SyncTransport>((ref) {
  if (!AppConfig.isConfigured) return const UnconfiguredSyncTransport();
  return SupabaseSyncTransport();
});

/// The hand-rolled client delta-sync engine (Phase 4a), built from the local
/// database and [syncTransportProvider].
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(databaseProvider),
    ref.watch(syncTransportProvider),
  );
});

/// Wires [SyncTrigger] into the app lifecycle, the same lazy-factory pattern
/// as [proofRetryTriggerProvider]: resolves [syncServiceProvider] via
/// `ref.read` inside a factory rather than `ref.watch`, so this provider has
/// no build-time dependency edge on it (or on [authServiceProvider], read
/// the same way for the `isSignedIn` guard) and is built once, for the life
/// of the app, with its lifecycle listener/connectivity subscription started
/// exactly once. Nothing constructs the trigger until something watches this
/// provider, so the app root must watch it once at startup.
final syncTriggerProvider = Provider<SyncTrigger>((ref) {
  final trigger = SyncTrigger(
    () => ref.read(syncServiceProvider),
    isConfigured: () => AppConfig.isConfigured,
    isSignedIn: () => ref.read(authServiceProvider).currentUserId != null,
  );
  trigger.start();
  ref.onDispose(trigger.dispose);
  return trigger;
});

/// Whether the Phase 4b account-upgrade feature (create account / sign in /
/// reset password / sign out) is available at all: false when no live
/// Supabase project is configured. WO-B uses this to hide every entry point
/// (the Profile row's affordances) rather than showing a feature with
/// nothing to talk to.
final accountFeatureAvailableProvider =
    Provider<bool>((ref) => AppConfig.isConfigured);

/// Orchestrates the account-upgrade flows (see [AccountService]'s doc
/// comment) on top of the existing auth/sync/completions providers.
final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService(
    auth: ref.watch(authServiceProvider),
    sync: ref.watch(syncServiceProvider),
    completions: ref.watch(completionRepositoryProvider),
    tasks: ref.watch(taskRepositoryProvider),
    premium: ref.watch(premiumServiceProvider),
    settings: ref.watch(settingsRepositoryProvider),
  );
});

/// Reactive anonymous-vs-signed-in state for the Profile row. A plain,
/// invalidate-on-demand `FutureProvider` - the same pattern
/// [onboardingCompleteProvider] already uses - rather than a stream off the
/// SDK's own auth-state-change: WO-B's screens are expected to
/// `ref.invalidate(accountStateProvider)` immediately after any
/// [AccountService] call that can change it (sign in, create-account
/// completion, sign-out), the same way `OnboardingFlow` already invalidates
/// [onboardingCompleteProvider] after its own side effect rather than this
/// provider watching a stream to catch up on its own.
final accountStateProvider = FutureProvider<AccountState>((ref) async {
  final auth = ref.watch(authServiceProvider);
  return AccountState(isAnonymous: auth.isAnonymous, email: auth.email);
});

// -----------------------------------------------------------------------------
// Premium & Monetization (Phase 5)
// -----------------------------------------------------------------------------

/// Seam for subscription entitlement and purchasing (Phase 5).
///
/// Returns the real RevenueCat-backed service ([RevenueCatPremiumService]) when
/// [AppConfig.isPremiumConfigured], otherwise [UnconfiguredPremiumService]
/// (mirroring [syncTransportProvider]).
final premiumServiceProvider = Provider<PremiumService>((ref) {
  if (!AppConfig.isPremiumConfigured) return const UnconfiguredPremiumService();
  return RevenueCatPremiumService();
});

/// Drives the paywall's real store prices; null when offerings are unavailable
/// or billing is unconfigured.
final premiumOfferingProvider = FutureProvider<PremiumOffering?>((ref) async {
  return ref.watch(premiumServiceProvider).loadOfferings();
});

/// Internal stream provider tracking entitlement updates from [premiumServiceProvider].
final _premiumStatusStreamProvider = StreamProvider<bool>((ref) {
  return ref.watch(premiumServiceProvider).isPremiumStream;
});

/// Debug affordance (mirrors [debugVerifierModeProvider]): when non-null it
/// forces the premium status regardless of the real service, so entitlement
/// gates are testable on a real device with no billing backend.
final debugPremiumOverrideProvider = StateProvider<bool?>((ref) => null);

/// Single reactive source of truth for whether the user is currently entitled to
/// premium features. Consumed across the rest of the app.
final premiumStatusProvider = Provider<bool>((ref) {
  final override = ref.watch(debugPremiumOverrideProvider);
  if (override != null) return override;
  return ref.watch(_premiumStatusStreamProvider).asData?.value ?? false;
});

// -----------------------------------------------------------------------------
// Stone Styles (Phase 5)
// -----------------------------------------------------------------------------

/// The user's *stored* stone-style choice, persisted in `AppSettings` via
/// [SettingsRepository.stoneStyle]/[SettingsRepository.setStoneStyle] - see
/// [StoneStyle]'s own doc comment for why this is a distinct notion from
/// [effectiveStoneStyleProvider] below. A plain [FutureProvider] +
/// manual-`ref.invalidate`-on-write, the same convention
/// [onboardingCompleteProvider]/[accountStateProvider] already use for
/// AppSettings-backed state, rather than a live stream: the Stone Style
/// picker's Apply button calls
/// `ref.read(settingsRepositoryProvider).setStoneStyle(...)` then
/// `ref.invalidate(storedStoneStyleProvider)`, mirroring exactly how
/// `OnboardingFlow` commits `markOnboardingComplete()`.
///
/// Named distinctly from (not merged into) [effectiveStoneStyleProvider] so
/// the stored-vs-effective split the spec for this feature calls out stays
/// explicit in the code, not just in a comment: a single ambiguously-named
/// provider returning "the" style would immediately raise the question of
/// which of the two notions it means.
final storedStoneStyleProvider = FutureProvider<StoneStyle>((ref) {
  return ref.watch(settingsRepositoryProvider).stoneStyle();
});

/// The stone style that should actually be RENDERED wherever a themed
/// [CairnStack] is drawn: [storedStoneStyleProvider]'s value, unless the
/// user isn't currently entitled to premium, in which case this resolves to
/// [StoneStyle.river] regardless of what's stored. A lapsed subscriber's
/// premium pick stays in `AppSettings` untouched (see
/// [storedStoneStyleProvider]) so re-subscribing restores it exactly, but it
/// is never rendered while they're not entitled - see [StoneStyle]'s own doc
/// comment for the full rationale. This is the provider every screen that
/// draws the app's *current* cairn style should watch.
final effectiveStoneStyleProvider = Provider<StoneStyle>((ref) {
  final stored = ref.watch(storedStoneStyleProvider).asData?.value ?? StoneStyle.river;
  if (stored.requiresPremium && !ref.watch(premiumStatusProvider)) {
    return StoneStyle.river;
  }
  return stored;
});

