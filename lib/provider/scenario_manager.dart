import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class ScenarioManager {
  static ScenarioManager? _instance;

  final ThingsboardClient tbClient;
  PageData<Scenario>? _scenarioCache;
  bool _isLoading = false;

  ScenarioManager._internal(this.tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = ScenarioManager._internal(client);
    try {
      TbStorage storage = getIt();
      String? jsonString = await storage.getItem('scenarios') as String?;
      if (jsonString != null) {
        List<Scenario> list = (jsonDecode(jsonString) as List)
            .map((item) => Scenario.fromJson(item))
            .toList();
        ScenarioManager.instance._scenarioCache =
            PageData<Scenario>(list, 1, list.length, false);
      }
    } catch (e) {
      print('Read scenario cache err');
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

  Future<PageData<Scenario>> getScenariosPageData(
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
      final customerId = tbClient.getAuthUser()?.customerId;
      if (customerId == null) {
        throw Exception("Không thể xác định customerId hợp lệ.");
      }

      pageLink ??= PageLink(200);
      final _pageData = await tbClient
          .getAssetService()
          .getCustomerAssetInfos(customerId, pageLink, type: 'Scenario');

      List<Scenario> scenarios = await Future.wait(
        _pageData.data.map((asset) => Scenario.fromAssetInfo(asset)),
      );

      PageData<Scenario> pageData = PageData(
        scenarios,
        _pageData.totalPages,
        _pageData.totalElements,
        _pageData.hasNext,
      );
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

  Future<List<Scenario>> getScenariosList({bool forceRefresh = false}) async {
    await getScenariosPageData(forceRefresh: forceRefresh);
    return _scenarioCache?.data ?? [];
  }

  Scenario? getScenarioByName(String name) {
    try {
      return _scenarioCache?.data.firstWhere(
        (scenario) => scenario.name == name,
      );
    } catch (e) {
      return null;
    }
  }

  Scenario? getScenarioById(String id) {
    try {
      return _scenarioCache?.data.firstWhere(
        (scenario) => scenario.id?.id == id,
      );
    } catch (e) {
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

extension on PageData<Scenario> {
  PageData<Scenario> filterByName(String searchText) {
    final filtered = data
        .where((scenario) => scenario.name.toLowerCase().contains(searchText))
        .toList();
    return PageData<Scenario>(filtered, 1, filtered.length, false);
  }
}
