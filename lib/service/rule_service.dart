import 'dart:convert';

import 'package:thingsboard_app/model/rule_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

void printLongString(String text) {
  const int chunkSize = 800;
  for (var i = 0; i < text.length; i += chunkSize) {
    final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
    print(text.substring(i, end));
  }
}

PageData<RuleInfo> parseRuleInfoPageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => RuleInfo.fromJson(json));
}

PageData<Rule> parseRulePageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => Rule.fromJson(json));
}

class RuleService {
  static RuleService? _instance;
  final ThingsboardClient _tbClient;

  factory RuleService(ThingsboardClient tbClient) {
    return RuleService._internal(tbClient);
  }

  RuleService._internal(this._tbClient);

  static void init(ThingsboardClient client) {
    _instance = RuleService._internal(client);
  }

  static RuleService get instance {
    if (_instance == null) {
      throw Exception('RuleService chưa được khởi tạo!');
    }
    return _instance!;
  }

  Future<Rule?> getRule(String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Rule.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<RuleInfo?> getRuleInfo(String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/asset/info/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null
            ? RuleInfo.fromJson(response.data!)
            : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Rule> saveRule(Rule asset,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<Map<String, dynamic>>('/api/asset',
        data: jsonEncode(asset),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return Rule.fromJson(response.data!);
  }

  Future<void> deleteRule(String assetId,
      {RequestConfig? requestConfig}) async {
    await _tbClient.delete('/api/asset/$assetId',
        options: defaultHttpOptionsFromConfig(requestConfig));
  }

  Future<Rule?> assignRuleToCustomer(String customerId, String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/customer/$customerId/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Rule.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Rule?> unassignRuleFromCustomer(String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.delete<Map<String, dynamic>>(
            '/api/customer/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Rule.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Rule?> assignRuleToPublicCustomer(String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/customer/public/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Rule.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<Rule>> getTenantRules(PageLink pageLink,
      {String type = 'Rule', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/tenant/assets',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseRulePageData, response.data!);
  }

  Future<PageData<RuleInfo>> getTenantRuleInfos(PageLink pageLink,
      {String type = 'Rule', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/tenant/assetInfos',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseRuleInfoPageData, response.data!);
  }

  Future<Rule?> getTenantRule(String assetName,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/tenant/assets',
            queryParameters: {'assetName': assetName},
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Rule.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<Rule>> getCustomerRules(
      String customerId, PageLink pageLink,
      {String type = 'Rule', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/customer/$customerId/assets',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseRulePageData, response.data!);
  }

  Future<PageData<RuleInfo>> getCustomerRuleInfos(
      String customerId, PageLink pageLink,
      {String type = 'Rule', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/customer/$customerId/assetInfos',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseRuleInfoPageData, response.data!);
  }

  Future<List<Rule>> getRulesByIds(List<String> assetIds,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<List<dynamic>>('/api/assets',
        queryParameters: {'assetIds': assetIds.join(',')},
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => Rule.fromJson(e)).toList();
  }

  Future<List<Rule>> findByQuery(RuleSearchQuery query,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<List<dynamic>>('/api/assets',
        data: jsonEncode(query),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => Rule.fromJson(e)).toList();
  }

  Future<List<EntitySubtype>> getRuleTypes(
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<List<dynamic>>('/api/asset/types',
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => EntitySubtype.fromJson(e)).toList();
  }

  Future<Rule?> assignRuleToEdge(String edgeId, String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/edge/$edgeId/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Rule.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Rule?> unassignRuleFromEdge(String edgeId, String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.delete<Map<String, dynamic>>(
            '/api/edge/$edgeId/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Rule.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<Rule>> getEdgeRules(String edgeId, PageLink pageLink,
      {String type = 'Rule', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/edge/$edgeId/assets',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseRulePageData, response.data!);
  }
}
