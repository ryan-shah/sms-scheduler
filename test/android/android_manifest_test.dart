import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _amp = 'dev.fluttercommunity.plus.androidalarmmanager';

/// Returns the full text of the first element `<tag ... android:name="name" ...>`
/// (the opening tag plus, for non-self-closing tags, everything to the close).
String? _element(String xml, String tag, String name) {
  final open = RegExp(
    '<$tag[\\s][^>]*android:name="${RegExp.escape(name)}"[^>]*>',
  );
  final m = open.firstMatch(xml);
  if (m == null) return null;
  if (m.group(0)!.endsWith('/>')) return m.group(0);
  final end = xml.indexOf('</$tag>', m.end);
  return xml.substring(m.start, end + tag.length + 3);
}

void main() {
  final xml = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  String perm(String n) {
    final e = _element(xml, 'uses-permission', 'android.permission.$n');
    expect(e, isNotNull, reason: 'missing uses-permission $n');
    return e!;
  }

  for (final n in [
    'SEND_SMS',
    'USE_EXACT_ALARM',
    'RECEIVE_BOOT_COMPLETED',
    'WAKE_LOCK',
    'POST_NOTIFICATIONS',
    'REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
  ]) {
    test('declares $n', () => perm(n));
  }

  test('SCHEDULE_EXACT_ALARM is capped at maxSdkVersion=32', () {
    expect(
      perm('SCHEDULE_EXACT_ALARM'),
      contains('android:maxSdkVersion="32"'),
    );
  });

  test('AlarmService requires BIND_JOB_SERVICE and is not exported', () {
    final e = _element(xml, 'service', '$_amp.AlarmService');
    expect(e, isNotNull);
    expect(
      e,
      contains('android:permission="android.permission.BIND_JOB_SERVICE"'),
    );
    expect(e, contains('android:exported="false"'));
  });

  test('AlarmBroadcastReceiver is declared and not exported', () {
    final e = _element(xml, 'receiver', '$_amp.AlarmBroadcastReceiver');
    expect(e, isNotNull);
    expect(e, contains('android:exported="false"'));
  });

  test(
    'RebootBroadcastReceiver is enabled, private, and hears BOOT_COMPLETED',
    () {
      final e = _element(xml, 'receiver', '$_amp.RebootBroadcastReceiver');
      expect(e, isNotNull);
      expect(e, contains('android:enabled="true"'));
      expect(e, contains('android:exported="false"'));
      expect(
        e,
        contains('<action android:name="android.intent.action.BOOT_COMPLETED"'),
      );
    },
  );

  test('no TIMEZONE_CHANGED/TIME_SET receiver yet (Phase 3)', () {
    expect(xml, isNot(contains('TIMEZONE_CHANGED')));
    expect(xml, isNot(contains('TIME_SET')));
  });
}
