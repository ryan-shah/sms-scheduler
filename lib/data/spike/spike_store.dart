import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'spike_models.dart';

/// File-backed spike state (`spike_job.json`, `spike_log.jsonl`).
///
/// Safe across isolates: no in-memory state, every call hits disk. The job is
/// replaced atomically (temp file + rename); log rows are single appended lines.
class SpikeStore {
  SpikeStore([Future<Directory> Function()? dir])
    : _dir = dir ?? getApplicationSupportDirectory;

  static const jobFileName = 'spike_job.json';
  static const logFileName = 'spike_log.jsonl';

  final Future<Directory> Function() _dir;

  Future<File> _file(String name) async {
    final d = await _dir();
    if (!d.existsSync()) await d.create(recursive: true);
    return File('${d.path}${Platform.pathSeparator}$name');
  }

  Future<SpikeJob?> readJob() async {
    try {
      final f = await _file(jobFileName);
      if (!f.existsSync()) return null;
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map<String, Object?>) return null;
      return SpikeJob.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  Future<void> writeJob(SpikeJob job) async {
    final f = await _file(jobFileName);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(job.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  Future<void> clearJob() async {
    final f = await _file(jobFileName);
    if (f.existsSync()) await f.delete();
  }

  Future<void> appendLog(SpikeLogEntry entry) async {
    final f = await _file(logFileName);
    await f.writeAsString(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  /// Valid rows in append order; corrupt lines (e.g. a torn tail) are skipped.
  Future<List<SpikeLogEntry>> readLog() async {
    final f = await _file(logFileName);
    if (!f.existsSync()) return const [];
    final String text;
    try {
      text = await f.readAsString();
    } on Object {
      return const [];
    }
    final out = <SpikeLogEntry>[];
    for (final line in const LineSplitter().convert(text)) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, Object?>) {
          out.add(SpikeLogEntry.fromJson(decoded));
        }
      } on Object {
        // Skip corrupt line.
      }
    }
    return out;
  }

  Future<void> clearLog() async {
    final f = await _file(logFileName);
    if (f.existsSync()) await f.delete();
  }
}

final spikeStoreProvider = Provider<SpikeStore>((ref) => SpikeStore());
