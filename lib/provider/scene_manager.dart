import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/model/scene_models.dart';
import 'package:thingsboard_app/service/scene_service.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class SceneManager {
  static SceneManager? _instance;

  final ThingsboardClient _tbClient;
  PageData<SceneInfo>? _sceneCache;
  bool _isLoading = false;

  SceneManager._internal(this._tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = SceneManager._internal(client);
    try {
      TbStorage storage = getIt();
      String? jsonString = await storage.getItem('scenes') as String?;
      if (jsonString != null) {
        List<SceneInfo> list = (jsonDecode(jsonString) as List)
            .map((item) => SceneInfo.fromJson(item))
            .toList();
        SceneManager.instance._sceneCache =
            PageData<SceneInfo>(list, 1, list.length, false);
      }
    } catch (e) {
      print('Read sceneInfo cache err');
    }
  }

  static SceneManager get instance {
    if (_instance == null) {
      throw Exception('SceneManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  get scenesPageLink => _sceneCache;
  get scenesList => _sceneCache?.data;

  Future<PageData<SceneInfo>> getScenesPageData(
      {PageLink? pageLink, bool forceRefresh = false}) async {
    final searchText = pageLink?.textSearch?.toLowerCase() ?? '';
    if (_sceneCache != null && !forceRefresh) {
      return Future.value(_sceneCache!.filterByName(searchText));
    }

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return Future.value(_sceneCache!);
    }

    try {
      final customerId = _tbClient.getAuthUser()?.customerId;
      if (customerId == null) {
        throw Exception("Không thể xác định customerId hợp lệ.");
      }

      pageLink ??= PageLink(200);
      var pageData =
          await SceneService.instance.getCustomerSceneInfos(customerId, pageLink);

      //TODO: not need forceRefresh = true
      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(pageData.data.map((d) => d.toJson()).toList());
        storage.setItem('scenes', jsonString);
      }

      _isLoading = true;
      _sceneCache = pageData;
      return pageData;
    } finally {
      _isLoading = false;
    }
  }

  Future<List<SceneInfo>> getScenesList({bool forceRefresh = false}) async {
    await getScenesPageData(forceRefresh: forceRefresh);
    return _sceneCache?.data ?? [];
  }

  SceneInfo? getSceneByName(String name) {
    try {
      return _sceneCache?.data.firstWhere(
        (sceneInfo) => sceneInfo.name == name,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  SceneInfo? getSceneById(String id) {
    try {
      return _sceneCache?.data.firstWhere(
        (sceneInfo) => sceneInfo.id?.id == id,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  Future<void> deleteScene(Scene scene) async {
    if (scene.id != null && scene.id!.id != null) {
      await SceneService.instance.deleteScene(scene.id!.id!);
    }
  }

  Future<void> refresh() async {
    await getScenesPageData(forceRefresh: true);
  }

  void clearCache() {
    _sceneCache = null;
  }
}

extension on PageData<SceneInfo> {
  PageData<SceneInfo> filterByName(String searchText) {
    if (searchText.isEmpty) {
      return PageData<SceneInfo>(data, 1, data.length, false);
    } else {
      final filtered = data
          .where((myDeviceInfo) =>
              myDeviceInfo.getDisplayName().toLowerCase().contains(searchText))
          .toList();
      return PageData<SceneInfo>(filtered, 1, filtered.length, false);
    }
  }
}
