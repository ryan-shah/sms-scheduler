import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sms_scheduler/data/permissions/permission_service.dart';

import '../../fakes/fake_permission_service.dart';

class _ScriptedApi implements PermissionApi {
  PermissionStatus statusResult = PermissionStatus.denied;
  PermissionStatus requestResult = PermissionStatus.granted;
  final statusCalls = <Permission>[];
  final requestCalls = <Permission>[];
  int settingsCalls = 0;

  @override
  Future<PermissionStatus> status(Permission p) async {
    statusCalls.add(p);
    return statusResult;
  }

  @override
  Future<PermissionStatus> request(Permission p) async {
    requestCalls.add(p);
    return requestResult;
  }

  @override
  Future<bool> openSettings() async {
    settingsCalls++;
    return true;
  }
}

void main() {
  group('mapPermissionStatus', () {
    const expected = {
      PermissionStatus.granted: AppPermissionStatus.granted,
      PermissionStatus.limited: AppPermissionStatus.granted,
      PermissionStatus.provisional: AppPermissionStatus.granted,
      PermissionStatus.denied: AppPermissionStatus.denied,
      PermissionStatus.permanentlyDenied: AppPermissionStatus.permanentlyDenied,
      PermissionStatus.restricted: AppPermissionStatus.restricted,
    };
    test('covers every PermissionStatus', () {
      expect(expected.keys.toSet(), PermissionStatus.values.toSet());
    });
    for (final e in expected.entries) {
      test('${e.key.name} -> ${e.value.name}', () {
        expect(mapPermissionStatus(e.key), e.value);
      });
    }
  });

  group('PermissionHandlerService', () {
    const targets = {
      AppPermission.sendSms: Permission.sms,
      AppPermission.notifications: Permission.notification,
      AppPermission.exactAlarm: Permission.scheduleExactAlarm,
      AppPermission.batteryOptimization: Permission.ignoreBatteryOptimizations,
    };

    test('targets table covers every AppPermission', () {
      expect(targets.keys.toSet(), AppPermission.values.toSet());
    });

    for (final e in targets.entries) {
      test('${e.key.name}: status and request use ${e.value}', () async {
        final api = _ScriptedApi()..statusResult = PermissionStatus.denied;
        final service = PermissionHandlerService(api);

        expect(await service.status(e.key), AppPermissionStatus.denied);
        expect(api.statusCalls, [e.value]);

        api.requestResult = PermissionStatus.permanentlyDenied;
        expect(
          await service.request(e.key),
          AppPermissionStatus.permanentlyDenied,
        );
        expect(api.requestCalls, [e.value]);
      });
    }

    test('openSettings delegates', () async {
      final api = _ScriptedApi();
      expect(await PermissionHandlerService(api).openSettings(), isTrue);
      expect(api.settingsCalls, 1);
    });
  });

  group('FakePermissionService', () {
    test('unscripted is denied; scripted status is returned', () async {
      final fake = FakePermissionService(
        statuses: {AppPermission.sendSms: AppPermissionStatus.granted},
      );
      expect(
        await fake.status(AppPermission.sendSms),
        AppPermissionStatus.granted,
      );
      expect(
        await fake.status(AppPermission.notifications),
        AppPermissionStatus.denied,
      );
    });

    test('request records and flips to scripted result', () async {
      final fake = FakePermissionService(
        requestResults: {AppPermission.sendSms: AppPermissionStatus.granted},
      );
      expect(
        await fake.request(AppPermission.sendSms),
        AppPermissionStatus.granted,
      );
      expect(
        await fake.request(AppPermission.notifications),
        AppPermissionStatus.denied,
      );
      expect(fake.requestCalls, [
        AppPermission.sendSms,
        AppPermission.notifications,
      ]);
      expect(
        await fake.status(AppPermission.sendSms),
        AppPermissionStatus.granted,
      );
    });

    test('openSettings counts calls', () async {
      final fake = FakePermissionService();
      expect(await fake.openSettings(), isTrue);
      expect(fake.openSettingsCalls, 1);
    });
  });

  test('permissionStatusProvider reads through the service', () async {
    final container = ProviderContainer(
      overrides: [
        permissionServiceProvider.overrideWithValue(
          FakePermissionService(
            statuses: {
              AppPermission.batteryOptimization:
                  AppPermissionStatus.permanentlyDenied,
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(
        permissionStatusProvider(AppPermission.batteryOptimization).future,
      ),
      AppPermissionStatus.permanentlyDenied,
    );
  });
}
