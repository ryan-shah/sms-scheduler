import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alarm_callback.dart';

/// The one alarm id used by the app (DESIGN §2 single-alarm model).
const kDispatchAlarmId = 0;

/// Arms a single exact wake-up alarm that runs [alarmCallback].
abstract class AlarmScheduler {
  /// Arms (replacing any existing) the alarm for [whenUtc].
  Future<void> armAt(DateTime whenUtc);

  /// Cancels the alarm, if armed.
  Future<void> cancel();
}

/// Thin seam over the static [AndroidAlarmManager] API, for tests.
class AlarmManagerApi {
  const AlarmManagerApi();

  Future<bool> oneShotAt(
    DateTime time,
    int id,
    Function callback, {
    required bool alarmClock,
    required bool allowWhileIdle,
    required bool exact,
    required bool wakeup,
    required bool rescheduleOnReboot,
  }) => AndroidAlarmManager.oneShotAt(
    time,
    id,
    callback,
    alarmClock: alarmClock,
    allowWhileIdle: allowWhileIdle,
    exact: exact,
    wakeup: wakeup,
    rescheduleOnReboot: rescheduleOnReboot,
  );

  Future<bool> cancel(int id) => AndroidAlarmManager.cancel(id);
}

/// [AlarmScheduler] backed by `android_alarm_manager_plus`.
class AndroidAlarmManagerScheduler implements AlarmScheduler {
  const AndroidAlarmManagerScheduler([
    this._api = const AlarmManagerApi(),
    this._callback = alarmCallback,
  ]);

  final AlarmManagerApi _api;
  final Function _callback;

  @override
  Future<void> armAt(DateTime whenUtc) async {
    await _api.oneShotAt(
      whenUtc,
      kDispatchAlarmId,
      _callback,
      exact: true,
      wakeup: true,
      alarmClock: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
    );
  }

  @override
  Future<void> cancel() async {
    await _api.cancel(kDispatchAlarmId);
  }
}

final alarmSchedulerProvider = Provider<AlarmScheduler>(
  (ref) => const AndroidAlarmManagerScheduler(),
);
