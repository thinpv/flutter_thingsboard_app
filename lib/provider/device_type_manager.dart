import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/model/device_type_models.dart';
import 'package:thingsboard_app/service/device_type_service.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class DeviceTypeManager {
  static DeviceTypeManager? _instance;

  final ThingsboardClient tbClient;
  PageData<DeviceTypeInfo>? _deviceProfileCache;
  bool _isLoading = false;

  DeviceTypeManager._internal(this.tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = DeviceTypeManager._internal(client);
    try {
      TbStorage storage = getIt();
      String? jsonString = await storage.getItem('deviceTypes') as String?;
      if (jsonString != null) {
        List<DeviceTypeInfo> list = (jsonDecode(jsonString) as List)
            .map((item) => DeviceTypeInfo.fromJson(item))
            .toList();
        DeviceTypeManager.instance._deviceProfileCache =
            PageData<DeviceTypeInfo>(list, 1, list.length, false);
      }
    } catch (e) {
      print('Read deviceProfiles cache err');
    }
  }

  static DeviceTypeManager get instance {
    if (_instance == null) {
      throw Exception('DeviceTypeManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  get deviceProfilesPageLink => _deviceProfileCache;
  get deviceProfilesList => _deviceProfileCache?.data;

  Future<PageData<DeviceTypeInfo>> getDeviceTypesPageData(
      {PageLink? pageLink, bool forceRefresh = false}) async {
    final searchText = pageLink?.textSearch?.toLowerCase() ?? '';
    if (_deviceProfileCache != null && !forceRefresh) {
      return Future.value(_deviceProfileCache!.filterByName(searchText));
    }

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return Future.value(_deviceProfileCache!);
    }

    try {
      pageLink ??= PageLink(200);
      final pageData =
          await DeviceTypeService.instance.getDeviceTypeInfos(pageLink);

      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(pageData.data.map((d) => d.toJson()).toList());
        storage.setItem('deviceTypes', jsonString);
      }

      _isLoading = true;
      _deviceProfileCache = pageData;
      return pageData;
    } finally {
      _isLoading = false;
    }
  }

  Future<List<DeviceTypeInfo>> getDeviceTypesList(
      {bool forceRefresh = false}) async {
    await getDeviceTypesPageData(forceRefresh: forceRefresh);
    return _deviceProfileCache?.data ?? [];
  }

  DeviceTypeInfo? getDeviceTypeByName(String displayName) {
    try {
      return _deviceProfileCache?.data.firstWhere(
        (deviceProfile) => deviceProfile.displayName == displayName,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  DeviceTypeInfo? getDeviceTypeById(String id) {
    try {
      return _deviceProfileCache?.data.firstWhere(
        (deviceProfile) => deviceProfile.id.id == id,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    await getDeviceTypesPageData(forceRefresh: true);
  }

  void clearCache() {
    _deviceProfileCache = null;
  }
}

extension on PageData<DeviceTypeInfo> {
  PageData<DeviceTypeInfo> filterByName(String searchText) {
    if (searchText.isEmpty) {
      return PageData<DeviceTypeInfo>(data, 1, data.length, false);
    } else {
      final filtered = data
          .where((myDeviceInfoInfo) =>
              myDeviceInfoInfo.displayName
                  ?.toLowerCase()
                  .contains(searchText) ??
              false)
          .toList();
      return PageData<DeviceTypeInfo>(filtered, 1, filtered.length, false);
    }
  }
}
