import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sms_scheduler/data/spike/spike_models.dart';
import 'package:sms_scheduler/data/spike/spike_store.dart';

void main() {
  late Directory dir;
  late SpikeStore store;

  final start = DateTime.utc(2026, 10, 28, 12);
  final job = SpikeJob(
    to: '+15551234567',
    total: 12,
    nextIndex: 3,
    interval: const Duration(minutes: 5),
    startUtc: start,
    nextScheduledUtc: start.add(const Duration(minutes: 15)),
  );
  SpikeLogEntry entry(int k, {String status = 'sent', int? err}) =>
      SpikeLogEntry(
        k: k,
        total: 12,
        scheduledFor: start.add(Duration(minutes: 5 * k)),
        firedAt: start.add(Duration(minutes: 5 * k, seconds: 7)),
        status: status,
        errorCode: err,
        parts: 1,
      );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('spike_store_test');
    store = SpikeStore(() async => dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  File f(String n) => File('${dir.path}${Platform.pathSeparator}$n');

  test('job round-trips with UTC preserved', () async {
    await store.writeJob(job);
    final read = await store.readJob();
    expect(read, job);
    expect(read!.startUtc.isUtc, isTrue);
    expect(read.remaining, 9);
    expect(read.scheduledFor(3), job.nextScheduledUtc);
    expect(f('spike_job.json.tmp').existsSync(), isFalse);
  });

  test('writeJob overwrites; clearJob yields null', () async {
    await store.writeJob(job);
    await store.writeJob(job.copyWith(nextIndex: 4));
    expect((await store.readJob())!.nextIndex, 4);
    await store.clearJob();
    expect(await store.readJob(), isNull);
    await store.clearJob(); // idempotent
  });

  test('missing files give null / empty', () async {
    expect(await store.readJob(), isNull);
    expect(await store.readLog(), isEmpty);
  });

  test('missing directory is created on write', () async {
    final sub = Directory('${dir.path}${Platform.pathSeparator}nested');
    final s = SpikeStore(() async => sub);
    await s.writeJob(job);
    expect(await s.readJob(), job);
  });

  test('corrupt or partial job file reads as null', () async {
    f('spike_job.json').writeAsStringSync('{"to": "+1555');
    expect(await store.readJob(), isNull);
    f('spike_job.json').writeAsStringSync('[1,2]');
    expect(await store.readJob(), isNull);
    f('spike_job.json').writeAsStringSync('{"to":"x"}');
    expect(await store.readJob(), isNull);
  });

  test('log rows append in order and round-trip', () async {
    final rows = [entry(0), entry(1, status: 'failed', err: 4), entry(2)];
    for (final r in rows) {
      await store.appendLog(r);
    }
    final read = await store.readLog();
    expect(read, rows);
    expect(read[1].errorCode, 4);
    expect(read[0].drift, const Duration(seconds: 7));
    expect(f('spike_log.jsonl').readAsLinesSync(), hasLength(3));
  });

  test('log skips corrupt middle and torn last lines', () async {
    await store.appendLog(entry(0));
    f('spike_log.jsonl').writeAsStringSync('garbage\n', mode: FileMode.append);
    await store.appendLog(entry(1));
    f(
      'spike_log.jsonl',
    ).writeAsStringSync('{"k":2,"tot', mode: FileMode.append);
    expect(await store.readLog(), [entry(0), entry(1)]);
  });

  test('clearLog empties the log', () async {
    await store.appendLog(entry(0));
    await store.clearLog();
    expect(await store.readLog(), isEmpty);
    await store.clearLog();
  });
}
