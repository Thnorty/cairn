import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads every font declared in the app's bundle (`pubspec.yaml`'s `fonts:`
/// section - Zilla Slab and Work Sans, see that file's own comment on why
/// they're bundled offline) into the test binding, so a widget test renders
/// real glyphs instead of `flutter_test`'s default Ahem placeholder boxes.
///
/// `flutter test` doesn't load bundled fonts by default (this is exactly
/// why golden/screenshot-style tests normally see boxes instead of text);
/// this reads `FontManifest.json` from the test asset bundle - present
/// because `flutter test` builds one from `pubspec.yaml`'s `fonts:`/`assets:`
/// declarations - and registers each listed font file under its family via
/// [FontLoader], the same technique used by community golden-test tooling
/// (e.g. `golden_toolkit`'s `loadAppFonts()`), reimplemented here rather than
/// adding that package as a dependency for one helper.
///
/// Call this once per test file (a `setUpAll` is the natural place) before
/// pumping anything whose text needs to render legibly in a screenshot.
Future<void> loadAppFonts() async {
  final manifestJson = await rootBundle.loadString('FontManifest.json');
  final fontManifest = jsonDecode(manifestJson) as List<dynamic>;

  for (final entry in fontManifest) {
    final map = entry as Map<String, dynamic>;
    final family = map['family'] as String;
    final fonts = map['fonts'] as List<dynamic>;

    final loader = FontLoader(family);
    for (final fontEntry in fonts) {
      final asset = (fontEntry as Map<String, dynamic>)['asset'] as String;
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}
