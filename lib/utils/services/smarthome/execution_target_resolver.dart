import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/smarthome/provisioning_service.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

/// Resolves [execution_target] for an automation rule based on the devices involved.
///
/// Rules:
/// - All devices on the SAME gateway → `"gw:{gatewayId}"`
/// - Devices span multiple gateways OR any device has no gateway → `"server"`
///
/// Implementation note: we enumerate gateways in the customer and walk each
/// gateway's sub-device list forward (`findByFrom`). Going forward is robust
/// against TB auto-creating the gateway→sub-device relation with different
/// types (`Contains` vs `Created`) depending on how the device was registered.
class ExecutionTargetResolver {
  ExecutionTargetResolver()
      : _client = getIt<ITbClientService>().client,
        _provisioning = ProvisioningService();

  final ThingsboardClient _client;
  final ProvisioningService _provisioning;

  /// Given a list of device IDs (from conditions + actions), returns the
  /// appropriate execution_target string. [homeId] scopes gateway discovery.
  Future<String> resolve(List<String> deviceIds, {String? homeId}) async {
    if (deviceIds.isEmpty) return 'server';
    final unique = deviceIds.toSet();

    final deviceToGateway = await _buildDeviceToGatewayMap(homeId: homeId);

    String? commonGatewayId;
    for (final deviceId in unique) {
      final gatewayId = deviceToGateway[deviceId];
      if (gatewayId == null) return 'server';
      if (commonGatewayId == null) {
        commonGatewayId = gatewayId;
      } else if (commonGatewayId != gatewayId) {
        return 'server';
      }
    }
    return commonGatewayId != null ? 'gw:$commonGatewayId' : 'server';
  }

  /// Builds `{ subDeviceId → gatewayId }` by listing every gateway in the
  /// customer scope and walking each one's forward relations.
  Future<Map<String, String>> _buildDeviceToGatewayMap({String? homeId}) async {
    final map = <String, String>{};
    final gateways = await _provisioning.fetchGatewayDevices(homeId ?? '');
    for (final gw in gateways) {
      try {
        final relations = await _client.getEntityRelationService().findByFrom(
              DeviceId(gw.id),
            );
        for (final rel in relations) {
          if (rel.to.entityType != EntityType.DEVICE) continue;
          final subId = rel.to.id;
          if (subId == null || subId == gw.id) continue;
          map.putIfAbsent(subId, () => gw.id);
        }
      } catch (_) {}
    }
    return map;
  }
}
