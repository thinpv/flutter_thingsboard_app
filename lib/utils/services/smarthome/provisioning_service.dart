import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class ProvisioningService {
  ProvisioningService()
      : _client = getIt<ITbClientService>().client,
        _control = DeviceControlService();

  final ThingsboardClient _client;
  final DeviceControlService _control;

  static const _containsRelation = 'Contains';

  // ─── Gateway discovery ────────────────────────────────────────────────────

  /// Returns gateway devices that are directly related to the home asset.
  /// In the data model, gateways are attached via Contains relation from Home.
  Future<List<SmarthomeDevice>> fetchGatewayDevices(String homeId) async {
    final relations = await _client.getEntityRelationService().findByFrom(
          AssetId(homeId),
          relationType: _containsRelation,
        );
    final deviceIds = relations
        .where((r) => r.to.entityType == EntityType.DEVICE)
        .map((r) => r.to.id!)
        .toList();
    if (deviceIds.isEmpty) return [];
    final devices = await _client.getDeviceService().getDevicesByIds(deviceIds);
    return devices
        .where((d) => d.type.toLowerCase().contains('gateway'))
        .map(SmarthomeDevice.fromDevice)
        .toList();
  }

  // ─── Pairing RPC ─────────────────────────────────────────────────────────

  /// Sends start_pairing RPC to gateway. Resolves when gateway acknowledges.
  Future<void> startPairing(
    String gatewayId, {
    String? deviceType,
    int timeoutSeconds = 60,
  }) async {
    await _control.sendTwoWayRpc(
      gatewayId,
      'start_pairing',
      {
        if (deviceType != null) 'device_type': deviceType,
        'timeout_seconds': timeoutSeconds,
      },
    );
  }

  /// Sends stop_pairing RPC to gateway.
  Future<void> stopPairing(String gatewayId) async {
    await _control.sendTwoWayRpc(gatewayId, 'stop_pairing', {});
  }

  // ─── Sub-device discovery ─────────────────────────────────────────────────

  /// Returns all sub-devices currently registered under the gateway.
  /// ThingsBoard creates a Contains relation from gateway to sub-device
  /// when the gateway connects the device via v1/gateway/connect.
  Future<List<SmarthomeDevice>> fetchSubDevices(String gatewayId) async {
    final relations = await _client.getEntityRelationService().findByFrom(
          DeviceId(gatewayId),
          relationType: _containsRelation,
        );
    final deviceIds = relations
        .where((r) => r.to.entityType == EntityType.DEVICE)
        .map((r) => r.to.id!)
        .toList();
    if (deviceIds.isEmpty) return [];
    final devices = await _client.getDeviceService().getDevicesByIds(deviceIds);
    return devices.map(SmarthomeDevice.fromDevice).toList();
  }

  // ─── Room assignment ──────────────────────────────────────────────────────

  /// Creates a Contains relation from [roomId] to [deviceId].
  Future<void> assignToRoom(String deviceId, String roomId) async {
    await _client.getEntityRelationService().saveRelation(
          EntityRelation(
            from: AssetId(roomId),
            to: DeviceId(deviceId),
            type: _containsRelation,
          ),
        );
  }
}
