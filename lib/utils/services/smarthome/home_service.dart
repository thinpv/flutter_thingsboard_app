import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class HomeService {
  HomeService() : _client = getIt<ITbClientService>().client;

  final ThingsboardClient _client;

  static const _homeType = 'smarthome_home';
  static const _roomType = 'smarthome_room';
  static const _containsRelation = 'Contains';

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
    final user = await _client.getUserService().getUser();
    final customerId = user.customerId?.id;

    final asset = Asset(name, _homeType);
    final saved = await _client.getAssetService().saveAsset(asset);
    if (customerId != null) {
      await _client
          .getAssetService()
          .assignAssetToCustomer(customerId, saved.id!.id!);
    }
    return SmarthomeHome(id: saved.id!.id!, name: saved.name);
  }

  Future<void> deleteHome(String homeId) async {
    await _client.getAssetService().deleteAsset(homeId);
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
    return assets
        .map((a) => SmarthomeRoom.fromAsset(a, homeId: homeId))
        .toList();
  }

  Future<SmarthomeRoom> createRoom(String homeId, String name) async {
    final user = await _client.getUserService().getUser();
    final customerId = user.customerId?.id;

    final asset = Asset(name, _roomType);
    final saved = await _client.getAssetService().saveAsset(asset);
    if (customerId != null) {
      await _client
          .getAssetService()
          .assignAssetToCustomer(customerId, saved.id!.id!);
    }
    // Create Contains relation: Home → Room
    await _client.getEntityRelationService().saveRelation(
          EntityRelation(
            from: AssetId(homeId),
            to: saved.id!,
            type: _containsRelation,
          ),
        );
    return SmarthomeRoom(id: saved.id!.id!, homeId: homeId, name: saved.name);
  }

  Future<void> deleteRoom(String roomId) async {
    await _client.getAssetService().deleteAsset(roomId);
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
    return devices.map(SmarthomeDevice.fromDevice).toList();
  }

  // ─── Attributes ─────────────────────────────────────────────────────────────

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

  Future<Map<String, dynamic>> getSharedAttributes(
    EntityId entityId,
    List<String> keys,
  ) async {
    final entries = await _client.getAttributeService().getAttributesByScope(
          entityId,
          'SHARED_SCOPE',
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

  Future<void> saveSharedAttributes(
    EntityId entityId,
    Map<String, dynamic> data,
  ) async {
    await _client.getAttributeService().saveEntityAttributesV2(
          entityId,
          'SHARED_SCOPE',
          data,
        );
  }
}
