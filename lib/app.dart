import 'package:flutter/material.dart';

/// Root widget. The theme and go_router shell arrive in sms-odd.3.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'SMS Scheduler',
      home: Scaffold(body: Center(child: Text('SMS Scheduler'))),
    );
  }
}
