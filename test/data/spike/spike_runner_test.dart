import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sms_scheduler/data/sms/sms_gateway.dart';
import 'package:sms_scheduler/data/spike/spike_runner.dart';
import 'package:sms_scheduler/data/spike/spike_store.dart';

import '../../fakes/fake_alarm_scheduler.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_sms_gateway.dart';

void main() {
  late Directory dir;
  late SpikeStore store;
  late FakeClock clock;
  late FakeSmsGateway gateway;
  late FakeAlarmScheduler alarms;
  late SpikeRunner runner;

  final t0 = DateTime.utc(2026, 10, 28, 12);
  const to = '+15551234567';
  const five = Duration(minutes: 5);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('spike_runner_test');
    store = SpikeStore(() async => dir);
    clock = FakeClock(t0);
    gateway = FakeSmsGateway();
    alarms = FakeAlarmScheduler();
    runner = SpikeRunner(
      store: store,
      gateway: gateway,
      alarms: alarms,
      clock: clock,
    );
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('13-send soak arms start + k*5min exactly and finishes', () async {
    await runner.startSoak(to);
    final start = t0.add(five);
    expect(alarms.armedAt, start);
    for (var k = 0; k < 13; k++) {
      expect(alarms.armedAt, start.add(five * k));
      clock.time = alarms.armedAt!;
      await runner.onAlarm();
    }
    expect(gateway.calls, hasLength(13));
    for (var k = 0; k < 13; k++) {
      expect(gateway.calls[k].body, contains('#${k + 1}/13'));
      expect(gateway.calls[k].to, to);
    }
    expect(gateway.calls[2].body, 'SMS Scheduler test #3/13 scheduled 12:15Z');
    expect(await runner.currentJob(), isNull);
    expect(alarms.armedAt, start.add(five * 12));
    final log = await runner.log();
    expect(log.map((e) => e.k), List.generate(13, (i) => i));
    expect(log.every((e) => e.drift == Duration.zero), isTrue);
  });

  test('late fire logs drift and arms the next absolute slot', () async {
    await runner.startSoak(to);
    final start = t0.add(five);
    clock.time = start.add(const Duration(seconds: 90));
    await runner.onAlarm();
    expect(alarms.armedAt, start.add(five));
    expect(gateway.calls, hasLength(1));
    final log = await runner.log();
    expect(log.single.drift, const Duration(seconds: 90));
    expect((await runner.currentJob())!.nextIndex, 1);
  });

  test('very late fire skips past slots without a catch-up burst', () async {
    await runner.startSoak(to);
    final start = t0.add(five);
    // Fires 17 min after slot 0: slots 1-3 are past, next future is slot 4.
    clock.time = start.add(const Duration(minutes: 17));
    await runner.onAlarm();
    expect(gateway.calls, hasLength(1));
    expect(alarms.armedAt, start.add(five * 4));
    expect((await runner.currentJob())!.nextIndex, 4);
    clock.time = alarms.armedAt!;
    await runner.onAlarm();
    expect(gateway.calls, hasLength(2));
    final log = await runner.log();
    expect(log.map((e) => e.k), [0, 4]);
  });

  test('very late fire past the last slot finishes the soak', () async {
    await runner.startSoak(to, total: 3);
    clock.time = t0.add(const Duration(hours: 3));
    await runner.onAlarm();
    expect(gateway.calls, hasLength(1));
    expect(await runner.currentJob(), isNull);
  });

  test(
    'failed, timeout and throwing sends are logged; soak continues',
    () async {
      gateway
        ..enqueue(
          const SmsSendOutcome(
            status: SmsSendOutcomeStatus.failed,
            errorCode: 4,
            parts: 1,
          ),
        )
        ..enqueue(const SmsSendOutcome(status: SmsSendOutcomeStatus.timeout));
      await runner.startSoak(to, total: 4);
      for (var k = 0; k < 3; k++) {
        clock.time = alarms.armedAt!;
        await runner.onAlarm();
      }
      final throwing = SpikeRunner(
        store: store,
        gateway: _ThrowingGateway(),
        alarms: alarms,
        clock: clock,
      );
      clock.time = alarms.armedAt!;
      await throwing.onAlarm();
      final log = await runner.log();
      expect(log.map((e) => e.status), ['failed', 'timeout', 'sent', 'failed']);
      expect(log[0].errorCode, 4);
      expect(await runner.currentJob(), isNull);
    },
  );

  test(
    'cancel clears job and alarm; onAlarm with no job sends nothing',
    () async {
      await runner.startSoak(to);
      await runner.cancel();
      expect(await runner.currentJob(), isNull);
      expect(alarms.armedAt, isNull);
      final cancels = alarms.cancelCalls;
      await runner.onAlarm();
      expect(gateway.calls, isEmpty);
      expect(alarms.cancelCalls, cancels + 1);
      expect(await runner.log(), isEmpty);
    },
  );

  test(
    'scheduleSingle arms at now+2min; one fire sends once and clears',
    () async {
      await runner.scheduleSingle(to);
      expect(alarms.armedAt, t0.add(const Duration(minutes: 2)));
      clock.time = alarms.armedAt!;
      final armedBefore = alarms.armCalls.length;
      await runner.onAlarm();
      expect(alarms.armCalls.length, armedBefore);
      expect(gateway.calls, hasLength(1));
      expect(gateway.calls.single.body, contains('#1/1'));
      expect(await runner.currentJob(), isNull);
      await runner.clearLog();
      expect(await runner.log(), isEmpty);
    },
  );

  test('sendNow sends once and logs without arming', () async {
    final o = await runner.sendNow(to);
    expect(o.isSent, isTrue);
    expect(gateway.calls, hasLength(1));
    expect(alarms.armCalls, isEmpty);
    expect(await runner.currentJob(), isNull);
    final log = await runner.log();
    expect(log.single.k, 0);
    expect(log.single.total, 1);
    expect(log.single.scheduledFor, t0);
    expect(log.single.firedAt, t0);
  });
}

class _ThrowingGateway implements SmsGateway {
  @override
  Future<SmsSendOutcome> send({
    required String to,
    required String body,
    int? subscriptionId,
  }) async => throw StateError('boom');
}
