import 'package:thingsboard_client/thingsboard_client.dart';

class DeviceManager {
  static DeviceManager? _instance;

  final ThingsboardClient tbClient;
  List<DeviceInfo>? _deviceCache;
  bool _isLoading = false;

  DeviceManager._internal(this.tbClient);

  static void init(ThingsboardClient client) {
    _instance = DeviceManager._internal(client);
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
      return _deviceCache!;
    } finally {
      _isLoading = false;
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
