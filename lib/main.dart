import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/debug/debug_screen.dart';
import 'src/providers.dart';

void main() {
  runApp(const ProviderScope(child: CairnApp()));
}

/// App root. A [ConsumerWidget] so it can watch [proofRetryTriggerProvider]:
/// that's a lazy [Provider], so nothing constructs the pending-verification
/// retry trigger (and starts its lifecycle listener/connectivity
/// subscription) until something watches it. The app root is the one place
/// guaranteed to build for the whole lifetime of the running app.
///
/// Deliberately not wired into `test/widget_test.dart`: that test pumps
/// `MaterialApp(home: DebugScreen())` directly rather than [CairnApp], so
/// watching the provider here never touches that test and never drags
/// connectivity_plus's platform channel into it.
class CairnApp extends ConsumerWidget {
  const CairnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(proofRetryTriggerProvider);
    return MaterialApp(
      title: 'Cairn (Phase 1 debug)',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const DebugScreen(),
    );
  }
}
