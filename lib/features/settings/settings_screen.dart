import 'package:flutter/material.dart';

import '../../app_version.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text(appVersion),
          ),
        ],
      ),
    );
  }
}
