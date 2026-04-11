import 'package:flutter/foundation.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class DeviceControlService {
  DeviceControlService() : _client = getIt<ITbClientService>().client;

  final ThingsboardClient _client;

  // ─── High-level helpers ─────────────────────────────────────────────────────

  /// Đặt giá trị một key bằng RPC `setValue`.
  ///
  /// Đây là command dùng bởi ToggleTile, SliderTile khi [StateDef.controllable].
  /// Gateway nhận params `{key: value}` và dispatch tới đúng ZCL attribute.
  Future<void> setValue(String deviceId, String key, dynamic value) {
    return sendOneWayRpc(deviceId, 'setValue', {key: value});
  }

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

  /// Fetch historical timeseries for [deviceId]. Values are returned
  /// oldest-first. Pass [agg] + [interval] for downsampling (e.g. daily max).
  ///
  /// Returns a map keyed by telemetry key → list of `(ts, value)` tuples.
  /// Values come through as [num] (TB REST API converts correctly with
  /// strict data types).
  Future<Map<String, List<(int, num)>>> fetchTimeseries(
    String deviceId,
    List<String> keys, {
    required int startTs,
    required int endTs,
    int? interval,
    Aggregation agg = Aggregation.NONE,
    int limit = 1000,
  }) async {
    try {
      final entries = await _client.getAttributeService().getTimeseries(
            DeviceId(deviceId),
            keys,
            startTime: startTs,
            endTime: endTs,
            interval: interval,
            agg: agg,
            limit: limit,
            sortOrder: Direction.ASC,
          );
      final result = <String, List<(int, num)>>{};
      for (final e in entries) {
        final raw = e.getValue();
        final n = raw is num
            ? raw
            : (raw is String ? num.tryParse(raw) : null);
        if (n == null) continue;
        (result[e.getKey()] ??= []).add((e.getTs(), n));
      }
      debugPrint(
          '[fetchTimeseries] dev=$deviceId keys=$keys → ${result.map((k, v) => MapEntry(k, '${v.length} pts'))}');
      return result;
    } catch (e, st) {
      debugPrint('[fetchTimeseries] FAILED dev=$deviceId keys=$keys: $e\n$st');
      return {};
    }
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
