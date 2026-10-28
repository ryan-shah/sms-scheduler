import 'package:flutter/material.dart';

import '../../ui/widgets/widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: const EmptyState(
        icon: Icons.history,
        title: 'No messages sent yet',
        body: 'Each send attempt and its result will be listed here.',
      ),
    );
  }
}
