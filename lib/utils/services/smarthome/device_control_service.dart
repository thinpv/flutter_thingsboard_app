import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class DeviceControlService {
  DeviceControlService() : _client = getIt<ITbClientService>().client;

  final ThingsboardClient _client;

  // ─── RPC ────────────────────────────────────────────────────────────────────

  /// Fire-and-forget command (e.g. toggle, setPosition).
  Future<void> sendOneWayRpc(
    String deviceId,
    String method,
    Map<String, dynamic> params,
  ) async {
    await _client.getDeviceService().handleOneWayDeviceRPCRequest(
          deviceId,
          {'method': method, 'params': params},
        );
  }

  /// Two-way RPC — awaits the device response.
  Future<dynamic> sendTwoWayRpc(
    String deviceId,
    String method,
    Map<String, dynamic> params,
  ) {
    return _client.getDeviceService().handleTwoWayDeviceRPCRequest(
          deviceId,
          {'method': method, 'params': params},
        );
  }

  // ─── Telemetry WebSocket ─────────────────────────────────────────────────────

  /// Subscribes to the latest telemetry of [deviceId].
  ///
  /// Returns a [TelemetrySubscriber] — caller must call [TelemetrySubscriber.unsubscribe]
  /// when done (e.g. in widget dispose or provider onDispose).
  ///
  /// Listen on [subscriber.attributeDataStream] for updates:
  /// ```dart
  /// subscriber.attributeDataStream.listen((attrs) {
  ///   final telemetry = {for (final a in attrs) a.key: a.value};
  /// });
  /// ```
  TelemetrySubscriber subscribeToLatestTelemetry(
    String deviceId, {
    List<String>? keys,
  }) {
    final entityId = DeviceId(deviceId);
    final subscriber = TelemetrySubscriber.createEntityAttributesSubscription(
      telemetryService: _client.getTelemetryService(),
      entityId: entityId,
      attributeScope: LatestTelemetry.LATEST_TELEMETRY.toShortString(),
      keys: keys,
    );
    subscriber.subscribe();
    return subscriber;
  }

  /// Subscribes to SERVER_SCOPE attributes of [deviceId].
  /// Useful for tracking TB-managed `active` connectivity status.
  TelemetrySubscriber subscribeToServerAttributes(
    String deviceId, {
    List<String>? keys,
  }) {
    final entityId = DeviceId(deviceId);
    final subscriber = TelemetrySubscriber.createEntityAttributesSubscription(
      telemetryService: _client.getTelemetryService(),
      entityId: entityId,
      attributeScope: AttributeScope.SERVER_SCOPE.toShortString(),
      keys: keys,
    );
    subscriber.subscribe();
    return subscriber;
  }
}
