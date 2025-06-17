import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/model/home_models.dart';
import 'package:thingsboard_app/service/home_service.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class HomeManager {
  static HomeManager? _instance;

  final ThingsboardClient _tbClient;
  PageData<HomeInfo>? _homeCache;
  bool _isLoading = false;

  HomeManager._internal(this._tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = HomeManager._internal(client);
    try {
      TbStorage storage = getIt();
      String? jsonString = await storage.getItem('homes') as String?;
      if (jsonString != null) {
        List<HomeInfo> list = (jsonDecode(jsonString) as List)
            .map((item) => HomeInfo.fromJson(item))
            .toList();
        HomeManager.instance._homeCache =
            PageData<HomeInfo>(list, 1, list.length, false);
      }
    } catch (e) {
      print('Read homeInfo cache err');
    }
  }

  static HomeManager get instance {
    if (_instance == null) {
      throw Exception('HomeManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  get homesPageLink => _homeCache;
  get homesList => _homeCache?.data;

  Future<PageData<HomeInfo>> getHomesPageData(
      {PageLink? pageLink, bool forceRefresh = false}) async {
    final searchText = pageLink?.textSearch?.toLowerCase() ?? '';
    if (_homeCache != null && !forceRefresh) {
      return Future.value(_homeCache!.filterByName(searchText));
    }

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return Future.value(_homeCache!);
    }

    try {
      final customerId = _tbClient.getAuthUser()?.customerId;
      if (customerId == null) {
        throw Exception("Không thể xác định customerId hợp lệ.");
      }

      pageLink ??= PageLink(200);
      var pageData =
          await HomeService.instance.getCustomerHomeInfos(customerId, pageLink);

      //TODO: not need forceRefresh = true
      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(pageData.data.map((d) => d.toJson()).toList());
        storage.setItem('homes', jsonString);
      }

      _isLoading = true;
      _homeCache = pageData;
      return pageData;
    } finally {
      _isLoading = false;
    }
  }

  Future<List<HomeInfo>> getHomesList({bool forceRefresh = false}) async {
    await getHomesPageData(forceRefresh: forceRefresh);
    return _homeCache?.data ?? [];
  }

  HomeInfo? getHomeByName(String name) {
    try {
      return _homeCache?.data.firstWhere(
        (homeInfo) => homeInfo.name == name,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  HomeInfo? getHomeById(String id) {
    try {
      return _homeCache?.data.firstWhere(
        (homeInfo) => homeInfo.id?.id == id,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    await getHomesPageData(forceRefresh: true);
  }

  void clearCache() {
    _homeCache = null;
  }

  HomeInfo? getCurrentHome()
  {
    return _homeCache?.data.first;
  }
}

extension on PageData<HomeInfo> {
  PageData<HomeInfo> filterByName(String searchText) {
    if (searchText.isEmpty) {
      return PageData<HomeInfo>(data, 1, data.length, false);
    } else {
      final filtered = data
          .where((myDeviceInfo) =>
              myDeviceInfo.getDisplayName().toLowerCase().contains(searchText))
          .toList();
      return PageData<HomeInfo>(filtered, 1, filtered.length, false);
    }
  }
}
