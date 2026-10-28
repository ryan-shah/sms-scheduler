import 'package:flutter/foundation.dart';

/// The pending soak-test job persisted in `spike_job.json`.
///
/// Send `k` (0-based [nextIndex]) is scheduled at `startUtc + k * interval`,
/// so drift never compounds. Instants are stored as UTC ISO-8601 strings.
@immutable
class SpikeJob {
  const SpikeJob({
    required this.to,
    required this.total,
    required this.nextIndex,
    required this.interval,
    required this.startUtc,
    required this.nextScheduledUtc,
  });

  final String to;
  final int total;

  /// Index `k` of the next send to perform; the job is done at `total`.
  final int nextIndex;
  final Duration interval;
  final DateTime startUtc;
  final DateTime nextScheduledUtc;

  int get remaining => total - nextIndex;

  /// Absolute scheduled instant of send [k].
  DateTime scheduledFor(int k) => startUtc.add(interval * k);

  SpikeJob copyWith({int? nextIndex, DateTime? nextScheduledUtc}) => SpikeJob(
    to: to,
    total: total,
    nextIndex: nextIndex ?? this.nextIndex,
    interval: interval,
    startUtc: startUtc,
    nextScheduledUtc: nextScheduledUtc ?? this.nextScheduledUtc,
  );

  Map<String, Object?> toJson() => {
    'to': to,
    'total': total,
    'nextIndex': nextIndex,
    'intervalMs': interval.inMilliseconds,
    'startUtc': startUtc.toUtc().toIso8601String(),
    'nextScheduledUtc': nextScheduledUtc.toUtc().toIso8601String(),
  };

  /// Throws [FormatException]/[TypeError] on malformed input.
  factory SpikeJob.fromJson(Map<String, Object?> json) => SpikeJob(
    to: json['to']! as String,
    total: json['total']! as int,
    nextIndex: json['nextIndex']! as int,
    interval: Duration(milliseconds: json['intervalMs']! as int),
    startUtc: DateTime.parse(json['startUtc']! as String).toUtc(),
    nextScheduledUtc: DateTime.parse(
      json['nextScheduledUtc']! as String,
    ).toUtc(),
  );

  @override
  bool operator ==(Object other) =>
      other is SpikeJob &&
      other.to == to &&
      other.total == total &&
      other.nextIndex == nextIndex &&
      other.interval == interval &&
      other.startUtc == startUtc &&
      other.nextScheduledUtc == nextScheduledUtc;

  @override
  int get hashCode =>
      Object.hash(to, total, nextIndex, interval, startUtc, nextScheduledUtc);

  @override
  String toString() =>
      'SpikeJob(to: $to, k: $nextIndex/$total, interval: $interval, '
      'start: $startUtc, next: $nextScheduledUtc)';
}

/// One row of `spike_log.jsonl`.
@immutable
class SpikeLogEntry {
  const SpikeLogEntry({
    required this.k,
    required this.total,
    required this.scheduledFor,
    required this.firedAt,
    required this.status,
    this.errorCode,
    this.parts = 0,
  });

  final int k;
  final int total;
  final DateTime scheduledFor;
  final DateTime firedAt;

  /// `SmsSendOutcomeStatus.name`: sent | failed | timeout.
  final String status;
  final int? errorCode;
  final int parts;

  /// How late the alarm fired relative to its slot.
  Duration get drift => firedAt.difference(scheduledFor);

  Map<String, Object?> toJson() => {
    'k': k,
    'total': total,
    'scheduledFor': scheduledFor.toUtc().toIso8601String(),
    'firedAt': firedAt.toUtc().toIso8601String(),
    'status': status,
    'errorCode': errorCode,
    'parts': parts,
  };

  factory SpikeLogEntry.fromJson(Map<String, Object?> json) => SpikeLogEntry(
    k: json['k']! as int,
    total: json['total']! as int,
    scheduledFor: DateTime.parse(json['scheduledFor']! as String).toUtc(),
    firedAt: DateTime.parse(json['firedAt']! as String).toUtc(),
    status: json['status']! as String,
    errorCode: json['errorCode'] as int?,
    parts: json['parts']! as int,
  );

  @override
  bool operator ==(Object other) =>
      other is SpikeLogEntry &&
      other.k == k &&
      other.total == total &&
      other.scheduledFor == scheduledFor &&
      other.firedAt == firedAt &&
      other.status == status &&
      other.errorCode == errorCode &&
      other.parts == parts;

  @override
  int get hashCode =>
      Object.hash(k, total, scheduledFor, firedAt, status, errorCode, parts);

  @override
  String toString() =>
      'SpikeLogEntry(k: $k/$total $status, drift: $drift, '
      'errorCode: $errorCode, parts: $parts)';
}
