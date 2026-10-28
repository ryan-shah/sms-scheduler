import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sender/sms_sender.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodCall? lastCall;

  void mock(Object? Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SmsSender.channel, (call) async {
      lastCall = call;
      return handler(call);
    });
  }

  tearDown(() {
    lastCall = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SmsSender.channel, null);
  });

  test('maps sent and passes arguments', () async {
    mock((_) => {'status': 'sent', 'errorCode': null, 'parts': 2});
    final r = await const SmsSender()
        .send(to: '+15551234', body: 'hi', subscriptionId: 3);
    expect(r, const SmsSendResult(status: SmsSendStatus.sent, parts: 2));
    expect(lastCall!.method, 'send');
    expect(lastCall!.arguments, {
      'to': '+15551234',
      'body': 'hi',
      'subscriptionId': 3,
    });
  });

  test('maps failed with errorCode', () async {
    mock((_) => {'status': 'failed', 'errorCode': 4, 'parts': 1});
    final r = await const SmsSender().send(to: '1', body: 'x');
    expect(r.status, SmsSendStatus.failed);
    expect(r.errorCode, 4);
    expect(r.parts, 1);
  });

  test('maps timeout', () async {
    mock((_) => {'status': 'timeout', 'errorCode': null, 'parts': 3});
    final r = await const SmsSender().send(to: '1', body: 'x');
    expect(r.status, SmsSendStatus.timeout);
    expect(r.errorCode, isNull);
    expect(r.parts, 3);
  });

  test('unknown status and null result map to failed', () async {
    mock((_) => {'status': 'weird', 'parts': 1});
    expect(
      (await const SmsSender().send(to: '1', body: 'x')).status,
      SmsSendStatus.failed,
    );
    mock((_) => null);
    expect(
      (await const SmsSender().send(to: '1', body: 'x')).status,
      SmsSendStatus.failed,
    );
  });
}
