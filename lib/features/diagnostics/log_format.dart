import 'dart:convert';

import '../../data/spike/spike_models.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// Local `HH:mm:ss`.
String formatLocalTime(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}:${_two(l.second)}';
}

String formatDriftSeconds(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';

/// One human-readable row of the log viewer.
String describeLogEntry(SpikeLogEntry e) =>
    '#${e.k + 1}/${e.total}  sched ${formatLocalTime(e.scheduledFor)}  '
    'fired ${formatLocalTime(e.firedAt)}  drift ${formatDriftSeconds(e.drift)}';

String describeLogOutcome(SpikeLogEntry e) =>
    '${e.status}  errorCode ${e.errorCode ?? '-'}  parts ${e.parts}';

/// Clipboard text: JSONL, oldest first (file order).
String logToJsonl(List<SpikeLogEntry> entries) =>
    entries.map((e) => jsonEncode(e.toJson())).join('\n');
