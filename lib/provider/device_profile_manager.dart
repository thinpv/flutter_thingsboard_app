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

  Future<List<DeviceProfileInfo>> getDeviceProfiles(
      {bool forceRefresh = false}) async {
    if (_deviceProfileCache != null && !forceRefresh) {
      return _deviceProfileCache!;
    }

    if (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _deviceProfileCache ?? [];
    }

    _isLoading = true;
    try {
      final pageLink =
          PageLink(100); // hoặc tuỳ chỉnh phân trang nếu nhiều thiết bị
      final pageData = await tbClient
          .getDeviceProfileService()
          .getDeviceProfileInfos(pageLink);

      _deviceProfileCache = pageData.data;
      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(_deviceProfileCache?.map((d) => d.toJson()).toList());
        storage.setItem('deviceProfiles', jsonString);
      }
      return _deviceProfileCache!;
    } finally {
      _isLoading = false;
    }
  }

  DeviceProfileInfo? getDeviceProfileByName(String name) {
    if (_deviceProfileCache == null) return null;
    try {
      return _deviceProfileCache?.firstWhere(
        (deviceProfile) => deviceProfile.name == name,
      );
    } catch (e) {
      return null;
    }
  }

  DeviceProfileInfo? getDeviceProfileById(String id) {
    if (_deviceProfileCache == null) return null;
    try {
      return _deviceProfileCache?.firstWhere(
        (deviceProfile) => deviceProfile.id.id == id,
      );
    } catch (e) {
      return null;
    }
  }

  /// Làm mới cache
  Future<void> refresh() async {
    await getDeviceProfiles(forceRefresh: true);
  }

  /// Xoá cache thủ công nếu cần
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
