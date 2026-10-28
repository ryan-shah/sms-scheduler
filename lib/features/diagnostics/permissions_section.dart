import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/permissions/permission_service.dart';

String permissionLabel(AppPermission p) => switch (p) {
  AppPermission.sendSms => 'Send SMS',
  AppPermission.notifications => 'Notifications',
  AppPermission.exactAlarm => 'Exact alarms',
  AppPermission.batteryOptimization => 'Battery optimization exemption',
};

class PermissionsSection extends ConsumerWidget {
  const PermissionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        for (final p in AppPermission.values) _PermissionRow(permission: p),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => ref.read(permissionServiceProvider).openSettings(),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Open app settings'),
          ),
        ),
      ],
    );
  }
}

class _PermissionRow extends ConsumerWidget {
  const _PermissionRow({required this.permission});

  final AppPermission permission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(permissionStatusProvider(permission));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(permissionLabel(permission)),
      subtitle: Text(
        status.when(
          data: (s) => s.name,
          loading: () => '...',
          error: (e, _) => 'error',
        ),
        key: ValueKey('perm-status-${permission.name}'),
      ),
      trailing: OutlinedButton(
        key: ValueKey('perm-request-${permission.name}'),
        onPressed: () async {
          await ref.read(permissionServiceProvider).request(permission);
          ref.invalidate(permissionStatusProvider(permission));
        },
        child: const Text('Request'),
      ),
    );
  }
}
