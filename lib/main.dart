import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/debug/debug_screen.dart';

void main() {
  runApp(const ProviderScope(child: CairnApp()));
}

class CairnApp extends StatelessWidget {
  const CairnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cairn (Phase 1 debug)',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const DebugScreen(),
    );
  }
}
