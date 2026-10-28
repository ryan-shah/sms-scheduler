import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/spike/spike_models.dart';
import '../../data/spike/spike_runner.dart';

/// Session-only developer toggle (not persisted; Phase 5 makes it a setting).
class DeveloperMode extends Notifier<bool> {
  @override
  bool build() => false;

  void enable() => state = true;
}

final developerModeProvider = NotifierProvider<DeveloperMode, bool>(
  DeveloperMode.new,
);

/// The pending spike job; invalidate after actions (the background isolate
/// updates the files, so the screen also offers a manual refresh).
final spikeJobProvider = FutureProvider.autoDispose<SpikeJob?>(
  (ref) => ref.watch(spikeRunnerProvider).currentJob(),
);

final spikeLogProvider = FutureProvider.autoDispose<List<SpikeLogEntry>>(
  (ref) => ref.watch(spikeRunnerProvider).log(),
);
