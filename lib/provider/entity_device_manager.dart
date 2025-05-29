import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/utils/services/entity_query_api.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class EntityDeviceManager {
  static EntityDeviceManager? _instance;

  final ThingsboardClient tbClient;
  EntityFilter deviceFilter = EntityTypeFilter(entityType: EntityType.DEVICE);
  PageData<EntityData>? _entityCache;
  bool _isLoading = false;

  EntityDeviceManager._internal(this.tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = EntityDeviceManager._internal(client);

    TbStorage storage = getIt();
    String? jsonString = await storage.getItem('entityDevices') as String?;
    if (jsonString != null) {
      EntityDeviceManager.instance._entityCache =
          parseEntityDataPageData(jsonDecode(jsonString));
    }
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

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return PageData<EntityData>([], 0, 0, false);
    }

    try {
      EntityDataQuery dataQuery =
          EntityQueryApi.createDefaultDeviceQuery(pageSize: 100);

      var entityCache = await tbClient
          .getEntityQueryService()
          .findEntityDataByQuery(dataQuery);

      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString = jsonEncode(PageDataEntityDatatoJson(entityCache));
        storage.setItem('entityDevices', jsonString);
      }
      
      _isLoading = true;
      _entityCache = entityCache;
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

Map<String, dynamic> TsValueToJson(TsValue tsValue) {
  return {
    'ts': tsValue.ts,
    'value': tsValue.value,
  };
}

Map<String, dynamic> ComparisonTsValueToJson(
    ComparisonTsValue comparisonTsValue) {
  return {
    'current': TsValueToJson(comparisonTsValue.current),
    'previous': comparisonTsValue.previous != null
        ? TsValueToJson(comparisonTsValue.previous!)
        : null,
  };
}

Map<String, dynamic> EntityDataToJson(EntityData entityData) {
  return {
    'entityId': entityData.entityId.toJson(),
    'latest': entityData.latest.map((key, value) => MapEntry(
          key.toShortString(),
          value.map((k, v) => MapEntry(k, TsValueToJson(v))),
        )),
    'timeseries': entityData.timeseries.map((key, value) =>
        MapEntry(key, value.map((tsVal) => TsValueToJson(tsVal)).toList())),
    'aggLatest': entityData.aggLatest.map((key, value) =>
        MapEntry(key.toString(), ComparisonTsValueToJson(value))),
  };
}

Map<String, dynamic> PageDataEntityDatatoJson(PageData<EntityData> pageData) {
  return {
    'data': pageData.data.map((dynamic e) => EntityDataToJson(e)).toList(),
    'totalPages': pageData.totalPages,
    'totalElements': pageData.totalElements,
    'hasNext': pageData.hasNext
  };
}
