import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class ScenarioManager {
  static ScenarioManager? _instance;

  final ThingsboardClient tbClient;
  List<Scenario>? _scenarioCache;
  bool _isLoading = false;

  ScenarioManager._internal(this.tbClient);

  static void init(ThingsboardClient client) {
    _instance = ScenarioManager._internal(client);
  }

  static ScenarioManager get instance {
    if (_instance == null) {
      throw Exception('ScenarioManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  /// Lấy danh sách thiết bị, dùng cache nếu có
  Future<List<Scenario>> getScenarios({bool forceRefresh = false}) async {
    if (_scenarioCache != null && !forceRefresh) {
      return _scenarioCache!;
    }

    if (_isLoading) {
      // Nếu đang loading song song, đợi một chút
      await Future.delayed(Duration(milliseconds: 300));
      return _scenarioCache ?? [];
    }

    _isLoading = true;
    try {
      final user = await tbClient.getUserService().getUser();
      final customerId = user.customerId?.id;

      if (customerId == null ||
          customerId == '13814000-1dd2-11b2-8080-808080808080') {
        throw Exception("Không thể xác định customerId hợp lệ.");
      }

      final pageLink =
          PageLink(100); // hoặc tuỳ chỉnh phân trang nếu nhiều thiết bị
      final pageData = await tbClient
          .getAssetService()
          .getCustomerAssetInfos(customerId, pageLink);

      List<Scenario> scenarios = await Future.wait(
        pageData.data.map((asset) => Scenario.fromAssetInfo(asset)),
      );

      PageData<Scenario> scenarioPageData = PageData(
        scenarios,
        pageData.totalPages,
        pageData.totalElements,
        pageData.hasNext,
      );

      _scenarioCache = scenarioPageData.data;
      return _scenarioCache!;
    } finally {
      _isLoading = false;
    }
  }

  Future<Scenario?> getScenarioByName(String name) async {
    if (_scenarioCache == null) await getScenarios();
    try {
      return _scenarioCache?.firstWhere(
        (scenario) => scenario.name == name,
      );
    } catch (e) {
      return null;
    }
  }

  Future<Scenario?> getScenarioById(String id) async {
    if (_scenarioCache == null) await getScenarios();
    try {
      return _scenarioCache?.firstWhere(
        (scenario) => scenario.id?.id == id,
      );
    } catch (e) {
      return null;
    }
  }

  /// Làm mới cache
  Future<void> refresh() async {
    await getScenarios(forceRefresh: true);
  }

  /// Xoá cache thủ công nếu cần
  void clearCache() {
    _scenarioCache = null;
  }
}
