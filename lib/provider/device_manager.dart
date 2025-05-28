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

  /// Lấy danh sách thiết bị, dùng cache nếu có
  Future<List<DeviceInfo>> getDevices({bool forceRefresh = false}) async {
    if (_deviceCache != null && !forceRefresh) {
      return _deviceCache!;
    }

    if (_isLoading) {
      // Nếu đang loading song song, đợi một chút
      await Future.delayed(Duration(milliseconds: 300));
      return _deviceCache ?? [];
    }

    _isLoading = true;
    try {
      final customerId = tbClient.getAuthUser()?.customerId;
      if (customerId == null) {
        throw Exception("Không thể xác định customerId hợp lệ.");
      }

      final pageLink =
          PageLink(100); // hoặc tuỳ chỉnh phân trang nếu nhiều thiết bị
      final pageData = await tbClient
          .getDeviceService()
          .getCustomerDeviceInfos(customerId, pageLink);

      _deviceCache = pageData.data;

      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(_deviceCache?.map((d) => d.toJson()).toList());
        storage.setItem('devices', jsonString);
      }
      return _deviceCache!;
    } finally {
      _isLoading = false;
    }
  }

  Future<PageData<DeviceInfo>> getDeviceInfos(PageLink pageLink) async {
    if (_deviceCache != null) {
      final deviceInfos = _deviceCache!;
      return PageData<DeviceInfo>(
        deviceInfos,
        1,
        deviceInfos.length,
        false,
      );
    } else {
      return PageData<DeviceInfo>(
        [],
        1,
        0,
        false,
      );
    }
  }

  Future<DeviceInfo?> getDeviceByName(String name) async {
    if (_deviceCache == null) await getDevices();
    try {
      return _deviceCache?.firstWhere(
        (device) => device.name == name,
      );
    } catch (e) {
      return null;
    }
  }

  Future<DeviceInfo?> getDeviceById(String id) async {
    if (_deviceCache == null) await getDevices();
    try {
      return _deviceCache?.firstWhere(
        (device) => device.id?.id == id,
      );
    } catch (e) {
      return null;
    }
  }

  /// Làm mới cache
  Future<void> refresh() async {
    await getDevices(forceRefresh: true);
  }

  /// Xoá cache thủ công nếu cần
  void clearCache() {
    _deviceCache = null;
  }
}
