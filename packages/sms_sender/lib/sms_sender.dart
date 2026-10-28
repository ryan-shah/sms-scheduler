import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Aggregate outcome of one (possibly multipart) SMS send.
enum SmsSendStatus {
  /// Every part reported RESULT_OK.
  sent,

  /// At least one part failed; [SmsSendResult.errorCode] is the first error.
  failed,

  /// Not every part reported within the native timeout (30 s).
  timeout,
}

/// Typed result of [SmsSender.send].
@immutable
class SmsSendResult {
  const SmsSendResult({
    required this.status,
    required this.parts,
    this.errorCode,
  });

  /// Builds a result from the native `{status, errorCode, parts}` map.
  /// Unknown or missing status is treated as [SmsSendStatus.failed].
  factory SmsSendResult.fromMap(Map<Object?, Object?> map) {
    final status = switch (map['status']) {
      'sent' => SmsSendStatus.sent,
      'timeout' => SmsSendStatus.timeout,
      _ => SmsSendStatus.failed,
    };
    return SmsSendResult(
      status: status,
      errorCode: map['errorCode'] as int?,
      parts: (map['parts'] as int?) ?? 0,
    );
  }

  final SmsSendStatus status;

  /// Android SMS error code (first failing part), or a plugin-specific code.
  final int? errorCode;

  /// Number of message parts the body was split into.
  final int parts;

  @override
  bool operator ==(Object other) =>
      other is SmsSendResult &&
      other.status == status &&
      other.errorCode == errorCode &&
      other.parts == parts;

  @override
  int get hashCode => Object.hash(status, errorCode, parts);

  @override
  String toString() =>
      'SmsSendResult(status: $status, errorCode: $errorCode, parts: $parts)';
}

/// Sends SMS through the Android `SmsManager` (multipart-aware).
class SmsSender {
  const SmsSender();

  @visibleForTesting
  static const MethodChannel channel = MethodChannel('com.rsh.sms_sender');

  /// Sends [body] to [to]. Completes after all SENT reports or the native
  /// timeout. Send failures come back as [SmsSendStatus.failed], not thrown.
  Future<SmsSendResult> send({
    required String to,
    required String body,
    int? subscriptionId,
  }) async {
    final raw = await channel.invokeMapMethod<Object?, Object?>('send', {
      'to': to,
      'body': body,
      'subscriptionId': subscriptionId,
    });
    if (raw == null) {
      return const SmsSendResult(status: SmsSendStatus.failed, parts: 0);
    }
    return SmsSendResult.fromMap(raw);
  }
}
