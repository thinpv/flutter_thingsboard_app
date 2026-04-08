import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

/// Streams [SmarthomeDevice] list for [roomId] with live telemetry updates.
///
/// Each telemetry update from any device in the room causes a new list emission.
final devicesInRoomProvider =
    StreamProvider.family<List<SmarthomeDevice>, String>(
  (ref, roomId) async* {
    final initial = await HomeService().fetchDevicesInRoom(roomId);
    if (initial.isEmpty) {
      yield [];
      return;
    }

    // Mutable map: deviceId → latest device state
    final stateMap = {for (final d in initial) d.id: d};
    final controller = StreamController<List<SmarthomeDevice>>.broadcast();
    ref.onDispose(controller.close);

    final control = DeviceControlService();
    for (final device in initial) {
      final subscriber = control.subscribeToLatestTelemetry(device.id);
      ref.onDispose(subscriber.unsubscribe);

      subscriber.attributeDataStream.listen((attrs) {
        final updated = {
          ...stateMap[device.id]!.telemetry,
          for (final a in attrs) a.key: a.value,
        };
        stateMap[device.id] = stateMap[device.id]!.copyWith(
          isOnline: updated['stt'] == 1,
          telemetry: updated,
        );
        if (!controller.isClosed) {
          controller.add(List.unmodifiable(stateMap.values));
        }
      });
    }

    // Emit initial state, then forward WebSocket-driven updates
    yield List.unmodifiable(stateMap.values);
    yield* controller.stream;
  },
);
