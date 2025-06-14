import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/service/my_device_service.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class DeviceManager {
  static DeviceManager? _instance;

  final ThingsboardClient tbClient;
  PageData<MyDeviceInfo>? _myDeviceInfoCache;
  bool _isLoading = false;

  DeviceManager._internal(this.tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = DeviceManager._internal(client);
    try {
      TbStorage storage = getIt();
      String? jsonString = await storage.getItem('devices') as String?;
      if (jsonString != null) {
        DeviceManager.instance._myDeviceInfoCache =
            parseMyDeviceInfoPageData(jsonDecode(jsonString));
      }
    } catch (e) {
      print('Read myDeviceInfos cache err');
    }
  }

  static DeviceManager get instance {
    if (_instance == null) {
      throw Exception('DeviceManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  get myDeviceInfosPageLink => _myDeviceInfoCache;
  get myDeviceInfosList => _myDeviceInfoCache?.data;

  Future<PageData<MyDeviceInfo>> getMyDeviceInfosPageData(
      {PageLink? pageLink, bool forceRefresh = false}) async {
    final searchText = pageLink?.textSearch?.toLowerCase() ?? '';
    if (_myDeviceInfoCache != null && !forceRefresh) {
      return Future.value(_myDeviceInfoCache!.filterByName(searchText));
    }

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return Future.value(_myDeviceInfoCache!);
    }

    try {
      final customerId = tbClient.getAuthUser()?.customerId;
      if (customerId == null) {
        throw Exception("Không thể xác định customerId hợp lệ.");
      }

      pageLink ??= PageLink(200);
      final pageData = await MyDeviceService.instance
          .getCustomerMyDeviceInfos(customerId, pageLink);

      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(pageData.data.map((d) => d.toJson()).toList());
        storage.setItem('devices', jsonString);
      }

      _isLoading = true;
      _myDeviceInfoCache = pageData;
      return pageData;
    } finally {
      _isLoading = false;
    }
  }

  Future<List<MyDeviceInfo>> getMyDeviceInfosList(
      {bool forceRefresh = false}) async {
    await getMyDeviceInfosPageData(forceRefresh: forceRefresh);
    return _myDeviceInfoCache?.data ?? [];
  }

  MyDeviceInfo? getMyDeviceInfoByName(String name) {
    try {
      return _myDeviceInfoCache?.data.firstWhere(
        (myDeviceInfo) => myDeviceInfo.name == name,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  MyDeviceInfo? getMyDeviceInfoById(String id) {
    try {
      return _myDeviceInfoCache?.data.firstWhere(
        (myDeviceInfo) => myDeviceInfo.id?.id == id,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    await getMyDeviceInfosPageData(forceRefresh: true);
  }

  void clearCache() {
    _myDeviceInfoCache = null;
  }
}

extension on PageData<MyDeviceInfo> {
  PageData<MyDeviceInfo> filterByName(String searchText) {
    if (searchText.isEmpty) {
      return PageData<MyDeviceInfo>(data, 1, data.length, false);
    } else {
      final filtered = data
          .where(
            (myDeviceInfo) => (myDeviceInfo.getDisplayName())
                .toLowerCase()
                .contains(searchText),
          )
          .toList();
      return PageData<MyDeviceInfo>(filtered, 1, filtered.length, false);
    }
  }
}
