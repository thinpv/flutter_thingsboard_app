import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

/// Resolves [execution_target] for an automation rule based on the devices involved.
///
/// Rules:
/// - All devices on the SAME gateway → `"gw:{gatewayId}"`
/// - Devices span multiple gateways OR any device has no gateway → `"server"`
class ExecutionTargetResolver {
  ExecutionTargetResolver() : _client = getIt<ITbClientService>().client;

  final ThingsboardClient _client;

  static const _containsRelation = 'Contains';

  /// Given a list of device IDs (from conditions + actions), returns the
  /// appropriate execution_target string.
  Future<String> resolve(List<String> deviceIds) async {
    if (deviceIds.isEmpty) return 'server';

    final unique = deviceIds.toSet().toList();
    String? commonGatewayId;

    for (final deviceId in unique) {
      final gatewayId = await _findGatewayForDevice(deviceId);
      if (gatewayId == null) {
        // Device has no gateway (cloud-only) → server
        return 'server';
      }
      if (commonGatewayId == null) {
        commonGatewayId = gatewayId;
      } else if (commonGatewayId != gatewayId) {
        // Devices span multiple gateways → server
        return 'server';
      }
    }

    return commonGatewayId != null ? 'gw:$commonGatewayId' : 'server';
  }

  /// Finds the gateway device that owns [deviceId] by traversing the
  /// sub-device relation (a Gateway "Is Gateway" device contains sub-devices).
  ///
  /// ThingsBoard sub-devices are linked from the gateway via a "Contains"
  /// relation FROM the gateway TO the sub-device.
  Future<String?> _findGatewayForDevice(String deviceId) async {
    try {
      // Find entities that have a Contains relation TO this device
      final relations = await _client.getEntityRelationService().findByTo(
            DeviceId(deviceId),
            relationType: _containsRelation,
          );
      for (final rel in relations) {
        if (rel.from.entityType == EntityType.DEVICE) {
          // Verify this is a gateway device by checking profile
          try {
            final gw = await _client.getDeviceService().getDevice(rel.from.id!);
            // Gateway devices have type containing 'gateway' or are Is-Gateway
            if (gw.type.toLowerCase().contains('gateway')) {
              return rel.from.id!;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return null;
  }
}
