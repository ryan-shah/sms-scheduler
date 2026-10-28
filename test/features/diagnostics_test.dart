import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_scheduler/app.dart';
import 'package:sms_scheduler/data/permissions/permission_service.dart';
import 'package:sms_scheduler/data/sms/sms_gateway.dart';
import 'package:sms_scheduler/data/spike/spike_models.dart';
import 'package:sms_scheduler/data/spike/spike_runner.dart';

import '../fakes/fake_permission_service.dart';

/// In-memory runner: records calls, no disk/channel access.
class RecordingRunner implements SpikeRunner {
  final List<String> calls = [];
  SpikeJob? job;
  List<SpikeLogEntry> logRows = [];

  @override
  Future<SmsSendOutcome> sendNow(String to) async {
    calls.add('sendNow:$to');
    return const SmsSendOutcome(status: SmsSendOutcomeStatus.sent, parts: 2);
  }

  @override
  Future<void> scheduleSingle(String to, {Duration? delay}) async {
    calls.add('scheduleSingle:$to');
  }

  @override
  Future<void> startSoak(
    String to, {
    int total = 13,
    Duration interval = const Duration(minutes: 5),
  }) async {
    calls.add('startSoak:$to:$total');
  }

  @override
  Future<void> cancel() async => calls.add('cancel');

  @override
  Future<SpikeJob?> currentJob() async => job;

  @override
  Future<List<SpikeLogEntry>> log() async => logRows;

  @override
  Future<void> clearLog() async {
    calls.add('clearLog');
    logRows = [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late RecordingRunner runner;
  late FakePermissionService perms;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          spikeRunnerProvider.overrideWithValue(runner),
          permissionServiceProvider.overrideWithValue(perms),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVersion(WidgetTester tester, int times) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.text('Version'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> openDiagnostics(WidgetTester tester) async {
    await pump(tester);
    await tapVersion(tester, 7);
    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  setUp(() {
    runner = RecordingRunner();
    perms = FakePermissionService(
      statuses: {AppPermission.sendSms: AppPermissionStatus.granted},
      requestResults: {
        AppPermission.notifications: AppPermissionStatus.granted,
      },
    );
  });

  testWidgets('Diagnostics tile appears after exactly 7 version taps', (
    tester,
  ) async {
    await pump(tester);
    await tapVersion(tester, 6);
    expect(find.text('Diagnostics'), findsNothing);
    await tapVersion(tester, 1);
    expect(find.text('Developer options enabled'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);

    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();
    expect(find.text('Phone number (E.164)'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('buttons are disabled until a number is entered', (tester) async {
    await openDiagnostics(tester);
    FilledButton send() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send test SMS now'),
    );
    expect(send().onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('diag-number')), '  ');
    await tester.pump();
    expect(send().onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('diag-number')),
      ' +15551234567 ',
    );
    await tester.pump();
    expect(send().onPressed, isNotNull);
    await teardown(tester);
  });

  testWidgets('each button calls the matching runner method', (tester) async {
    await openDiagnostics(tester);
    await tester.enterText(
      find.byKey(const ValueKey('diag-number')),
      ' +15551234567 ',
    );
    await tester.pump();

    await tester.tap(find.text('Send test SMS now'));
    await tester.pumpAndSettle();
    expect(runner.calls.last, 'sendNow:+15551234567');
    expect(find.textContaining('Send sent'), findsOneWidget);
    expect(find.textContaining('parts 2'), findsOneWidget);

    await tester.tap(find.text('Send in 2 min (background)'));
    await tester.pumpAndSettle();
    expect(runner.calls.last, 'scheduleSingle:+15551234567');

    await tester.enterText(find.byKey(const ValueKey('diag-soak-count')), '4');
    await tester.pump();
    await tester.tap(find.text('Run 5-min soak for 4 sends'));
    await tester.pumpAndSettle();
    expect(runner.calls.last, 'startSoak:+15551234567:4');

    await tester.tap(find.text('Cancel job'));
    await tester.pumpAndSettle();
    expect(runner.calls.last, 'cancel');
    await teardown(tester);
  });

  testWidgets('soak count defaults to 13', (tester) async {
    await openDiagnostics(tester);
    expect(find.text('Run 5-min soak for 13 sends'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('next alarm shows None, or the job progress', (tester) async {
    await openDiagnostics(tester);
    expect(find.text('None'), findsOneWidget);
    runner.job = SpikeJob(
      to: '+15551234567',
      total: 13,
      nextIndex: 2,
      interval: const Duration(minutes: 5),
      startUtc: DateTime.utc(2026, 10, 28, 12),
      nextScheduledUtc: DateTime.utc(2026, 10, 28, 12, 10),
    );
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.textContaining('send 3/13'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('permission rows render statuses and Request updates them', (
    tester,
  ) async {
    await openDiagnostics(tester);
    await tester.scrollUntilVisible(
      find.text('Open app settings'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    String status(AppPermission p) => tester
        .widget<Text>(find.byKey(ValueKey('perm-status-${p.name}')))
        .data!;
    expect(find.text('Battery optimization exemption'), findsOneWidget);
    expect(status(AppPermission.sendSms), 'granted');
    expect(status(AppPermission.notifications), 'denied');
    expect(status(AppPermission.batteryOptimization), 'denied');

    final req = find.byKey(const ValueKey('perm-request-notifications'));
    await tester.ensureVisible(req);
    await tester.pumpAndSettle();
    await tester.tap(req);
    await tester.pumpAndSettle();
    expect(perms.requestCalls, [AppPermission.notifications]);
    expect(status(AppPermission.notifications), 'granted');

    await tester.tap(find.text('Open app settings'));
    await tester.pump();
    expect(perms.openSettingsCalls, 1);
    await teardown(tester);
  });

  testWidgets('log viewer lists rows newest first; copy and clear work', (
    tester,
  ) async {
    runner.logRows = [
      for (var k = 0; k < 2; k++)
        SpikeLogEntry(
          k: k,
          total: 2,
          scheduledFor: DateTime.utc(2026, 10, 28, 12, k * 5),
          firedAt: DateTime.utc(2026, 10, 28, 12, k * 5, 3),
          status: k == 0 ? 'sent' : 'failed',
          errorCode: k == 0 ? null : 4,
          parts: 1,
        ),
    ];
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await openDiagnostics(tester);
    await tester.scrollUntilVisible(
      find.text('Clear log'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('#1/2'), findsOneWidget);
    expect(find.textContaining('#2/2'), findsOneWidget);
    expect(find.textContaining('drift 3.0s'), findsNWidgets(2));
    expect(find.textContaining('failed  errorCode 4'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('#2/2')).dy,
      lessThan(tester.getTopLeft(find.textContaining('#1/2')).dy),
    );

    await tester.tap(find.text('Copy log'));
    await tester.pumpAndSettle();
    expect(copied!.split('\n'), hasLength(2));
    expect(copied, contains('"status":"failed"'));

    await tester.tap(find.text('Clear log'));
    await tester.pumpAndSettle();
    expect(runner.calls, contains('clearLog'));
    expect(find.text('No log rows yet'), findsOneWidget);
    await teardown(tester);
  });
}
