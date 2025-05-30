import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class DeviceProfileManager {
  static DeviceProfileManager? _instance;

  final ThingsboardClient tbClient;
  PageData<DeviceProfileInfo>? _deviceProfileCache;
  bool _isLoading = false;

  DeviceProfileManager._internal(this.tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = DeviceProfileManager._internal(client);
    try {
      TbStorage storage = getIt();
      String? jsonString = await storage.getItem('deviceProfiles') as String?;
      if (jsonString != null) {
        List<DeviceProfileInfo> list = (jsonDecode(jsonString) as List)
            .map((item) => DeviceProfileInfo.fromJson(item))
            .toList();
        DeviceProfileManager.instance._deviceProfileCache =
            PageData<DeviceProfileInfo>(list, 1, list.length, false);
      }
    } catch (e) {
      print('Read deviceProfiles cache err');
    }
  }

  static DeviceProfileManager get instance {
    if (_instance == null) {
      throw Exception('DeviceProfileManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  get deviceProfilesPageLink => _deviceProfileCache;
  get deviceProfilesList => _deviceProfileCache?.data;

  Future<PageData<DeviceProfileInfo>> getDeviceProfilesPageData(
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
      final pageData = await tbClient
          .getDeviceProfileService()
          .getDeviceProfileInfos(pageLink);

      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(pageData.data.map((d) => d.toJson()).toList());
        storage.setItem('deviceProfiles', jsonString);
      }

      _isLoading = true;
      _deviceProfileCache = pageData;
      return pageData;
    } finally {
      _isLoading = false;
    }
  }

  Future<List<DeviceProfileInfo>> getDeviceProfilesList(
      {bool forceRefresh = false}) async {
    await getDeviceProfilesPageData(forceRefresh: forceRefresh);
    return _deviceProfileCache?.data ?? [];
  }

  DeviceProfileInfo? getDeviceProfileByName(String name) {
    try {
      return _deviceProfileCache?.data.firstWhere(
        (deviceProfile) => deviceProfile.name == name,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  DeviceProfileInfo? getDeviceProfileById(String id) {
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
    await getDeviceProfilesPageData(forceRefresh: true);
  }

  void clearCache() {
    _deviceProfileCache = null;
  }
}

extension on EntityId {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType.toString().split('.').last,
    };
  }
}

extension on DeviceProfileInfo {
  Map<String, dynamic> toJson() {
    return {
      'id': id.toJson(),
      'name': name,
      'type': type.toShortString(),
      'transportType': transportType.toShortString(),
      'defaultDashboardId': defaultDashboardId?.toJson(),
      'image': image,
      'tenantId': tenantId.toJson(),
    };
  }
}

extension on PageData<DeviceProfileInfo> {
  PageData<DeviceProfileInfo> filterByName(String searchText) {
    final filtered = data
        .where((deviceProfileInfo) =>
            deviceProfileInfo.name.toLowerCase().contains(searchText))
        .toList();
    return PageData<DeviceProfileInfo>(filtered, 1, filtered.length, false);
  }
}
