import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release build retains the runtime-resolved notification icon', () {
    final icon = File(
      'android/app/src/main/res/drawable/ic_stat_cairn.xml',
    );
    final keepFile = File('android/app/src/main/res/raw/keep.xml');
    final scheduler = File(
      'lib/src/notifications/local_notifications_scheduler.dart',
    );

    expect(icon.existsSync(), isTrue);
    expect(keepFile.existsSync(), isTrue);
    expect(
      keepFile.readAsStringSync(),
      contains('tools:keep="@drawable/ic_stat_cairn"'),
    );
    expect(
      scheduler.readAsStringSync(),
      contains("AndroidInitializationSettings('ic_stat_cairn')"),
    );
  });
}
