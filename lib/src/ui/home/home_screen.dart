import 'package:flutter/material.dart'
    show Colors, MaterialPageRoute, Scaffold, ScaffoldMessenger, SnackBar, Text;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/date_number_formatting.dart';
import '../../providers.dart';
import '../../repo/completion_repository.dart';
import '../../services/home_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../new_habit/new_habit_screen.dart';
import '../proof/camera_capture_screen.dart';
import '../proof/proof_outcome_routing.dart';
import '../widgets/buttons.dart';
import '../widgets/plus_glyph.dart';
import '../widgets/wordmark_glyph.dart';
import 'empty_today_view.dart';
import 'home_occurrence_card.dart';

/// Opens `NewHabitScreen` on top of the current route. Shared by both of
/// Home's "New habit" entry points (the header pill and the Empty Today
/// CTA) so they navigate identically.
void _openNewHabitScreen(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => const NewHabitScreen(),
  ));
}

/// The Today/Home screen (`Cairn Home.dc.html` / `Cairn Empty Today.dc.html`):
/// the app's default tab, showing every occurrence scheduled today across
/// active tasks, or the empty-state illustration when there are no tasks at
/// all yet.
///
/// All data comes from [homeSnapshotProvider], which stays live (see
/// [HomeService.watchToday]'s doc comment): a completion recorded elsewhere,
/// or a pending proof resolving in the background, updates this screen with
/// no manual refresh.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onOpenDebug});

  /// TEMPORARY: see [AppShell]'s doc comment. Wired onto this screen's own
  /// wordmark text so the Phase 1 debug screen stays reachable now that
  /// Today no longer shows [AppShell]'s shared placeholder header.
  final VoidCallback? onOpenDebug;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Keys ("taskId#slot") of cards whose "Prove it" is currently mid-flight,
  /// so a double-tap can't open the camera/gallery picker twice for the same
  /// occurrence while the first attempt is still running.
  final Set<String> _provingKeys = {};

  /// Tapping "Prove it" always runs [CompletionRepository.precheckProof]
  /// *first*, so a doomed attempt (daily cap, attempts exhausted, or any of
  /// the other guard-chain rejections) never opens the camera - see this
  /// run's spec ("the state machine") and `proof_outcome_routing.dart`'s doc
  /// comment. Only a clear precheck (`null`) opens [CameraCaptureScreen];
  /// everything from there on (capture, verify, and routing to the outcome
  /// screens) happens on that screen, not here.
  Future<void> _handleProveIt(HomeOccurrenceCard card) async {
    final key = '${card.taskId}#${card.slot}';
    if (_provingKeys.contains(key)) return;
    setState(() => _provingKeys.add(key));

    try {
      final clock = ref.read(clockProvider);
      final today = clock.today();
      final completionRepo = ref.read(completionRepositoryProvider);
      final rejection = await completionRepo.precheckProof(
        taskId: card.taskId,
        occurrenceDate: today,
        slot: card.slot,
      );
      if (!mounted) return;

      if (rejection == null) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => CameraCaptureScreen(
            taskId: card.taskId,
            taskTitle: card.taskTitle,
            occurrenceDate: today,
            slot: card.slot,
          ),
        ));
        return;
      }

      // Daily-cap/attempts-exhausted precheck rejections route to the exact
      // same outcome screens a post-submit rejection would (shared with
      // CameraCaptureScreen via routeToProofOutcome, so both paths agree);
      // the remaining rejection types have no dedicated screen by design
      // (they're not reachable from a correctly-behaving UI) and fall back
      // to a minimal snackbar below.
      final handled = await routeToProofOutcome(
        context,
        ref,
        result: rejection,
        taskId: card.taskId,
        taskTitle: card.taskTitle,
        occurrenceDate: today,
        slot: card.slot,
      );
      if (!handled && mounted) {
        _showUnreachableRejection(rejection);
      }
    } finally {
      if (mounted) setState(() => _provingKeys.remove(key));
    }
  }

  /// Minimal fallback for the handful of rejections
  /// [routeToProofOutcome] deliberately builds no screen for (back-fill,
  /// not-scheduled, task-not-found, already-completed): none of these are
  /// reachable from a correctly-behaving UI (precheckProof already blocked
  /// the tap that could cause them), so this stays a plain, untranslated
  /// safety net rather than polished product copy - the same scope decision
  /// the Phase 1 debug screen already makes for these exact rejection types.
  void _showUnreachableRejection(CompleteOccurrenceResult result) {
    final message = switch (result) {
      CompletionRejectedBackfill() => 'Cannot complete a past date',
      CompletionRejectedNotScheduled() => 'Not scheduled for this slot today',
      CompletionRejectedTaskNotFound() => 'Task not found',
      CompletionRejectedAlreadyCompleted() => 'Already completed',
      _ => 'Something went wrong',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final today = ref.watch(clockProvider).today();
    final displayName =
        ref.watch(userDisplayNameProvider) ?? l10n.fallbackDisplayName;
    final snapshotAsync = ref.watch(homeSnapshotProvider);

    // This screen gets dropped into AppShell's `IndexedStack` (which already
    // sits under its own `Material(type: MaterialType.transparency)`
    // ancestor), but must also render correctly standalone - a widget test
    // or the screenshot harness pumping just `HomeScreen` under a bare
    // `MaterialApp` - so it supplies its own. A bare `Material.transparency`
    // wrapper (the pattern `CardSurface`/`StatusChip`/the button family use)
    // would be enough for text/ink inheritance alone, but `_showProofOutcome`
    // needs a real `Scaffold` ancestor to show its placeholder snackbar
    // (`ScaffoldMessenger.showSnackBar` asserts one exists to present into,
    // even though `ScaffoldMessenger.of` itself is satisfied by MaterialApp's
    // implicit root messenger), so this uses a transparent `Scaffold`
    // instead: `backgroundColor: Colors.transparent` so it doesn't paint
    // over `ScreenBackground`'s parchment gradient/washes/contour beneath it,
    // and its own body already sits under a proper `Material` ancestor, so
    // no separate wrapper is needed on top.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        // 24/8 horizontal/top inset, matching the standardized top-left
        // header position shared by every tab screen (Home/Trail/Stats/
        // Profile) and the VerificationHeader family - this run's spec.
        padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BrandRow(onOpenDebug: widget.onOpenDebug, displayName: displayName),
            const SizedBox(height: 22),
            Text(
              formatWeekdayMonthDayHeader(today, locale),
              style: AppTextStyles.sectionLabel,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.goodMorningGreeting(displayName),
              style: AppTextStyles.greeting,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: snapshotAsync.when(
                data: (snapshot) => snapshot.activeTaskCount == 0
                    ? EmptyTodayView(onNewHabit: () => _openNewHabitScreen(context))
                    : _PopulatedBody(
                        snapshot: snapshot,
                        l10n: l10n,
                        provingKeys: _provingKeys,
                        onProveIt: _handleProveIt,
                      ),
                // The stream's first emission is effectively synchronous
                // (see HomeService.watchToday's doc comment), so there's no
                // meaningful loading UI to design here; an empty box avoids
                // a one-frame flash of anything else.
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => Center(child: Text('$error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopulatedBody extends StatelessWidget {
  const _PopulatedBody({
    required this.snapshot,
    required this.l10n,
    required this.provingKeys,
    required this.onProveIt,
  });

  final HomeSnapshot snapshot;
  final AppLocalizations l10n;
  final Set<String> provingKeys;
  final void Function(HomeOccurrenceCard card) onProveIt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.tasksDoneCount(snapshot.doneCount, snapshot.totalCount),
              style: AppTextStyles.body,
            ),
            const SizedBox(width: 16),
            const _SummaryDot(),
            const SizedBox(width: 16),
            Text(
              l10n.stonesThisWeek(snapshot.stonesThisWeek),
              style: AppTextStyles.body,
            ),
          ],
        ),
        const SizedBox(height: 26),
        Text(l10n.todaySectionLabel, style: AppTextStyles.sectionLabel),
        const SizedBox(height: 14),
        Expanded(
          child: snapshot.cards.isEmpty
              ? const SizedBox.shrink()
              : ListView.separated(
                  padding: const EdgeInsetsDirectional.only(bottom: 16),
                  itemCount: snapshot.cards.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final card = snapshot.cards[index];
                    final busy = provingKeys.contains('${card.taskId}#${card.slot}');
                    return HomeOccurrenceCardView(
                      key: ValueKey('${card.taskId}#${card.slot}'),
                      card: card,
                      onProveIt: busy ? () {} : () => onProveIt(card),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// The decorative bullet between "N of M done" and "N stones this week"
/// (`width:4px;height:4px;border-radius:50%;background:#c4bbaa`).
class _SummaryDot extends StatelessWidget {
  const _SummaryDot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 4,
      height: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFFC4BBAA),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.onOpenDebug, required this.displayName});

  final VoidCallback? onOpenDebug;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          // TEMPORARY: see HomeScreen's doc comment on [onOpenDebug].
          onLongPress: onOpenDebug,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WordmarkGlyph(),
              const SizedBox(width: 10),
              Text(l10n.appTitle, style: AppTextStyles.wordmark),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TintedPillButton(
              label: l10n.newHabitButton,
              onPressed: () => _openNewHabitScreen(context),
              icon: const PlusGlyph(color: AppColors.terracottaChipText),
            ),
            const SizedBox(width: 10),
            _AvatarCircle(initial: displayName.isEmpty ? '?' : displayName[0].toUpperCase()),
          ],
        ),
      ],
    );
  }
}

/// The circular avatar in the brand row
/// (`linear-gradient(150deg,#c9c0b0,#a99f8c)`), showing the first letter of
/// [initial] (the Home greeting's display name - see
/// `userDisplayNameProvider`'s doc comment on why there's no real profile
/// picture/name yet).
class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment(-0.5, -1),
          end: Alignment(0.5, 1),
          colors: [Color(0xFFC9C0B0), Color(0xFFA99F8C)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Work Sans',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFF453F35),
        ),
      ),
    );
  }
}
