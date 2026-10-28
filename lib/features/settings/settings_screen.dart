import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_version.dart';
import '../../ui/routing/app_router.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/widgets.dart';
import '../diagnostics/diagnostics_providers.dart';

/// Taps on the version row needed to reveal developer options.
const int kDeveloperTapCount = 7;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _taps = 0;

  void _onVersionTap() {
    if (ref.read(developerModeProvider)) return;
    _taps++;
    if (_taps >= kDeveloperTapCount) {
      ref.read(developerModeProvider.notifier).enable();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Developer options enabled')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final developer = ref.watch(developerModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        children: [
          const Expanded(
            child: EmptyState(
              icon: Icons.settings_outlined,
              title: 'Nothing to configure yet',
              body: 'Permissions and preferences will appear here.',
            ),
          ),
          if (developer)
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Diagnostics'),
              onTap: () => context.push(AppRoutes.diagnostics),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.md,
              Spacing.md,
              Spacing.xs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'About',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text(appVersion),
            onTap: _onVersionTap,
          ),
        ],
      ),
    );
  }
}
