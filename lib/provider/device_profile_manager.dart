import 'package:thingsboard_client/thingsboard_client.dart';

class DeviceProfileManager {
  static DeviceProfileManager? _instance;

  final ThingsboardClient tbClient;
  List<DeviceProfileInfo>? _deviceProfileCache;
  bool _isLoading = false;

  DeviceProfileManager._internal(this.tbClient);

  static void init(ThingsboardClient client) {
    _instance = DeviceProfileManager._internal(client);
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
      return _deviceProfileCache!;
    } finally {
      _isLoading = false;
    }
  }

  Future<DeviceProfileInfo?> getDeviceProfileByName(String name) async {
    if (_deviceProfileCache == null) await getDeviceProfiles();
    try {
      return _deviceProfileCache?.firstWhere(
        (deviceProfile) => deviceProfile.name == name,
      );
    } catch (e) {
      return null;
    }
  }

  Future<DeviceProfileInfo?> getDeviceProfileById(String id) async {
    if (_deviceProfileCache == null) await getDeviceProfiles();
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
