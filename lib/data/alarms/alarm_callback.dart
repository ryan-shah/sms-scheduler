import 'dart:ui';

import 'package:flutter/widgets.dart';

/// Entry point run by android_alarm_manager_plus in its background isolate.
///
/// Stub for now; sms-4mv.7 wires the SpikeRunner in here.
@pragma('vm:entry-point')
Future<void> alarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  debugPrint('alarmCallback fired');
}
