import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_scheduler/data/sms/sms_gateway.dart';
import 'package:sms_scheduler/domain/clock.dart';
import 'package:sms_sender/sms_sender.dart';

import '../fakes/fake_clock.dart';
import '../fakes/fake_sms_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FakeSmsGateway', () {
    test('records calls and returns default sent', () async {
      final g = FakeSmsGateway();
      final r = await g.send(to: '+1555', body: 'hi', subscriptionId: 2);
      expect(r.isSent, isTrue);
      expect(g.calls.single.to, '+1555');
      expect(g.calls.single.body, 'hi');
      expect(g.calls.single.subscriptionId, 2);
    });

    test('returns scripted results in order then default', () async {
      final g = FakeSmsGateway()
        ..enqueue(const SmsSendOutcome(
            status: SmsSendOutcomeStatus.failed, errorCode: 1))
        ..enqueue(const SmsSendOutcome(status: SmsSendOutcomeStatus.timeout));
      expect((await g.send(to: 'a', body: 'b')).status,
          SmsSendOutcomeStatus.failed);
      expect((await g.send(to: 'a', body: 'b')).status,
          SmsSendOutcomeStatus.timeout);
      expect((await g.send(to: 'a', body: 'b')).status,
          SmsSendOutcomeStatus.sent);
      expect(g.calls.length, 3);
    });
  });

  group('PluginSmsGateway', () {
    void mock(Future<Object?> Function(MethodCall) h) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SmsSender.channel, h);
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SmsSender.channel, null);
    });

    test('maps sent with parts', () async {
      MethodCall? call;
      mock((c) async {
        call = c;
        return {'status': 'sent', 'errorCode': null, 'parts': 3};
      });
      final r = await const PluginSmsGateway()
          .send(to: '+1555', body: 'x', subscriptionId: 4);
      expect(r,
          const SmsSendOutcome(status: SmsSendOutcomeStatus.sent, parts: 3));
      expect(call!.arguments,
          {'to': '+1555', 'body': 'x', 'subscriptionId': 4});
    });

    test('maps failed with errorCode', () async {
      mock((_) async => {'status': 'failed', 'errorCode': 4, 'parts': 2});
      final r = await const PluginSmsGateway().send(to: 'a', body: 'b');
      expect(
          r,
          const SmsSendOutcome(
              status: SmsSendOutcomeStatus.failed, errorCode: 4, parts: 2));
    });

    test('maps timeout', () async {
      mock((_) async => {'status': 'timeout', 'errorCode': null, 'parts': 1});
      final r = await const PluginSmsGateway().send(to: 'a', body: 'b');
      expect(r.status, SmsSendOutcomeStatus.timeout);
      expect(r.parts, 1);
    });

    test('PlatformException becomes failed outcome', () async {
      mock((_) async => throw PlatformException(code: 'boom'));
      final r = await const PluginSmsGateway().send(to: 'a', body: 'b');
      expect(r.status, SmsSendOutcomeStatus.failed);
    });
  });

  group('Clock', () {
    test('FakeClock is settable and advanceable, UTC', () {
      final c = FakeClock(DateTime.utc(2026, 1, 1, 9));
      c.advance(const Duration(minutes: 5));
      expect(c.now(), DateTime.utc(2026, 1, 1, 9, 5));
      c.time = DateTime.utc(2027);
      expect(c.now(), DateTime.utc(2027));
      expect(c.now().isUtc, isTrue);
    });

    test('SystemClock returns UTC', () {
      expect(const SystemClock().now().isUtc, isTrue);
    });
  });
}
