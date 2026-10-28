import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('namespace and applicationId are com.rsh.smsscheduler', () {
    expect(gradle, contains('namespace = "com.rsh.smsscheduler"'));
    expect(gradle, contains('applicationId = "com.rsh.smsscheduler"'));
  });

  test('MainActivity lives in the matching package', () {
    final activity = File(
      'android/app/src/main/kotlin/com/rsh/smsscheduler/MainActivity.kt',
    );
    expect(activity.existsSync(), isTrue);
    expect(
      activity.readAsStringSync(),
      contains('package com.rsh.smsscheduler'),
    );
  });

  test('minSdk is 26', () {
    expect(gradle, contains('minSdk = 26'));
  });

  test('app label is "SMS Scheduler"', () {
    expect(manifest, contains('android:label="SMS Scheduler"'));
  });
}
