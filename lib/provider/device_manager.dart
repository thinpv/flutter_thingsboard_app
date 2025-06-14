import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/model/device_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class DeviceManager {
  static DeviceManager? _instance;

  final ThingsboardClient tbClient;
  PageData<DeviceInfo>? _deviceInfoCache;
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
        DeviceManager.instance._deviceInfoCache =
            PageData<DeviceInfo>(list, 1, list.length, false);
      }
    } catch (e) {
      print('Read deviceInfos cache err');
    }
  }

  static DeviceManager get instance {
    if (_instance == null) {
      throw Exception('DeviceManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  get deviceInfosPageLink => _deviceInfoCache;
  get deviceInfosList => _deviceInfoCache?.data;

  Future<PageData<DeviceInfo>> getDeviceInfosPageData(
      {PageLink? pageLink, bool forceRefresh = false}) async {
    final searchText = pageLink?.textSearch?.toLowerCase() ?? '';
    if (_deviceInfoCache != null && !forceRefresh) {
      return Future.value(_deviceInfoCache!.filterByName(searchText));
    }

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return Future.value(_deviceInfoCache!);
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
      _deviceInfoCache = pageData;
      return pageData;
    } finally {
      _isLoading = false;
    }
  }

  Future<List<DeviceInfo>> getDeviceInfosList(
      {bool forceRefresh = false}) async {
    await getDeviceInfosPageData(forceRefresh: forceRefresh);
    return _deviceInfoCache?.data ?? [];
  }

  DeviceInfo? getDeviceInfoByName(String name) {
    try {
      return _deviceInfoCache?.data.firstWhere(
        (deviceInfo) => deviceInfo.name == name,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  DeviceInfo? getDeviceInfoById(String id) {
    try {
      return _deviceInfoCache?.data.firstWhere(
        (deviceInfo) => deviceInfo.id?.id == id,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    await getDeviceInfosPageData(forceRefresh: true);
  }

  void clearCache() {
    _deviceInfoCache = null;
  }
}

extension on PageData<DeviceInfo> {
  PageData<DeviceInfo> filterByName(String searchText) {
    if (searchText.isEmpty) {
      return PageData<DeviceInfo>(data, 1, data.length, false);
    } else {
      final filtered = data
          .where(
            (deviceInfo) => (deviceInfo.getDisplayName())
                .toLowerCase()
                .contains(searchText),
          )
          .toList();
      return PageData<DeviceInfo>(filtered, 1, filtered.length, false);
    }
  }
}
