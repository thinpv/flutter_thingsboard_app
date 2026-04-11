// B-A-7: Widget test — ToggleTile: state display + tap → verify setValue called + UI update
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/toggle_tile.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/section_card.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/device_state_providers.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';

// ─── Fakes ────────────────────────────────────────────────────────────────────

/// Fake DeviceControlService nhớ lời gọi setValue.
class _FakeControlService implements DeviceControlService {
  final calls = <(String, String, dynamic)>[];

  @override
  Future<void> setValue(String deviceId, String key, dynamic value) async {
    calls.add((deviceId, key, value));
  }

  // Unused methods — ToggleTile chỉ dùng setValue
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

// ─── Helper ───────────────────────────────────────────────────────────────────

/// Pump [ToggleTile] với provider overrides để mock telemetry + control.
Future<void> pumpToggleTile(
  WidgetTester tester, {
  required String deviceId,
  required String stateKey,
  required StateDef def,
  required AsyncValue<dynamic> telemetryValue,
  required _FakeControlService fakeControl,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Override deviceStateProvider để trả về giá trị mock
        deviceStateProvider.overrideWith(
          (ref, args) => telemetryValue,
        ),
        // Override deviceControlServiceProvider với fake
        deviceControlServiceProvider.overrideWithValue(fakeControl),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ToggleTile(
            deviceId: deviceId,
            stateKey: stateKey,
            def: def,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  const deviceId = 'device-001';
  const stateKey = 'onoff0';
  const def = StateDef(
    type: 'bool',
    controllable: true,
    labelDefault: 'Bật/Tắt',
  );

  group('ToggleTile — state display', () {
    testWidgets('shows label from StateDef.labelDefault', (tester) async {
      final fake = _FakeControlService();
      await pumpToggleTile(
        tester,
        deviceId: deviceId,
        stateKey: stateKey,
        def: def,
        telemetryValue: const AsyncValue.data(1),
        fakeControl: fake,
      );
      expect(find.text('Bật/Tắt'), findsOneWidget);
    });

    testWidgets('switch is ON when value = 1 (int)', (tester) async {
      final fake = _FakeControlService();
      await pumpToggleTile(
        tester,
        deviceId: deviceId,
        stateKey: stateKey,
        def: def,
        telemetryValue: const AsyncValue.data(1),
        fakeControl: fake,
      );
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final sw = tester.widget<Switch>(switchFinder);
      expect(sw.value, isTrue);
    });

    testWidgets('switch is OFF when value = 0', (tester) async {
      final fake = _FakeControlService();
      await pumpToggleTile(
        tester,
        deviceId: deviceId,
        stateKey: stateKey,
        def: def,
        telemetryValue: const AsyncValue.data(0),
        fakeControl: fake,
      );
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);
    });

    testWidgets('switch is ON when value = true (bool)', (tester) async {
      final fake = _FakeControlService();
      await pumpToggleTile(
        tester,
        deviceId: deviceId,
        stateKey: stateKey,
        def: def,
        telemetryValue: const AsyncValue.data(true),
        fakeControl: fake,
      );
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
    });

    testWidgets('switch is ON when value = "true" (string)', (tester) async {
      final fake = _FakeControlService();
      await pumpToggleTile(
        tester,
        deviceId: deviceId,
        stateKey: stateKey,
        def: def,
        telemetryValue: const AsyncValue.data('true'),
        fakeControl: fake,
      );
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
    });

    testWidgets('shows SkeletonTile when loading', (tester) async {
      final fake = _FakeControlService();
      await pumpToggleTile(
        tester,
        deviceId: deviceId,
        stateKey: stateKey,
        def: def,
        telemetryValue: const AsyncValue.loading(),
        fakeControl: fake,
      );
      expect(find.byType(SkeletonTile), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('shows ErrorTile when error', (tester) async {
      final fake = _FakeControlService();
      await pumpToggleTile(
        tester,
        deviceId: deviceId,
        stateKey: stateKey,
        def: def,
        telemetryValue: AsyncValue.error(
          Exception('network error'),
          StackTrace.empty,
        ),
        fakeControl: fake,
      );
      expect(find.byType(ErrorTile), findsOneWidget);
    });
  });

  group('ToggleTile — tap interaction', () {
    testWidgets('tap switch when ON → setValue called with 0', (tester) async {
      final fake = _FakeControlService();
      await pumpToggleTile(
        tester,
        deviceId: deviceId,
        stateKey: stateKey,
        def: def,
        telemetryValue: const AsyncValue.data(1),
        fakeControl: fake,
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(fake.calls, hasLength(1));
      final call = fake.calls.first;
      expect(call.$1, deviceId);
      expect(call.$2, stateKey);
      expect(call.$3, 0); // OFF → send 0
    });

    testWidgets('tap switch when OFF → setValue called with 1', (tester) async {
      final fake = _FakeControlService();
      await pumpToggleTile(
        tester,
        deviceId: deviceId,
        stateKey: stateKey,
        def: def,
        telemetryValue: const AsyncValue.data(0),
        fakeControl: fake,
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(fake.calls, hasLength(1));
      expect(fake.calls.first.$3, 1); // ON → send 1
    });

    testWidgets('switch disabled when def.controllable == false', (tester) async {
      const readOnlyDef = StateDef(
        type: 'bool',
        controllable: false,
        labelDefault: 'Trạng thái',
      );
      final fake = _FakeControlService();
      await pumpToggleTile(
        tester,
        deviceId: deviceId,
        stateKey: stateKey,
        def: readOnlyDef,
        telemetryValue: const AsyncValue.data(1),
        fakeControl: fake,
      );

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.onChanged, isNull); // disabled

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(fake.calls, isEmpty); // no RPC sent
    });
  });
}
