import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_scheduler/app.dart';
import 'package:sms_scheduler/ui/theme/app_theme.dart';
import 'package:sms_scheduler/ui/theme/tokens.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
}) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(const ProviderScope(child: App()));
  await tester.pumpAndSettle();
}

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Schedules tab renders empty state and disabled FAB',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('No schedules yet'), findsOneWidget);
    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.onPressed, isNull);
    expect(find.text('Coming in Phase 4'), findsOneWidget);
  });

  testWidgets('NavigationBar switches tabs', (tester) async {
    await pumpApp(tester);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tapTab(tester, 'History');
    expect(find.text('No messages sent yet'), findsOneWidget);

    await tapTab(tester, 'Settings');
    expect(find.text('Nothing to configure yet'), findsOneWidget);

    await tapTab(tester, 'Schedules');
    expect(find.text('No schedules yet'), findsOneWidget);
  });

  testWidgets('Settings About shows the dev version', (tester) async {
    await pumpApp(tester);
    await tapTab(tester, 'Settings');
    expect(find.text('About'), findsOneWidget);
    expect(find.text('dev'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('app builds with ${brightness.name} theme', (tester) async {
      await pumpApp(tester, brightness: brightness);
      final context = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, brightness);
      expect(Theme.of(context).useMaterial3, isTrue);
    });
  }

  test('themes derive from the seed token', () {
    expect(
      AppTheme.light().colorScheme,
      ColorScheme.fromSeed(seedColor: kSeedColor),
    );
    expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
  });
}
