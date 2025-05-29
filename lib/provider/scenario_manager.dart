import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class ScenarioManager {
  static ScenarioManager? _instance;

  final ThingsboardClient tbClient;
  List<Scenario>? _scenarioCache;
  bool _isLoading = false;

  ScenarioManager._internal(this.tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = ScenarioManager._internal(client);
    TbStorage storage = getIt();
    String? jsonString = await storage.getItem('scenarios') as String?;
    if (jsonString != null) {
      List<AssetInfo>? assetInfoList = (jsonDecode(jsonString) as List)
          .map((item) => AssetInfo.fromJson(item))
          .toList();
      ScenarioManager.instance._scenarioCache = await Future.wait(
          assetInfoList.map((p) => Scenario.fromAssetInfo(p)));
    }
  }

  static ScenarioManager get instance {
    if (_instance == null) {
      throw Exception('ScenarioManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  Future<List<Scenario>> getScenariosAsync({bool forceRefresh = false}) async {
    if (_scenarioCache != null && !forceRefresh) {
      return _scenarioCache!;
    }

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return [];
    }

    try {
      final customerId = tbClient.getAuthUser()?.customerId;
      if (customerId == null) {
        throw Exception("Không thể xác định customerId hợp lệ.");
      }

      final pageLink = PageLink(200);
      final pageData = await tbClient
          .getAssetService()
          .getCustomerAssetInfos(customerId, pageLink, type: 'Scenario');

      List<Scenario> scenarios = await Future.wait(
        pageData.data.map((asset) => Scenario.fromAssetInfo(asset)),
      );

      PageData<Scenario> scenarioPageData = PageData(
        scenarios,
        pageData.totalPages,
        pageData.totalElements,
        pageData.hasNext,
      );

      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(scenarioPageData.data.map((d) => d.toJson()).toList());
        storage.setItem('scenarios', jsonString);
      }

      _isLoading = true;
      _scenarioCache = scenarioPageData.data;
      return _scenarioCache!;
    } finally {
      _isLoading = false;
    }
  }

  Future<PageData<Scenario>> getScenarios(PageLink pageLink) async {
    if (_scenarioCache != null) {
      final searchText = pageLink.textSearch?.toLowerCase() ?? '';
      final scenarios = _scenarioCache!
          .where((scenario) => scenario.name.toLowerCase().contains(searchText))
          .toList();
      return PageData<Scenario>(
        scenarios,
        1,
        scenarios.length,
        false,
      );
    } else {
      return PageData<Scenario>(
        [],
        0,
        0,
        false,
      );
    }
  }

  Scenario? getScenarioByName(String name) {
    try {
      return _scenarioCache?.firstWhere(
        (scenario) => scenario.name == name,
      );
    } catch (e) {
      return null;
    }
  }

  Scenario? getScenarioById(String id) {
    try {
      return _scenarioCache?.firstWhere(
        (scenario) => scenario.id?.id == id,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> refresh() async {
    await getScenariosAsync(forceRefresh: true);
  }

  void clearCache() {
    _scenarioCache = null;
  }
}
