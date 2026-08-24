import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'widget_snapshot.dart';

/// Contract for saving widget snapshots and updating Android / iOS home screen
/// widgets.
abstract interface class WidgetUpdater {
  /// Writes [snapshot] to native widget storage and requests a native widget redraw.
  Future<void> updateSnapshot(WidgetSnapshot snapshot);

  /// Stream of URIs triggered by widget click actions while the app is running.
  Stream<Uri?> get widgetClicks;

  /// Retrieves the URI that launched the app from a widget, if any.
  Future<Uri?> initiallyLaunchedUri();
}

/// Real implementation of [WidgetUpdater] backed by `package:home_widget`.
class HomeWidgetUpdater implements WidgetUpdater {
  const HomeWidgetUpdater();

  static const String glanceWidgetName = 'CairnGlanceWidgetProvider';
  static const String glanceQualifiedName =
      'com.thnorty.cairn.CairnGlanceWidgetProvider';

  static const String nextHabitWidgetName = 'CairnNextHabitWidgetProvider';
  static const String nextHabitQualifiedName =
      'com.thnorty.cairn.CairnNextHabitWidgetProvider';

  @override
  Future<void> updateSnapshot(WidgetSnapshot snapshot) async {
    try {
      final data = snapshot.toWidgetData();
      for (final entry in data.entries) {
        final val = entry.value;
        if (val is int) {
          await HomeWidget.saveWidgetData<int>(entry.key, val);
        } else if (val is bool) {
          await HomeWidget.saveWidgetData<bool>(entry.key, val);
        } else if (val is String) {
          await HomeWidget.saveWidgetData<String>(entry.key, val);
        }
      }

      await HomeWidget.updateWidget(
        name: glanceWidgetName,
        qualifiedAndroidName: glanceQualifiedName,
      );

      await HomeWidget.updateWidget(
        name: nextHabitWidgetName,
        qualifiedAndroidName: nextHabitQualifiedName,
      );
    } catch (e, st) {
      debugPrint('HomeWidgetUpdater.updateSnapshot error: $e\n$st');
    }
  }

  @override
  Stream<Uri?> get widgetClicks => HomeWidget.widgetClicked;

  @override
  Future<Uri?> initiallyLaunchedUri() =>
      HomeWidget.initiallyLaunchedFromHomeWidget();
}

/// Inert [WidgetUpdater] used in tests and unsupported platforms.
class UnconfiguredWidgetUpdater implements WidgetUpdater {
  const UnconfiguredWidgetUpdater();

  @override
  Future<void> updateSnapshot(WidgetSnapshot snapshot) async {}

  @override
  Stream<Uri?> get widgetClicks => const Stream.empty();

  @override
  Future<Uri?> initiallyLaunchedUri() async => null;
}

/// In-memory fake for automated testing of widget state generation.
class FakeWidgetUpdater implements WidgetUpdater {
  FakeWidgetUpdater({Uri? initialUri}) : _initialUri = initialUri;

  final Uri? _initialUri;
  final List<WidgetSnapshot> snapshots = [];
  final StreamController<Uri?> _clickController =
      StreamController<Uri?>.broadcast();

  WidgetSnapshot? get latestSnapshot =>
      snapshots.isNotEmpty ? snapshots.last : null;

  void emitClick(Uri uri) {
    _clickController.add(uri);
  }

  @override
  Future<void> updateSnapshot(WidgetSnapshot snapshot) async {
    snapshots.add(snapshot);
  }

  @override
  Stream<Uri?> get widgetClicks => _clickController.stream;

  @override
  Future<Uri?> initiallyLaunchedUri() async => _initialUri;

  void dispose() {
    _clickController.close();
  }
}

/// Provider for the active [WidgetUpdater].
final widgetUpdaterProvider = Provider<WidgetUpdater>((ref) {
  // Use real HomeWidgetUpdater on Android / iOS devices.
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    return const HomeWidgetUpdater();
  }
  return const UnconfiguredWidgetUpdater();
});
