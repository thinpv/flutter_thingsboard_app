import 'package:thingsboard_app/modules/device/devices_list_base.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class EntityDeviceManager {
  static EntityDeviceManager? _instance;

  final ThingsboardClient tbClient;
  EntityFilter deviceFilter = EntityTypeFilter(entityType: EntityType.DEVICE);
  PageData<EntityData>? _entityCache;
  bool _isLoading = false;

  EntityDeviceManager._internal(this.tbClient);

  static void init(ThingsboardClient client) {
    _instance = EntityDeviceManager._internal(client);
  }

  static EntityDeviceManager get instance {
    if (_instance == null) {
      throw Exception('EntityDeviceManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  /// Lấy danh sách thiết bị, dùng cache nếu có
  Future<PageData<EntityData>> getDevices({bool forceRefresh = false}) async {
    if (_entityCache != null && !forceRefresh) {
      return _entityCache!;
    }

    if (_isLoading) {
      // Nếu đang loading song song, đợi một chút
      await Future.delayed(const Duration(milliseconds: 300));
      return _entityCache ?? PageData<EntityData>([], 0, 0, false);
    }

    _isLoading = true;
    try {
      DeviceQueryController _deviceQueryController =
          DeviceQueryController(pageSize: 100);

      _entityCache = await tbClient
          .getEntityQueryService()
          .findEntityDataByQuery(_deviceQueryController.value.pageKey);

      return _entityCache!;
    } finally {
      _isLoading = false;
    }
  }

  Future<EntityData?> getDeviceByName(String name) async {
    if (_entityCache == null) await getDevices();
    try {
      if (_entityCache != null) {
        for (EntityData entityData in _entityCache!.data) {
          if (entityData.field('name') == name) {
            return entityData;
          }
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<EntityData?> getDeviceById(String id) async {
    if (_entityCache == null) await getDevices();
    try {
      if (_entityCache != null) {
        for (EntityData entityData in _entityCache!.data) {
          if (entityData.entityId == id) {
            return entityData;
          }
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Làm mới cache
  Future<void> refresh() async {
    await getDevices(forceRefresh: true);
  }

  /// Xoá cache thủ công nếu cần
  void clearCache() {
    _entityCache = null;
  }
}
