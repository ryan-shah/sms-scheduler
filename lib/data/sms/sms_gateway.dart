import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sms_sender/sms_sender.dart';

/// Aggregate outcome of one (possibly multipart) SMS send.
enum SmsSendOutcomeStatus { sent, failed, timeout }

/// App-side result of [SmsGateway.send], independent of the plugin's types.
@immutable
class SmsSendOutcome {
  const SmsSendOutcome({
    required this.status,
    this.errorCode,
    this.parts = 0,
  });

  final SmsSendOutcomeStatus status;
  final int? errorCode;
  final int parts;

  bool get isSent => status == SmsSendOutcomeStatus.sent;

  @override
  bool operator ==(Object other) =>
      other is SmsSendOutcome &&
      other.status == status &&
      other.errorCode == errorCode &&
      other.parts == parts;

  @override
  int get hashCode => Object.hash(status, errorCode, parts);

  @override
  String toString() =>
      'SmsSendOutcome(status: $status, errorCode: $errorCode, parts: $parts)';
}

/// Sends SMS from the device SIM. Implementations never throw for send failures.
abstract class SmsGateway {
  Future<SmsSendOutcome> send({
    required String to,
    required String body,
    int? subscriptionId,
  });
}

/// [SmsGateway] backed by the in-repo `sms_sender` plugin.
class PluginSmsGateway implements SmsGateway {
  const PluginSmsGateway([this._sender = const SmsSender()]);

  final SmsSender _sender;

  @override
  Future<SmsSendOutcome> send({
    required String to,
    required String body,
    int? subscriptionId,
  }) async {
    try {
      final r = await _sender.send(
        to: to,
        body: body,
        subscriptionId: subscriptionId,
      );
      return SmsSendOutcome(
        status: switch (r.status) {
          SmsSendStatus.sent => SmsSendOutcomeStatus.sent,
          SmsSendStatus.failed => SmsSendOutcomeStatus.failed,
          SmsSendStatus.timeout => SmsSendOutcomeStatus.timeout,
        },
        errorCode: r.errorCode,
        parts: r.parts,
      );
    } on PlatformException {
      return const SmsSendOutcome(status: SmsSendOutcomeStatus.failed);
    } on MissingPluginException {
      return const SmsSendOutcome(status: SmsSendOutcomeStatus.failed);
    }
  }
}

final smsGatewayProvider =
    Provider<SmsGateway>((ref) => const PluginSmsGateway());
