import 'package:flutter/foundation.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class DeviceControlService {
  DeviceControlService() : _client = getIt<ITbClientService>().client;

  final ThingsboardClient _client;

  // Cache subDeviceId → routing info. gatewayId=null nghĩa device là Gateway
  // hoặc standalone (gửi RPC trực tiếp). gatewayId!=null → wrap qua Gateway,
  // dùng `name` làm field "id" trong payload `controlDevice` vì gateway
  // DeviceManager đánh index theo NAME (xem DeviceManager.cpp:271 — TB Gateway
  // protocol push xuống v1/gateway/rpc đã convert UUID→name; custom RPC
  // không có conversion đó nên app phải tự gửi name).
  // Mapping chỉ đổi khi device bị xoá/đổi tên — rare runtime, cache suốt session.
  static final Map<String, _SubDeviceRouting> _routingCache = {};

  Future<_SubDeviceRouting> _resolveRouting(String deviceId) async {
    final cached = _routingCache[deviceId];
    if (cached != null) return cached;

    String? gwId;
    try {
      final relations = await _client
          .getEntityRelationService()
          .findByTo(DeviceId(deviceId));
      for (final rel in relations) {
        if (rel.from.entityType == EntityType.DEVICE) {
          gwId = rel.from.id;
          break;
        }
      }
    } catch (_) {}

    // Chỉ cần resolve name khi sẽ wrap qua gateway. Gateway/standalone gửi
    // trực tiếp bằng deviceId không cần name.
    String name = deviceId;
    if (gwId != null) {
      try {
        final device = await _client.getDeviceService().getDevice(deviceId);
        if (device != null) name = device.name;
      } catch (_) {}
    }

    final routing = _SubDeviceRouting(gwId, name);
    _routingCache[deviceId] = routing;
    return routing;
  }

  /// Build `data` field cho payload `controlDevice` qua Gateway.
  ///
  /// Gateway-side: handler `setValue` ở RpcDevice.cpp:6 register direct, pass
  /// thẳng `data` vào `device->Do()`. Các method khác (toggle/open/close/stop
  /// + fallback IR/RF) cần `data.method = <name>` để binding tìm đúng action.
  Map<String, dynamic> _wrapDataForGateway(
    String method,
    Map<String, dynamic> params,
  ) {
    if (method == 'setValue') return Map<String, dynamic>.from(params);
    return {...params, 'method': method};
  }

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
  ///
  /// Nếu [deviceId] là sub-device của một Gateway, tự động wrap thành
  /// `controlDevice` RPC gửi tới Gateway (xem COMMUNICATION_PROTOCOL.md mục
  /// "RPC qua Gateway"). Nếu [deviceId] là Gateway/standalone — gửi trực tiếp.
  Future<void> sendOneWayRpc(
    String deviceId,
    String method,
    Map<String, dynamic> params,
  ) async {
    final routing = await _resolveRouting(deviceId);
    if (routing.gatewayId == null) {
      await _client.getDeviceService().handleOneWayDeviceRPCRequest(
            deviceId,
            {'method': method, 'params': params},
          );
      return;
    }
    debugPrint(
        '[RPC→GW oneway] gw=${routing.gatewayId} sub=${routing.name} $method($params)');
    await _client.getDeviceService().handleOneWayDeviceRPCRequest(
          routing.gatewayId!,
          {
            'method': 'controlDevice',
            'params': {
              'id': routing.name,
              'data': _wrapDataForGateway(method, params),
            },
          },
        );
  }

  /// Two-way RPC — awaits the device response.
  /// [timeout] in milliseconds (TB server-side timeout, default 10000).
  ///
  /// Cùng routing rule như [sendOneWayRpc].
  Future<dynamic> sendTwoWayRpc(
    String deviceId,
    String method,
    Map<String, dynamic> params, {
    int? timeout,
  }) async {
    final routing = await _resolveRouting(deviceId);
    if (routing.gatewayId == null) {
      final body = <String, dynamic>{
        'method': method,
        'params': params,
        if (timeout != null) 'timeout': timeout,
      };
      return _client.getDeviceService().handleTwoWayDeviceRPCRequest(
            deviceId,
            body,
          );
    }
    debugPrint(
        '[RPC→GW twoway] gw=${routing.gatewayId} sub=${routing.name} $method($params)');
    final body = <String, dynamic>{
      'method': 'controlDevice',
      'params': {
        'id': routing.name,
        'data': _wrapDataForGateway(method, params),
      },
      if (timeout != null) 'timeout': timeout,
    };
    return _client.getDeviceService().handleTwoWayDeviceRPCRequest(
          routing.gatewayId!,
          body,
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

  // ─── Cache invalidation ─────────────────────────────────────────────────────

  /// Xoá cache routing — gọi khi device bị xoá hoặc đổi tên trên TB để
  /// lần RPC tiếp theo lookup lại.
  static void invalidateRoutingCache(String deviceId) {
    _routingCache.remove(deviceId);
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

class _SubDeviceRouting {
  const _SubDeviceRouting(this.gatewayId, this.name);
  final String? gatewayId;
  final String name;
}
