import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../domain/clock.dart';
import '../sms/sms_gateway.dart';
import '../spike/spike_runner.dart';
import '../spike/spike_store.dart';
import 'alarm_scheduler.dart';

/// Entry point run by android_alarm_manager_plus in its background isolate.
///
/// Builds a [SpikeRunner] from real implementations (no ProviderScope in the
/// background isolate) and never throws.
@pragma('vm:entry-point')
Future<void> alarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await SpikeRunner(
      store: SpikeStore(),
      gateway: const PluginSmsGateway(),
      alarms: const AndroidAlarmManagerScheduler(),
      clock: const SystemClock(),
    ).onAlarm();
  } on Object catch (e, st) {
    debugPrint('alarmCallback failed: $e\n$st');
  }
}
