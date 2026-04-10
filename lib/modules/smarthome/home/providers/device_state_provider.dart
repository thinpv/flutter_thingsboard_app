import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_profile_ui_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

/// Resolves isOnline from the combined telemetry + server attribute state.
/// Priority: TB's `active` server attribute > device-published `stt` telemetry.
/// Handles all value types TB may return: bool, int, or String.
bool _resolveOnline(Map<String, dynamic> state) {
  final active = state['active'];
  if (active != null) {
    return active == true || active == 1 || active == 'true';
  }
  final stt = state['stt'];
  if (stt != null) return stt == 1 || stt == true || stt == 'true';
  return false;
}

/// Sets up live subscriptions for a list of devices and emits updated state.
///
/// Subscribes to:
///  - LATEST_TELEMETRY: device metrics (onoff0, dim, temp, …, stt)
///  - SERVER_SCOPE: TB-managed connectivity (`active`)
Stream<List<SmarthomeDevice>> _liveDeviceStream(
  List<SmarthomeDevice> initial,
  void Function(void Function()) onDispose,
) async* {
  if (initial.isEmpty) {
    yield [];
    return;
  }

  // Combined state map: deviceId → {telemetry keys + server attr keys}
  final stateMap = {for (final d in initial) d.id: d};
  // Separate combined data map for online resolution (merges telemetry + server attrs)
  final dataMap = {for (final d in initial) d.id: <String, dynamic>{}};

  final controller = StreamController<List<SmarthomeDevice>>.broadcast();
  onDispose(controller.close);

  final control = DeviceControlService();

  for (final device in initial) {
    // ── Telemetry subscription (latest values: onoff0, dim, temp, stt…) ──
    final telSub = control.subscribeToLatestTelemetry(device.id);
    onDispose(telSub.unsubscribe);

    telSub.attributeDataStream.listen((attrs) {
      for (final a in attrs) {
        dataMap[device.id]![a.key] = a.value;
      }
      final merged = dataMap[device.id]!;
      stateMap[device.id] = stateMap[device.id]!.copyWith(
        isOnline: _resolveOnline(merged),
        telemetry: Map.unmodifiable({
          ...stateMap[device.id]!.telemetry,
          for (final a in attrs) a.key: a.value,
        }),
      );
      if (!controller.isClosed) {
        controller.add(List.unmodifiable(stateMap.values));
      }
    });

    // ── Server attribute subscription (active = TB connectivity status) ──
    final attrSub = control.subscribeToServerAttributes(
      device.id,
      keys: ['active'],
    );
    onDispose(attrSub.unsubscribe);

    attrSub.attributeDataStream.listen((attrs) {
      for (final a in attrs) {
        dataMap[device.id]![a.key] = a.value;
      }
      stateMap[device.id] = stateMap[device.id]!.copyWith(
        isOnline: _resolveOnline(dataMap[device.id]!),
      );
      if (!controller.isClosed) {
        controller.add(List.unmodifiable(stateMap.values));
      }
    });
  }

  yield List.unmodifiable(stateMap.values);
  yield* controller.stream;
}

/// Resolves uiType + profileImage from server attrs and profile info.
Future<List<SmarthomeDevice>> _resolveUiTypes(
    List<SmarthomeDevice> devices) async {
  final svc = DeviceProfileUiService();
  final result = <SmarthomeDevice>[];
  for (final d in devices) {
    final meta = await svc.getUiMeta(d.id, d.deviceProfileId);
    result.add(d.copyWith(
      uiType: meta.uiType,
      profileImage: meta.profileImage,
      // Use device_name from gateway as default label only if no label set yet
      label: (d.label == null || d.label!.isEmpty) ? meta.defaultLabel : null,
    ));
  }
  return result;
}

/// Streams devices in [roomId] with live telemetry + connectivity updates.
final devicesInRoomProvider =
    StreamProvider.family<List<SmarthomeDevice>, String>(
  (ref, roomId) async* {
    final raw = await HomeService().fetchDevicesInRoom(roomId);
    final initial = await _resolveUiTypes(raw);
    yield* _liveDeviceStream(initial, ref.onDispose);
  },
);

/// Streams devices directly under the home asset (gateways + unassigned).
final devicesInHomeProvider =
    StreamProvider.family<List<SmarthomeDevice>, String>(
  (ref, homeId) async* {
    final raw = await HomeService().fetchDevicesInHome(homeId);
    final initial = await _resolveUiTypes(raw);
    yield* _liveDeviceStream(initial, ref.onDispose);
  },
);
