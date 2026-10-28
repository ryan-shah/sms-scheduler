import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/spike/spike_runner.dart';
import '../../ui/theme/tokens.dart';
import 'diagnostics_providers.dart';
import 'log_format.dart';
import 'permissions_section.dart';

/// Phase 1 spike harness: send / schedule / soak, permissions, alarm state,
/// and the soak log. Reached by tapping the Settings version row 7 times.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  final _to = TextEditingController();
  final _count = TextEditingController(text: '13');

  @override
  void initState() {
    super.initState();
    _to.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _to.dispose();
    _count.dispose();
    super.dispose();
  }

  String get _number => _to.text.trim();
  bool get _hasNumber => _number.isNotEmpty;
  int? get _n {
    final n = int.tryParse(_count.text.trim());
    return n != null && n > 0 ? n : null;
  }

  SpikeRunner get _runner => ref.read(spikeRunnerProvider);

  void _refresh() {
    ref.invalidate(spikeJobProvider);
    ref.invalidate(spikeLogProvider);
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _sendNow() async {
    final o = await _runner.sendNow(_number);
    _refresh();
    if (!mounted) return;
    _snack(
      'Send ${o.status.name}, errorCode ${o.errorCode ?? '-'}, '
      'parts ${o.parts}',
    );
  }

  Future<void> _scheduleSingle() async {
    await _runner.scheduleSingle(_number);
    _refresh();
    if (mounted) _snack('Armed one background send in 2 min');
  }

  Future<void> _startSoak() async {
    final n = _n;
    if (n == null) return;
    await _runner.startSoak(_number, total: n);
    _refresh();
    if (mounted) _snack('Armed $n-send soak, first send in 5 min');
  }

  Future<void> _cancel() async {
    await _runner.cancel();
    _refresh();
    if (mounted) _snack('Job cancelled');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = _n;
    Widget header(String t) => Padding(
      padding: const EdgeInsets.only(top: Spacing.lg, bottom: Spacing.xs),
      child: Text(
        t,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            TextField(
              key: const ValueKey('diag-number'),
              controller: _to,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number (E.164)',
                hintText: '+15551234567',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            FilledButton(
              onPressed: _hasNumber ? _sendNow : null,
              child: const Text('Send test SMS now'),
            ),
            const SizedBox(height: Spacing.sm),
            FilledButton.tonal(
              onPressed: _hasNumber ? _scheduleSingle : null,
              child: const Text('Send in 2 min (background)'),
            ),
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    key: const ValueKey('diag-soak-count'),
                    controller: _count,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'N',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _hasNumber && n != null ? _startSoak : null,
                    child: Text('Run 5-min soak for ${n ?? '?'} sends'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            OutlinedButton(onPressed: _cancel, child: const Text('Cancel job')),
            header('Next armed alarm'),
            const _AlarmSection(),
            header('Permissions'),
            const PermissionsSection(),
            header('Log'),
            const _LogSection(),
          ],
        ),
      ),
    );
  }
}

class _AlarmSection extends ConsumerWidget {
  const _AlarmSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(spikeJobProvider);
    final text = job.when(
      data: (j) => j == null
          ? 'None'
          : '${formatLocalTime(j.nextScheduledUtc)} local, '
                'send ${j.nextIndex + 1}/${j.total} to ${j.to}',
      loading: () => '...',
      error: (e, _) => 'error: $e',
    );
    return Text(text, key: const ValueKey('diag-next-alarm'));
  }
}

class _LogSection extends ConsumerWidget {
  const _LogSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(spikeLogProvider);
    return log.when(
      loading: () => const Text('...'),
      error: (e, _) => Text('error: $e'),
      data: (entries) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextButton.icon(
                  onPressed: entries.isEmpty
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(
                            ClipboardData(text: logToJsonl(entries)),
                          );
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Copied ${entries.length} rows'),
                            ),
                          );
                        },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy log'),
                ),
                TextButton.icon(
                  onPressed: entries.isEmpty
                      ? null
                      : () async {
                          await ref.read(spikeRunnerProvider).clearLog();
                          ref.invalidate(spikeLogProvider);
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear log'),
                ),
              ],
            ),
            if (entries.isEmpty) const Text('No log rows yet'),
            for (final e in entries.reversed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(describeLogEntry(e)),
                subtitle: Text(describeLogOutcome(e)),
              ),
          ],
        );
      },
    );
  }
}
