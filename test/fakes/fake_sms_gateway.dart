import 'package:sms_scheduler/data/sms/sms_gateway.dart';

class SentSms {
  const SentSms(this.to, this.body, this.subscriptionId);
  final String to;
  final String body;
  final int? subscriptionId;
}

/// Records calls; returns queued results, then [defaultOutcome].
class FakeSmsGateway implements SmsGateway {
  FakeSmsGateway({
    this.defaultOutcome = const SmsSendOutcome(
      status: SmsSendOutcomeStatus.sent,
      parts: 1,
    ),
  });

  final SmsSendOutcome defaultOutcome;
  final List<SentSms> calls = [];
  final List<SmsSendOutcome> _queue = [];

  void enqueue(SmsSendOutcome outcome) => _queue.add(outcome);

  @override
  Future<SmsSendOutcome> send({
    required String to,
    required String body,
    int? subscriptionId,
  }) async {
    calls.add(SentSms(to, body, subscriptionId));
    return _queue.isEmpty ? defaultOutcome : _queue.removeAt(0);
  }
}
