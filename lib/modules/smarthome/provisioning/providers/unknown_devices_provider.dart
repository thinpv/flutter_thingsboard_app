import 'dart:async';
import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

// ─── Domain ───────────────────────────────────────────────────────────────────

/// Một thiết bị chưa được nhận dạng mà gateway đã phát hiện.
class UnknownDevice {
  const UnknownDevice({
    required this.gatewayId,
    required this.fingerprint,
    required this.detectedAt,
    this.protocol,
    this.address,
  });

  factory UnknownDevice.fromJson(
    Map<String, dynamic> json,
    String gatewayId,
    int ts,
  ) {
    return UnknownDevice(
      gatewayId: gatewayId,
      fingerprint: json['fp'] as String? ??
          json['fingerprint'] as String? ??
          json['addr'] as String? ??
          '',
      detectedAt: DateTime.fromMillisecondsSinceEpoch(
        json['ts'] as int? ?? ts,
      ),
      protocol: json['proto'] as String? ?? json['protocol'] as String?,
      address: json['addr'] as String?,
    );
  }

  /// ID của gateway đã phát hiện thiết bị này.
  final String gatewayId;

  /// Chuỗi định danh duy nhất (MAC, IEEE addr, mã serial…).
  final String fingerprint;

  /// Thời điểm phát hiện.
  final DateTime detectedAt;

  /// Giao thức: 'ble', 'zigbee', 'ir', ...
  final String? protocol;

  /// Địa chỉ vật lý (MAC, short addr…).
  final String? address;
}

// ─── Provider ────────────────────────────────────────────────────────────────

/// Stream danh sách [UnknownDevice] từ tất cả gateway trong nhà hiện tại.
///
/// Gateway gửi telemetry key `unknown_device` dạng JSON array mỗi khi phát
/// hiện thiết bị mới không có trong database:
/// ```json
/// [{"fp":"AA:BB:CC", "proto":"zigbee", "ts":1710001234567}, ...]
/// ```
///
/// Provider này subscribe [devicesInHomeProvider] để lấy list gateway (type
/// có `gateway` trong uiType), rồi subscribe telemetry `unknown_device` trên
/// mỗi gateway và merge kết quả.
final unknownDevicesProvider =
    StreamProvider<List<UnknownDevice>>((ref) async* {
  // Lấy home hiện tại
  final homeAsync = ref.watch(selectedHomeProvider);
  final home = homeAsync.valueOrNull;
  if (home == null) {
    yield [];
    return;
  }

  // Lấy danh sách gateway devices trong home
  final svc = HomeService();
  List<String> gatewayIds;
  try {
    final devices = await svc.fetchDevicesInHome(home.id);
    gatewayIds = devices
        .where((d) =>
            d.effectiveUiType == 'gateway' || d.type == 'gateway')
        .map((d) => d.id)
        .toList();
  } catch (_) {
    yield [];
    return;
  }

  if (gatewayIds.isEmpty) {
    yield [];
    return;
  }

  // Subscribe `unknown_device` telemetry trên từng gateway
  final control = DeviceControlService();
  final subscriptions = <dynamic>[];
  final controller = StreamController<List<UnknownDevice>>.broadcast();

  // Accumulate latest list per gateway
  final latest = <String, List<UnknownDevice>>{};

  void emit() {
    if (!controller.isClosed) {
      controller.add(
        latest.values.expand((l) => l).toList()
          ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt)),
      );
    }
  }

  for (final gwId in gatewayIds) {
    final sub = control.subscribeToLatestTelemetry(
      gwId,
      keys: ['unknown_device'],
    );
    subscriptions.add(sub);
    sub.attributeDataStream.listen((attrs) {
      for (final a in attrs) {
        if (a.key != 'unknown_device') continue;
        final raw = a.value;
        if (raw == null) {
          latest[gwId] = [];
          emit();
          continue;
        }
        try {
          final decoded = raw is String ? jsonDecode(raw) : raw;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (decoded is List) {
            latest[gwId] = decoded
                .whereType<Map<String, dynamic>>()
                .map((j) => UnknownDevice.fromJson(j, gwId, now))
                .where((d) => d.fingerprint.isNotEmpty)
                .toList();
          } else {
            latest[gwId] = [];
          }
        } catch (_) {
          latest[gwId] = [];
        }
        emit();
      }
    });
  }

  ref.onDispose(() {
    for (final s in subscriptions) {
      try {
        s.unsubscribe();
      } catch (_) {}
    }
    controller.close();
  });

  yield* controller.stream;
});

// ─── Retry RPC ────────────────────────────────────────────────────────────────

/// Gửi RPC `retryPending` đến gateway để yêu cầu thử lại nhận dạng các
/// thiết bị đang chờ. Gọi sau khi người dùng đã thêm device profile mới.
Future<void> retryPendingDevices(String gatewayId) {
  return DeviceControlService().sendOneWayRpc(gatewayId, 'retryPending', {});
}
