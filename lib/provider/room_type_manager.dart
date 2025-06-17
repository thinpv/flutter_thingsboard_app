import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/model/room_type_models.dart';
import 'package:thingsboard_app/service/room_type_service.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class RoomTypeManager {
  static RoomTypeManager? _instance;

  final ThingsboardClient tbClient;
  PageData<RoomTypeInfo>? _roomProfileCache;
  bool _isLoading = false;

  RoomTypeManager._internal(this.tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = RoomTypeManager._internal(client);
    try {
      TbStorage storage = getIt();
      String? jsonString = await storage.getItem('roomTypes') as String?;
      if (jsonString != null) {
        List<RoomTypeInfo> list = (jsonDecode(jsonString) as List)
            .map((item) => RoomTypeInfo.fromJson(item))
            .toList();
        RoomTypeManager.instance._roomProfileCache =
            PageData<RoomTypeInfo>(list, 1, list.length, false);
      }
    } catch (e) {
      print('Read roomProfiles cache err');
    }
  }

  static RoomTypeManager get instance {
    if (_instance == null) {
      throw Exception('RoomTypeManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  get roomProfilesPageLink => _roomProfileCache;
  get roomProfilesList => _roomProfileCache?.data;

  Future<PageData<RoomTypeInfo>> getRoomTypesPageData(
      {PageLink? pageLink, bool forceRefresh = false}) async {
    final searchText = pageLink?.textSearch?.toLowerCase() ?? '';
    if (_roomProfileCache != null && !forceRefresh) {
      return Future.value(_roomProfileCache!.filterByName(searchText));
    }

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return Future.value(_roomProfileCache!);
    }

    try {
      pageLink ??= PageLink(200);
      final pageData =
          await RoomTypeService.instance.getRoomTypeInfos(pageLink);

      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(pageData.data.map((d) => d.toJson()).toList());
        storage.setItem('roomTypes', jsonString);
      }

      _isLoading = true;
      _roomProfileCache = pageData;
      return pageData;
    } finally {
      _isLoading = false;
    }
  }

  Future<List<RoomTypeInfo>> getRoomTypesList(
      {bool forceRefresh = false}) async {
    await getRoomTypesPageData(forceRefresh: forceRefresh);
    return _roomProfileCache?.data ?? [];
  }

  RoomTypeInfo? getRoomTypeByName(String name) {
    try {
      return _roomProfileCache?.data.firstWhere(
        (roomProfile) => roomProfile.name == name,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  RoomTypeInfo? getRoomTypeById(String id) {
    try {
      return _roomProfileCache?.data.firstWhere(
        (roomProfile) => roomProfile.id.id == id,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    await getRoomTypesPageData(forceRefresh: true);
  }

  void clearCache() {
    _roomProfileCache = null;
  }
}

extension on PageData<RoomTypeInfo> {
  PageData<RoomTypeInfo> filterByName(String searchText) {
    if (searchText.isEmpty) {
      return PageData<RoomTypeInfo>(data, 1, data.length, false);
    } else {
      final filtered = data
          .where((roomType) =>
              roomType.name.toLowerCase().contains(searchText))
          .toList();
      return PageData<RoomTypeInfo>(filtered, 1, filtered.length, false);
    }
  }
}
