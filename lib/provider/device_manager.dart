import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class DeviceManager {
  static DeviceManager? _instance;

  final ThingsboardClient tbClient;
  List<DeviceInfo>? _deviceCache;
  bool _isLoading = false;

  DeviceManager._internal(this.tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = DeviceManager._internal(client);
    TbStorage storage = getIt();
    String? jsonString = await storage.getItem('devices') as String?;
    if (jsonString != null) {
      DeviceManager.instance._deviceCache = (jsonDecode(jsonString) as List)
          .map((item) => DeviceInfo.fromJson(item))
          .toList();
    }
  }

  static DeviceManager get instance {
    if (_instance == null) {
      throw Exception('DeviceManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  get devices => _deviceCache;

  Future<List<DeviceInfo>> getDevicesAsync({bool forceRefresh = false}) async {
    if (_deviceCache != null && !forceRefresh) {
      return _deviceCache!;
    }

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return [];
    }

    try {
      final customerId = tbClient.getAuthUser()?.customerId;
      if (customerId == null) {
        throw Exception("Không thể xác định customerId hợp lệ.");
      }

      final pageLink = PageLink(200);
      final pageData = await tbClient
          .getDeviceService()
          .getCustomerDeviceInfos(customerId, pageLink);

      var deviceCache = pageData.data;

      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(deviceCache.map((d) => d.toJson()).toList());
        storage.setItem('devices', jsonString);
      }

      _isLoading = true;
      _deviceCache = deviceCache;
      return _deviceCache!;
    } finally {
      _isLoading = false;
    }
  }

  Future<PageData<DeviceInfo>> getDevices(PageLink pageLink) async {
    if (_deviceCache != null) {
      final searchText = pageLink.textSearch?.toLowerCase() ?? '';
      final deviceInfos = _deviceCache!
          .where((deviceInfo) =>
              deviceInfo.name.toLowerCase().contains(searchText))
          .toList();
      return PageData<DeviceInfo>(
        deviceInfos,
        1,
        deviceInfos.length,
        false,
      );
    } else {
      return PageData<DeviceInfo>(
        [],
        0,
        0,
        false,
      );
    }
  }

  DeviceInfo? getDeviceByName(String name) {
    try {
      return _deviceCache?.firstWhere(
        (device) => device.name == name,
      );
    } catch (e) {
      return null;
    }
  }

  DeviceInfo? getDeviceById(String id) {
    try {
      return _deviceCache?.firstWhere(
        (device) => device.id?.id == id,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> refresh() async {
    await getDevicesAsync(forceRefresh: true);
  }

  void clearCache() {
    _deviceCache = null;
  }
}
