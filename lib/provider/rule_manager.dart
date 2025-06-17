import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/model/rule_models.dart';
import 'package:thingsboard_app/service/rule_service.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class RuleManager {
  static RuleManager? _instance;

  final ThingsboardClient _tbClient;
  PageData<RuleInfo>? _ruleCache;
  bool _isLoading = false;

  RuleManager._internal(this._tbClient);

  static Future<void> init(ThingsboardClient client) async {
    _instance = RuleManager._internal(client);
    try {
      TbStorage storage = getIt();
      String? jsonString = await storage.getItem('rules') as String?;
      if (jsonString != null) {
        List<RuleInfo> list = (jsonDecode(jsonString) as List)
            .map((item) => RuleInfo.fromJson(item))
            .toList();
        RuleManager.instance._ruleCache =
            PageData<RuleInfo>(list, 1, list.length, false);
      }
    } catch (e) {
      print('Read ruleInfo cache err');
    }
  }

  static RuleManager get instance {
    if (_instance == null) {
      throw Exception('RuleManager chưa được khởi tạo!');
    }
    return _instance!;
  }

  get rulesPageLink => _ruleCache;
  get rulesList => _ruleCache?.data;

  Future<PageData<RuleInfo>> getRulesPageData(
      {PageLink? pageLink, bool forceRefresh = false}) async {
    final searchText = pageLink?.textSearch?.toLowerCase() ?? '';
    if (_ruleCache != null && !forceRefresh) {
      return Future.value(_ruleCache!.filterByName(searchText));
    }

    int count = 3;
    while (_isLoading && count > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (--count == 0) return Future.value(_ruleCache!);
    }

    try {
      final customerId = _tbClient.getAuthUser()?.customerId;
      if (customerId == null) {
        throw Exception("Không thể xác định customerId hợp lệ.");
      }

      pageLink ??= PageLink(200);
      var pageData = await RuleService.instance
          .getCustomerRuleInfos(customerId, pageLink);

      //TODO: not need forceRefresh = true
      if (forceRefresh) {
        TbStorage storage = getIt();
        String jsonString =
            jsonEncode(pageData.data.map((d) => d.toJson()).toList());
        storage.setItem('rules', jsonString);
      }

      _isLoading = true;
      _ruleCache = pageData;
      return pageData;
    } finally {
      _isLoading = false;
    }
  }

  Future<List<RuleInfo>> getRulesList(
      {bool forceRefresh = false}) async {
    await getRulesPageData(forceRefresh: forceRefresh);
    return _ruleCache?.data ?? [];
  }

  RuleInfo? getRuleByName(String name) {
    try {
      return _ruleCache?.data.firstWhere(
        (ruleInfo) => ruleInfo.name == name,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  RuleInfo? getRuleById(String id) {
    try {
      return _ruleCache?.data.firstWhere(
        (ruleInfo) => ruleInfo.id?.id == id,
      );
    } catch (e) {
      print('e: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    await getRulesPageData(forceRefresh: true);
  }

  void clearCache() {
    _ruleCache = null;
  }
}

extension on PageData<RuleInfo> {
  PageData<RuleInfo> filterByName(String searchText) {
    if (searchText.isEmpty) {
      return PageData<RuleInfo>(data, 1, data.length, false);
    } else {
      final filtered = data
          .where((myDeviceInfo) =>
              myDeviceInfo.getDisplayName().toLowerCase().contains(searchText))
          .toList();
      return PageData<RuleInfo>(filtered, 1, filtered.length, false);
    }
  }
}
