import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Runtime permissions / exemptions the app cares about.
enum AppPermission {
  /// `SEND_SMS`.
  sendSms,

  /// `POST_NOTIFICATIONS` (API 33+; granted implicitly below that).
  notifications,

  /// Exact alarms. The app declares `USE_EXACT_ALARM`, which is auto-granted
  /// on API 33+, so this is normally [AppPermissionStatus.granted] there.
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

/// [PermissionService] backed by `permission_handler`.
class PermissionHandlerService implements PermissionService {
  const PermissionHandlerService([this._api = const PermissionApi()]);

  final PermissionApi _api;

  static Permission permissionFor(AppPermission p) => switch (p) {
    AppPermission.sendSms => Permission.sms,
    AppPermission.notifications => Permission.notification,
    AppPermission.exactAlarm => Permission.scheduleExactAlarm,
    AppPermission.batteryOptimization => Permission.ignoreBatteryOptimizations,
  };

  @override
  Future<AppPermissionStatus> status(AppPermission p) async =>
      mapPermissionStatus(await _api.status(permissionFor(p)));

  @override
  Future<AppPermissionStatus> request(AppPermission p) async =>
      mapPermissionStatus(await _api.request(permissionFor(p)));

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
