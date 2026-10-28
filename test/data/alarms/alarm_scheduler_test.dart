import 'package:flutter_test/flutter_test.dart';
import 'package:sms_scheduler/data/alarms/alarm_callback.dart';
import 'package:sms_scheduler/data/alarms/alarm_scheduler.dart';

import '../../fakes/fake_alarm_scheduler.dart';

class _RecordingApi implements AlarmManagerApi {
  Map<String, Object?>? oneShot;
  final cancelled = <int>[];

  @override
  Future<bool> oneShotAt(
    DateTime time,
    int id,
    Function callback, {
    required bool alarmClock,
    required bool allowWhileIdle,
    required bool exact,
    required bool wakeup,
    required bool rescheduleOnReboot,
  }) async {
    oneShot = {
      'time': time,
      'id': id,
      'callback': callback,
      'alarmClock': alarmClock,
      'allowWhileIdle': allowWhileIdle,
      'exact': exact,
      'wakeup': wakeup,
      'rescheduleOnReboot': rescheduleOnReboot,
    };
    return true;
  }

  @override
  Future<bool> cancel(int id) async {
    cancelled.add(id);
    return true;
  }
}

void main() {
  test('fake records armAt/cancel with the single id', () async {
    final f = FakeAlarmScheduler();
    final t = DateTime.utc(2026, 1, 2, 3);
    await f.armAt(t);
    expect(f.armedAt, t);
    expect(f.armCalls, [t]);
    await f.cancel();
    expect(f.armedAt, isNull);
    expect(f.cancelCalls, 1);
    expect(f.ids, [kDispatchAlarmId, kDispatchAlarmId]);
  });

  test('impl passes all flags, single id, UTC time and callback', () async {
    final api = _RecordingApi();
    final s = AndroidAlarmManagerScheduler(api);
    final t = DateTime.utc(2026, 1, 2, 3);
    await s.armAt(t);
    expect(api.oneShot, {
      'time': t,
      'id': kDispatchAlarmId,
      'callback': alarmCallback,
      'alarmClock': true,
      'allowWhileIdle': true,
      'exact': true,
      'wakeup': true,
      'rescheduleOnReboot': true,
    });
    expect((api.oneShot!['time'] as DateTime).isUtc, isTrue);
  });

  test('cancel uses the same id', () async {
    final api = _RecordingApi();
    await AndroidAlarmManagerScheduler(api).cancel();
    expect(api.cancelled, [kDispatchAlarmId]);
  });
}
