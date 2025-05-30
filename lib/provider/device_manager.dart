import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class DeviceManager {
  static DeviceManager? _instance;

  final ThingsboardClient tbClient;
  PageData<DeviceInfo>? _deviceCache;
  bool _isLoading = false;

  DeviceManager._internal(this.tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = DeviceManager._internal(client);
    try {
      TbStorage storage = getIt();
      String? jsonString = await storage.getItem('devices') as String?;
      if (jsonString != null) {
        List<DeviceInfo> list = (jsonDecode(jsonString) as List)
            .map((item) => DeviceInfo.fromJson(item))
            .toList();
        DeviceManager.instance._deviceCache =
            PageData<DeviceInfo>(list, 1, list.length, false);
      }
    } catch (e) {
      print('Read devices cache err');
    }
  }

  static DeviceManager get instance {
    if (_instance == null) {
      throw Exception('DeviceManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  get devicesPageLink => _deviceCache;
  get devicesList => _deviceCache?.data;

  Future<PageData<DeviceInfo>> getDevicesPageData(
      {PageLink? pageLink, bool forceRefresh = false}) async {
    final searchText = pageLink?.textSearch?.toLowerCase() ?? '';
    if (_deviceCache != null && !forceRefresh) {
      return Future.value(_deviceCache!.filterByName(searchText));
    }

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return Future.value(_deviceCache!);
    }

    try {
      final customerId = tbClient.getAuthUser()?.customerId;
      if (customerId == null) {
        throw Exception("Không thể xác định customerId hợp lệ.");
      }

      pageLink ??= PageLink(200);
      final pageData = await tbClient
          .getDeviceService()
          .getCustomerDeviceInfos(customerId, pageLink);

      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(pageData.data.map((d) => d.toJson()).toList());
        storage.setItem('devices', jsonString);
      }

      _isLoading = true;
      _deviceCache = pageData;
      return pageData;
    } finally {
      _isLoading = false;
    }
  }

  Future<List<DeviceInfo>> getDevicesList({bool forceRefresh = false}) async {
    await getDevicesPageData(forceRefresh: forceRefresh);
    return _deviceCache?.data ?? [];
  }

  DeviceInfo? getDeviceByName(String name) {
    try {
      return _deviceCache?.data.firstWhere(
        (device) => device.name == name,
      );
    } catch (e) {
      return null;
    }
  }

  DeviceInfo? getDeviceById(String id) {
    try {
      return _deviceCache?.data.firstWhere(
        (device) => device.id?.id == id,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> refresh() async {
    await getDevicesPageData(forceRefresh: true);
  }

  void clearCache() {
    _deviceCache = null;
  }
}

extension on PageData<DeviceInfo> {
  PageData<DeviceInfo> filterByName(String searchText) {
    final filtered = data
        .where(
            (deviceInfo) => deviceInfo.name.toLowerCase().contains(searchText))
        .toList();
    return PageData<DeviceInfo>(filtered, 1, filtered.length, false);
  }
}
