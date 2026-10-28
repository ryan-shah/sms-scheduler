import 'package:sms_scheduler/data/alarms/alarm_scheduler.dart';

/// Records calls; [armedAt] is the current armed time (null when unarmed).
class FakeAlarmScheduler implements AlarmScheduler {
  /// Every id passed through; always [kDispatchAlarmId].
  final List<int> ids = [];
  final List<DateTime> armCalls = [];
  int cancelCalls = 0;
  DateTime? armedAt;

  @override
  Future<void> armAt(DateTime whenUtc) async {
    ids.add(kDispatchAlarmId);
    armCalls.add(whenUtc);
    armedAt = whenUtc;
  }

  @override
  Future<void> cancel() async {
    ids.add(kDispatchAlarmId);
    cancelCalls++;
    armedAt = null;
  }
}
