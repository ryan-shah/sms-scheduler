import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/clock.dart';
import '../alarms/alarm_scheduler.dart';
import '../clock_provider.dart';
import '../sms/sms_gateway.dart';
import 'spike_models.dart';
import 'spike_store.dart';

/// Phase 1 spike logic: schedule test sends, and run one send per alarm fire.
///
/// Timing is absolute: send `k` (0-based) is scheduled at
/// `start + k * interval`; drift never compounds.
class SpikeRunner {
  SpikeRunner({
    required this._store,
    required this._gateway,
    required this._alarms,
    required this._clock,
  });

  final SpikeStore _store;
  final SmsGateway _gateway;
  final AlarmScheduler _alarms;
  final Clock _clock;

  /// Immediate foreground test send. Logs k=0,total=1 and leaves the
  /// job/alarm untouched.
  Future<SmsSendOutcome> sendNow(String to) async {
    final now = _clock.now();
    final outcome = await _safeSend(to, _body(0, 1, now));
    await _store.appendLog(_entry(0, 1, now, now, outcome));
    return outcome;
  }

  /// One background send at `now + delay` (total=1).
  Future<void> scheduleSingle(
    String to, {
    Duration delay = const Duration(minutes: 2),
  }) => _startJob(
    to,
    total: 1,
    interval: const Duration(minutes: 5),
    delay: delay,
  );

  /// Soak of [total] sends. Chosen timing: `start = now + interval`, so the
  /// first send is one interval out (time to lock the screen) and send k is
  /// scheduled at `start + k * interval`.
  Future<void> startSoak(
    String to, {
    int total = 13,
    Duration interval = const Duration(minutes: 5),
  }) => _startJob(to, total: total, interval: interval, delay: interval);

  Future<void> _startJob(
    String to, {
    required int total,
    required Duration interval,
    required Duration delay,
  }) async {
    final start = _clock.now().add(delay);
    await _store.writeJob(
      SpikeJob(
        to: to,
        total: total,
        nextIndex: 0,
        interval: interval,
        startUtc: start,
        nextScheduledUtc: start,
      ),
    );
    await _alarms.armAt(start);
  }

  Future<void> cancel() async {
    await _store.clearJob();
    await _alarms.cancel();
  }

  /// Alarm callback body: perform send `job.nextIndex`.
  ///
  /// Ordering (crash safety): the advanced job is persisted and the next alarm
  /// armed BEFORE sending. If the isolate dies mid-send the soak is not stalled
  /// and this slot is never re-sent (at worst its log row is missing).
  ///
  /// No catch-up: if the next slot is already past (a very late fire), skip
  /// forward to the first future slot `start + m * interval`, m > k. Skipped
  /// slots are not sent but the index advances, so the log shows the gap.
  Future<void> onAlarm() async {
    final job = await _store.readJob();
    if (job == null || job.nextIndex >= job.total) {
      await _alarms.cancel();
      if (job != null) await _store.clearJob();
      return;
    }
    final k = job.nextIndex;
    final scheduledFor = job.scheduledFor(k);
    final firedAt = _clock.now();

    var next = k + 1;
    if (next < job.total && !job.scheduledFor(next).isAfter(firedAt)) {
      final elapsed = firedAt.difference(job.startUtc);
      final m = elapsed.inMicroseconds ~/ job.interval.inMicroseconds + 1;
      if (m > next) next = m;
    }
    if (next < job.total) {
      final at = job.scheduledFor(next);
      await _store.writeJob(
        job.copyWith(nextIndex: next, nextScheduledUtc: at),
      );
      await _alarms.armAt(at);
    } else {
      await _store.clearJob();
    }

    final outcome = await _safeSend(job.to, _body(k, job.total, scheduledFor));
    await _store.appendLog(
      _entry(k, job.total, scheduledFor, firedAt, outcome),
    );
  }

  Future<SpikeJob?> currentJob() => _store.readJob();
  Future<List<SpikeLogEntry>> log() => _store.readLog();
  Future<void> clearLog() => _store.clearLog();

  Future<SmsSendOutcome> _safeSend(String to, String body) async {
    try {
      return await _gateway.send(to: to, body: body);
    } on Object catch (e) {
      debugPrint('SpikeRunner: gateway threw: $e');
      return const SmsSendOutcome(status: SmsSendOutcomeStatus.failed);
    }
  }

  SpikeLogEntry _entry(
    int k,
    int total,
    DateTime scheduledFor,
    DateTime firedAt,
    SmsSendOutcome o,
  ) => SpikeLogEntry(
    k: k,
    total: total,
    scheduledFor: scheduledFor,
    firedAt: firedAt,
    status: o.status.name,
    errorCode: o.errorCode,
    parts: o.parts,
  );

  /// e.g. "SMS Scheduler test #3/13 scheduled 14:05Z" (single SMS part).
  static String _body(int k, int total, DateTime scheduledFor) {
    final u = scheduledFor.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'SMS Scheduler test #${k + 1}/$total scheduled '
        '${two(u.hour)}:${two(u.minute)}Z';
  }
}

final spikeRunnerProvider = Provider<SpikeRunner>(
  (ref) => SpikeRunner(
    store: ref.watch(spikeStoreProvider),
    gateway: ref.watch(smsGatewayProvider),
    alarms: ref.watch(alarmSchedulerProvider),
    clock: ref.watch(clockProvider),
  ),
);
