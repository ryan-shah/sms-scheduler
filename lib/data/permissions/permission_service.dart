import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Runtime permissions / exemptions the app cares about.
enum AppPermission {
  /// `SEND_SMS`.
  sendSms,

  /// `POST_NOTIFICATIONS` (API 33+; granted implicitly below that).
  notifications,

  /// Exact alarms. The app declares `USE_EXACT_ALARM`, which is auto-granted
  /// on API 33+. permission_handler can't see it (it only inspects
  /// `SCHEDULE_EXACT_ALARM`, capped at API 32 here), so this is read from
  /// `AlarmManager.canScheduleExactAlarms()` via [ExactAlarmApi].
  exactAlarm,

  /// Battery-optimization exemption; granted means the app is exempt.
  batteryOptimization,
}

/// App-side permission state, so callers don't import permission_handler.
enum AppPermissionStatus {
  granted,
  denied,

  /// Denied with "don't ask again" (or blocked); only settings can fix it.
  permanentlyDenied,

  /// Restricted by the system (e.g. policy); the user can't change it here.
  restricted,
}

/// Maps a permission_handler [PermissionStatus] to [AppPermissionStatus].
///
/// `limited` and `provisional` are iOS-only partial grants; they count as
/// granted. Android never reports them.
AppPermissionStatus mapPermissionStatus(PermissionStatus s) => switch (s) {
  PermissionStatus.granted ||
  PermissionStatus.limited ||
  PermissionStatus.provisional => AppPermissionStatus.granted,
  PermissionStatus.denied => AppPermissionStatus.denied,
  PermissionStatus.permanentlyDenied => AppPermissionStatus.permanentlyDenied,
  PermissionStatus.restricted => AppPermissionStatus.restricted,
};

abstract class PermissionService {
  Future<AppPermissionStatus> status(AppPermission p);

  /// Prompts (or opens the relevant system screen) and returns the new status.
  Future<AppPermissionStatus> request(AppPermission p);

  /// Opens the app's system settings page. Returns whether it opened.
  Future<bool> openSettings();
}

/// Thin seam over permission_handler's static/extension API, for tests.
class PermissionApi {
  const PermissionApi();

  Future<PermissionStatus> status(Permission p) => p.status;

  Future<PermissionStatus> request(Permission p) => p.request();

  Future<bool> openSettings() => openAppSettings();
}

/// Thin seam over the app's UI-only `com.rsh.smsscheduler/system` channel.
/// Never use from the alarm isolate (the channel isn't registered there).
class ExactAlarmApi {
  const ExactAlarmApi();

  static const _channel = MethodChannel('com.rsh.smsscheduler/system');

  /// Whether exact alarms may be scheduled. Errors count as false.
  Future<bool> canScheduleExactAlarms() async {
    try {
      return await _channel.invokeMethod<bool>('canScheduleExactAlarms') ??
          false;
    } on MissingPluginException catch (e) {
      debugPrint('canScheduleExactAlarms unavailable: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('canScheduleExactAlarms failed: $e');
      return false;
    }
  }

  /// Opens the system screen for exact-alarm access. Returns whether an
  /// activity was started.
  Future<bool> openExactAlarmSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openExactAlarmSettings') ??
          false;
    } on MissingPluginException catch (e) {
      debugPrint('openExactAlarmSettings unavailable: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('openExactAlarmSettings failed: $e');
      return false;
    }
  }
}

/// [PermissionService] backed by `permission_handler`, except exact alarms,
/// which come from [ExactAlarmApi].
class PermissionHandlerService implements PermissionService {
  const PermissionHandlerService([
    this._api = const PermissionApi(),
    this._exactAlarm = const ExactAlarmApi(),
  ]);

  final PermissionApi _api;
  final ExactAlarmApi _exactAlarm;

  static Permission permissionFor(AppPermission p) => switch (p) {
    AppPermission.sendSms => Permission.sms,
    AppPermission.notifications => Permission.notification,
    AppPermission.exactAlarm => Permission.scheduleExactAlarm,
    AppPermission.batteryOptimization => Permission.ignoreBatteryOptimizations,
  };

  @override
  Future<AppPermissionStatus> status(AppPermission p) async {
    if (p == AppPermission.exactAlarm) return _exactAlarmStatus();
    return mapPermissionStatus(await _api.status(permissionFor(p)));
  }

  @override
  Future<AppPermissionStatus> request(AppPermission p) async {
    if (p == AppPermission.exactAlarm) {
      if (await _exactAlarmStatus() == AppPermissionStatus.granted) {
        return AppPermissionStatus.granted;
      }
      await _exactAlarm.openExactAlarmSettings();
      return _exactAlarmStatus();
    }
    return mapPermissionStatus(await _api.request(permissionFor(p)));
  }

  Future<AppPermissionStatus> _exactAlarmStatus() async =>
      await _exactAlarm.canScheduleExactAlarms()
      ? AppPermissionStatus.granted
      : AppPermissionStatus.denied;

  @override
  Future<bool> openSettings() => _api.openSettings();
}

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const PermissionHandlerService(),
);

/// Current status of one permission; invalidate after a request.
final permissionStatusProvider = FutureProvider.autoDispose
    .family<AppPermissionStatus, AppPermission>(
      (ref, p) => ref.watch(permissionServiceProvider).status(p),
    );
