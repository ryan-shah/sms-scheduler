import 'package:sms_scheduler/data/permissions/permission_service.dart';

/// Scripted [PermissionService]. Unscripted permissions are denied.
class FakePermissionService implements PermissionService {
  FakePermissionService({
    Map<AppPermission, AppPermissionStatus>? statuses,
    Map<AppPermission, AppPermissionStatus>? requestResults,
  }) : statuses = {...?statuses},
       requestResults = {...?requestResults};

  final Map<AppPermission, AppPermissionStatus> statuses;

  /// Status a permission flips to when requested; absent means unchanged.
  final Map<AppPermission, AppPermissionStatus> requestResults;

  final List<AppPermission> requestCalls = [];
  int openSettingsCalls = 0;
  bool openSettingsResult = true;

  @override
  Future<AppPermissionStatus> status(AppPermission p) async =>
      statuses[p] ?? AppPermissionStatus.denied;

  @override
  Future<AppPermissionStatus> request(AppPermission p) async {
    requestCalls.add(p);
    final result = requestResults[p];
    if (result != null) statuses[p] = result;
    return status(p);
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return openSettingsResult;
  }
}
