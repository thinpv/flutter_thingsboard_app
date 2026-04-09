import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:thingsboard_app/constants/app_constants.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class HomeService {
  HomeService()
      : _client = getIt<ITbClientService>().client,
        _middlewareBase = ThingsboardAppConstants.middlewareUrl;

  final ThingsboardClient _client;
  final String _middlewareBase;

  static const _homeType = 'smarthome_home';
  static const _roomType = 'smarthome_room';
  static const _containsRelation = 'Contains';

  // ─── Middleware HTTP helper ──────────────────────────────────────────────────

  /// Returns the current customer JWT — used as Bearer token for middleware.
  String get _bearerToken => _client.getJwtToken() ?? '';

  /// POST / PATCH / DELETE to the middleware.
  Future<Map<String, dynamic>> _mw(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_middlewareBase$path');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_bearerToken',
    };

    late http.Response resp;
    switch (method) {
      case 'POST':
        resp = await http.post(uri, headers: headers,
            body: body != null ? jsonEncode(body) : null);
      case 'PATCH':
        resp = await http.patch(uri, headers: headers,
            body: body != null ? jsonEncode(body) : null);
      case 'DELETE':
        resp = await http.delete(uri, headers: headers);
      default:
        throw ArgumentError('Unsupported method: $method');
    }

    if (resp.statusCode >= 400) {
      final msg = _tryDecodeError(resp.body);
      throw Exception('Middleware $method $path → ${resp.statusCode}: $msg');
    }

    if (resp.body.isEmpty) return {};
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  String _tryDecodeError(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      return m['error'] as String? ?? body;
    } catch (_) {
      return body;
    }
  }

  // ─── Home ───────────────────────────────────────────────────────────────────

  Future<List<SmarthomeHome>> fetchHomes() async {
    final user = await _client.getUserService().getUser();
    final customerId = user.customerId?.id;
    if (customerId == null) return [];

    final pageData = await _client.getAssetService().getCustomerAssetInfos(
          customerId,
          PageLink(100),
          type: _homeType,
        );
    return pageData.data.map(SmarthomeHome.fromAsset).toList();
  }

  Future<SmarthomeHome> createHome(String name) async {
    final result = await _mw('POST', '/assets', body: {
      'name': name,
      'type': _homeType,
    });
    final assetId = (result['id'] as Map<String, dynamic>?)?['id'] as String?;
    if (assetId == null) throw Exception('createHome: no id in response');
    return SmarthomeHome(id: assetId, name: name);
  }

  Future<void> deleteHome(String homeId) async {
    await _mw('DELETE', '/assets/$homeId');
  }

  // ─── Room ───────────────────────────────────────────────────────────────────

  Future<List<SmarthomeRoom>> fetchRooms(String homeId) async {
    final query = AssetSearchQuery(
      parameters: RelationsSearchParameters(
        rootId: homeId,
        rootType: EntityType.ASSET,
      ),
      assetTypes: [_roomType],
      relationType: _containsRelation,
    );
    final assets = await _client.getAssetService().findByQuery(query);
    final rooms = assets
        .map((a) => SmarthomeRoom.fromAsset(a, homeId: homeId))
        .toList();

    // Load icon + order from server attributes in parallel
    await Future.wait(rooms.asMap().entries.map((entry) async {
      final i = entry.key;
      final room = entry.value;
      try {
        final attrs = await getServerAttributes(
          AssetId(room.id),
          ['icon', 'order'],
        );
        if (attrs.isNotEmpty) {
          rooms[i] = room.copyWith(
            icon: attrs['icon'] as String?,
            order: attrs['order'] is int
                ? attrs['order'] as int
                : int.tryParse(attrs['order']?.toString() ?? ''),
          );
        }
      } catch (_) {
        // best-effort: keep room without attributes
      }
    }));

    rooms.sort((a, b) => a.order.compareTo(b.order));
    return rooms;
  }

  Future<SmarthomeRoom> createRoom(
    String homeId,
    String name, {
    String icon = 'living_room',
    int order = 0,
  }) async {
    final result = await _mw('POST', '/assets/$homeId/children', body: {
      'name': name,
      'type': _roomType,
      'attributes': {'icon': icon, 'order': order},
    });
    final assetId = (result['id'] as Map<String, dynamic>?)?['id'] as String?;
    if (assetId == null) throw Exception('createRoom: no id in response');
    return SmarthomeRoom(id: assetId, homeId: homeId, name: name);
  }

  Future<void> deleteRoom(String roomId) async {
    await _mw('DELETE', '/assets/$roomId');
  }

  Future<void> updateRoom(
    String roomId, {
    required String name,
    required String icon,
    required int order,
  }) async {
    await _mw('PATCH', '/assets/$roomId', body: {
      'name': name,
      'attributes': {'icon': icon, 'order': order},
    });
  }

  // ─── Devices ────────────────────────────────────────────────────────────────

  Future<List<SmarthomeDevice>> fetchDevicesInRoom(String roomId) async {
    final relations = await _client.getEntityRelationService().findByFrom(
          AssetId(roomId),
          relationType: _containsRelation,
        );
    final deviceIds = relations
        .where((r) => r.to.entityType == EntityType.DEVICE)
        .map((r) => r.to.id!)
        .toList();
    if (deviceIds.isEmpty) return [];

    final devices =
        await _client.getDeviceService().getDevicesByIds(deviceIds);
    return _attachActiveStatus(devices);
  }

  /// Devices directly under the home asset (gateways, unassigned devices).
  /// These are NOT inside any room — they have a Contains relation from home→device.
  Future<List<SmarthomeDevice>> fetchDevicesInHome(String homeId) async {
    final relations = await _client.getEntityRelationService().findByFrom(
          AssetId(homeId),
          relationType: _containsRelation,
        );
    final deviceIds = relations
        .where((r) => r.to.entityType == EntityType.DEVICE)
        .map((r) => r.to.id!)
        .toList();
    if (deviceIds.isEmpty) return [];

    final devices =
        await _client.getDeviceService().getDevicesByIds(deviceIds);
    return _attachActiveStatus(devices);
  }

  /// Batch-fetch `active` server attribute for [devices] and set initial
  /// [SmarthomeDevice.isOnline] from it. Falls back to false if unavailable.
  Future<List<SmarthomeDevice>> _attachActiveStatus(List<Device> devices) async {
    final result = devices.map(SmarthomeDevice.fromDevice).toList();
    await Future.wait(result.asMap().entries.map((entry) async {
      try {
        final attrs = await _client.getAttributeService().getAttributesByScope(
              DeviceId(entry.value.id),
              'SERVER_SCOPE',
              ['active'],
            );
        final active = attrs.isNotEmpty ? attrs.first.getValue() : null;
        if (active != null) {
          result[entry.key] = entry.value.copyWith(
            isOnline: active == true || active == 1 || active == 'true',
          );
        }
      } catch (_) {
        // Keep default isOnline = false
      }
    }));
    return result;
  }

  /// Moves a device from home-level to a room.
  /// Creates Room→Device relation and removes Home→Device relation.
  Future<void> assignDeviceToRoom(
    String deviceId,
    String roomId,
    String homeId,
  ) async {
    await _client.getEntityRelationService().saveRelation(
          EntityRelation(from: AssetId(roomId), to: DeviceId(deviceId)),
        );
    // Remove the direct home→device relation so it no longer appears as unassigned
    await _client.getEntityRelationService().deleteRelation(
          AssetId(homeId),
          _containsRelation,
          RelationTypeGroup.COMMON,
          DeviceId(deviceId),
        );
  }

  // ─── Attributes (read/write direct to TB) ───────────────────────────────────

  Future<Map<String, dynamic>> getServerAttributes(
    EntityId entityId,
    List<String> keys,
  ) async {
    final entries = await _client.getAttributeService().getAttributesByScope(
          entityId,
          'SERVER_SCOPE',
          keys,
        );
    return {for (final e in entries) e.getKey(): e.getValue()};
  }

  Future<void> saveServerAttributes(
    EntityId entityId,
    Map<String, dynamic> data,
  ) async {
    await _client.getAttributeService().saveEntityAttributesV2(
          entityId,
          'SERVER_SCOPE',
          data,
        );
  }
}
