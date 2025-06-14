import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_app/service/scenario_service.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class ScenarioManager {
  static ScenarioManager? _instance;

  final ThingsboardClient _tbClient;
  PageData<ScenarioInfo>? _scenarioCache;
  bool _isLoading = false;

  ScenarioManager._internal(this._tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = ScenarioManager._internal(client);
    try {
      TbStorage storage = getIt();
      String? jsonString = await storage.getItem('scenarios') as String?;
      if (jsonString != null) {
        List<ScenarioInfo> list = (jsonDecode(jsonString) as List)
            .map((item) => ScenarioInfo.fromJson(item))
            .toList();
        ScenarioManager.instance._scenarioCache =
            PageData<ScenarioInfo>(list, 1, list.length, false);
      }
    } catch (e) {
      print('Read scenarioInfo cache err');
    }
  }

  static ScenarioManager get instance {
    if (_instance == null) {
      throw Exception('ScenarioManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  get scenariosPageLink => _scenarioCache;
  get scenariosList => _scenarioCache?.data;

  Future<PageData<ScenarioInfo>> getScenariosPageData(
      {PageLink? pageLink, bool forceRefresh = false}) async {
    final searchText = pageLink?.textSearch?.toLowerCase() ?? '';
    if (_scenarioCache != null && !forceRefresh) {
      return Future.value(_scenarioCache!.filterByName(searchText));
    }

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return Future.value(_scenarioCache!);
    }

    try {
      final customerId = _tbClient.getAuthUser()?.customerId;
      if (customerId == null) {
        throw Exception("Không thể xác định customerId hợp lệ.");
      }

      pageLink ??= PageLink(200);
      var pageData = await ScenarioService.instance
          .getCustomerScenarioInfos(customerId, pageLink);

      //TODO: not need forceRefresh = true
      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(pageData.data.map((d) => d.toJson()).toList());
        storage.setItem('scenarios', jsonString);
      }

      _isLoading = true;
      _scenarioCache = pageData;
      return pageData;
    } finally {
      _isLoading = false;
    }
  }

  Future<List<ScenarioInfo>> getScenariosList(
      {bool forceRefresh = false}) async {
    await getScenariosPageData(forceRefresh: forceRefresh);
    return _scenarioCache?.data ?? [];
  }

  ScenarioInfo? getScenarioByName(String name) {
    try {
      return _scenarioCache?.data.firstWhere(
        (scenarioInfo) => scenarioInfo.name == name,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  ScenarioInfo? getScenarioById(String id) {
    try {
      return _scenarioCache?.data.firstWhere(
        (scenarioInfo) => scenarioInfo.id?.id == id,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    await getScenariosPageData(forceRefresh: true);
  }

  void clearCache() {
    _scenarioCache = null;
  }
}

extension on PageData<ScenarioInfo> {
  PageData<ScenarioInfo> filterByName(String searchText) {
    if (searchText.isEmpty) {
      return PageData<ScenarioInfo>(data, 1, data.length, false);
    } else {
      final filtered = data
          .where((deviceInfo) =>
              deviceInfo.getDisplayName().toLowerCase().contains(searchText))
          .toList();
      return PageData<ScenarioInfo>(filtered, 1, filtered.length, false);
    }
  }
}
