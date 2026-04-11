import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';

/// Provider trả về instance [DeviceControlService].
/// Dùng bởi ToggleTile, SliderTile để gửi lệnh điều khiển.
final deviceControlServiceProvider = Provider<DeviceControlService>((ref) {
  return DeviceControlService();
});

/// Stream toàn bộ telemetry (Map<key, value>) của một device, real-time qua WebSocket.
///
/// Mỗi deviceId có duy nhất một subscription — nhiều tile trong cùng trang
/// detail share subscription này, không tạo thêm WS cmd.
///
/// Stream phát ra snapshot mới mỗi khi TB gửi update (partial update được
/// merge vào map tích luỹ nên snapshot luôn chứa toàn bộ keys đã nhận).
final deviceTelemetryProvider =
    StreamProvider.family<Map<String, dynamic>, String>(
  (ref, deviceId) async* {
    if (deviceId.isEmpty) return;

    final telemetry = <String, dynamic>{};
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    final control = DeviceControlService();
    final sub = control.subscribeToLatestTelemetry(deviceId);

    sub.attributeDataStream.listen((attrs) {
      for (final a in attrs) {
        telemetry[a.key] = a.value;
      }
      if (!controller.isClosed) {
        controller.add(Map.unmodifiable(Map.from(telemetry)));
      }
    });

    ref.onDispose(() {
      sub.unsubscribe();
      controller.close();
    });

    yield* controller.stream;
  },
);

/// Giá trị real-time của một key cụ thể trên một device.
///
/// Là derived provider từ [deviceTelemetryProvider] — share cùng subscription.
///
/// Usage:
/// ```dart
/// final valueAsync = ref.watch(deviceStateProvider((deviceId, 'onoff0')));
/// valueAsync.when(
///   data: (v) => Text('$v'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Lỗi: $e'),
/// );
/// ```
final deviceStateProvider =
    Provider.family<AsyncValue<dynamic>, (String, String)>(
  (ref, args) {
    final (deviceId, stateKey) = args;
    return ref
        .watch(deviceTelemetryProvider(deviceId))
        .whenData((map) => map[stateKey]);
  },
);
