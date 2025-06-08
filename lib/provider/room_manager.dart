import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/model/room_models.dart';
import 'package:thingsboard_app/service/room_service.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class RoomManager {
  static RoomManager? _instance;

  final ThingsboardClient _tbClient;
  PageData<RoomInfo>? _roomCache;
  bool _isLoading = false;

  RoomManager._internal(this._tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = RoomManager._internal(client);
    try {
      TbStorage storage = getIt();
      String? jsonString = await storage.getItem('rooms') as String?;
      if (jsonString != null) {
        List<RoomInfo> list = (jsonDecode(jsonString) as List)
            .map((item) => RoomInfo.fromJson(item))
            .toList();
        RoomManager.instance._roomCache =
            PageData<RoomInfo>(list, 1, list.length, false);
      }
    } catch (e) {
      print('Read roomInfo cache err');
    }
  }

  static RoomManager get instance {
    if (_instance == null) {
      throw Exception('RoomManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  get roomsPageLink => _roomCache;
  get roomsList => _roomCache?.data;

  Future<PageData<RoomInfo>> getRoomsPageData(
      {PageLink? pageLink, bool forceRefresh = false}) async {
    final searchText = pageLink?.textSearch?.toLowerCase() ?? '';
    if (_roomCache != null && !forceRefresh) {
      return Future.value(_roomCache!.filterByName(searchText));
    }

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return Future.value(_roomCache!);
    }

    try {
      final customerId = _tbClient.getAuthUser()?.customerId;
      if (customerId == null) {
        throw Exception("Không thể xác định customerId hợp lệ.");
      }

      pageLink ??= PageLink(200);
      var pageData =
          await RoomService.instance.getCustomerRoomInfos(customerId, pageLink);

      //TODO: not need forceRefresh = true
      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(pageData.data.map((d) => d.toJson()).toList());
        storage.setItem('rooms', jsonString);
      }

      _isLoading = true;
      _roomCache = pageData;
      return pageData;
    } finally {
      _isLoading = false;
    }
  }

  Future<List<RoomInfo>> getRoomsList({bool forceRefresh = false}) async {
    await getRoomsPageData(forceRefresh: forceRefresh);
    return _roomCache?.data ?? [];
  }

  RoomInfo? getRoomByName(String name) {
    try {
      return _roomCache?.data.firstWhere(
        (roomInfo) => roomInfo.name == name,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  RoomInfo? getRoomById(String id) {
    try {
      return _roomCache?.data.firstWhere(
        (roomInfo) => roomInfo.id?.id == id,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    await getRoomsPageData(forceRefresh: true);
  }

  void clearCache() {
    _roomCache = null;
  }
}

extension on PageData<RoomInfo> {
  PageData<RoomInfo> filterByName(String searchText) {
    if (searchText.isEmpty) {
      return PageData<RoomInfo>(data, 1, data.length, false);
    } else {
      final filtered = data
          .where((myDeviceInfoInfo) =>
              myDeviceInfoInfo.displayName
                  ?.toLowerCase()
                  .contains(searchText) ??
              false)
          .toList();
      return PageData<RoomInfo>(filtered, 1, filtered.length, false);
    }
  }
}
