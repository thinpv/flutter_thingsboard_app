import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class DeviceProfileManager {
  static DeviceProfileManager? _instance;

  final ThingsboardClient tbClient;
  List<DeviceProfileInfo>? _deviceProfileCache;
  bool _isLoading = false;

  DeviceProfileManager._internal(this.tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = DeviceProfileManager._internal(client);
    TbStorage storage = getIt();
    String? jsonString = await storage.getItem('deviceProfiles') as String?;
    if (jsonString != null) {
      // DeviceProfileManager.instance._deviceProfileCache =
      //     (jsonDecode(jsonString) as List)
      //         .map((item) => DeviceProfileInfo.fromJson(item))
      //         .toList();
    }
  }

  static DeviceProfileManager get instance {
    if (_instance == null) {
      throw Exception('DeviceProfileManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  Future<List<DeviceProfileInfo>> getDeviceProfilesAsync(
      {bool forceRefresh = false}) async {
    if (_deviceProfileCache != null && !forceRefresh) {
      return _deviceProfileCache!;
    }

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return [];
    }

    try {
      final pageLink = PageLink(200);
      final pageData = await tbClient
          .getDeviceProfileService()
          .getDeviceProfileInfos(pageLink);

      var deviceProfileCache = pageData.data;
      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(deviceProfileCache.map((d) => d.toJson()).toList());
        storage.setItem('deviceProfiles', jsonString);
      }

      _isLoading = true;
      _deviceProfileCache = deviceProfileCache;
      return _deviceProfileCache!;
    } finally {
      _isLoading = false;
    }
  }

  Future<PageData<DeviceProfileInfo>> getDeviceProfiles(
      PageLink pageLink) async {
    if (_deviceProfileCache != null) {
      final searchText = pageLink.textSearch?.toLowerCase() ?? '';
      final deviceProfileInfos = _deviceProfileCache!
          .where((deviceInfo) =>
              deviceInfo.name.toLowerCase().contains(searchText))
          .toList();
      return PageData<DeviceProfileInfo>(
        deviceProfileInfos,
        1,
        deviceProfileInfos.length,
        false,
      );
    } else {
      return PageData<DeviceProfileInfo>(
        [],
        0,
        0,
        false,
      );
    }
  }

  DeviceProfileInfo? getDeviceProfileByName(String name) {
    try {
      return _deviceProfileCache?.firstWhere(
        (deviceProfile) => deviceProfile.name == name,
      );
    } catch (e) {
      return null;
    }
  }

  DeviceProfileInfo? getDeviceProfileById(String id) {
    try {
      return _deviceProfileCache?.firstWhere(
        (deviceProfile) => deviceProfile.id.id == id,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> refresh() async {
    await getDeviceProfilesAsync(forceRefresh: true);
  }

  void clearCache() {
    _deviceProfileCache = null;
  }
}

extension on DeviceProfileInfo {
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {'id': id};
    return json;
  }
}
