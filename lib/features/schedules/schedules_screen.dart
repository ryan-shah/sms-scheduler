import 'package:flutter/material.dart';

import '../../ui/widgets/widgets.dart';

class SchedulesScreen extends StatelessWidget {
  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedules')),
      body: const EmptyState(
        icon: Icons.schedule_send_outlined,
        title: 'No schedules yet',
        body: 'Recurring SMS reminders you create will show up here.',
      ),
      floatingActionButton: const FloatingActionButton.extended(
        onPressed: null,
        tooltip: 'Coming in Phase 4',
        icon: Icon(Icons.add),
        label: Text('Coming in Phase 4'),
      ),
    );
  }
}
