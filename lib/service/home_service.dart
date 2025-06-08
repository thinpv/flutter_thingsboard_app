import 'dart:convert';

import 'package:thingsboard_app/model/home_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

PageData<HomeInfo> parseHomeInfoPageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => HomeInfo.fromJson(json));
}

PageData<Home> parseHomePageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => Home.fromJson(json));
}

class HomeService {
  static HomeService? _instance;
  final ThingsboardClient _tbClient;

  factory HomeService(ThingsboardClient tbClient) {
    return HomeService._internal(tbClient);
  }

  HomeService._internal(this._tbClient);

  static void init(ThingsboardClient client) {
    _instance = HomeService._internal(client);
  }

  static HomeService get instance {
    if (_instance == null) {
      throw Exception('HomeService chưa được khởi tạo!');
    }
    return _instance!;
  }

  Future<Home?> getHome(String assetId, {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Home.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<HomeInfo?> getHomeInfo(String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/asset/info/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? HomeInfo.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Home> saveHome(Home asset, {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<Map<String, dynamic>>('/api/asset',
        data: jsonEncode(asset),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return Home.fromJson(response.data!);
  }

  Future<void> deleteHome(String assetId,
      {RequestConfig? requestConfig}) async {
    await _tbClient.delete('/api/asset/$assetId',
        options: defaultHttpOptionsFromConfig(requestConfig));
  }

  Future<Home?> assignHomeToCustomer(String customerId, String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/customer/$customerId/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Home.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Home?> unassignHomeFromCustomer(String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.delete<Map<String, dynamic>>(
            '/api/customer/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Home.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Home?> assignHomeToPublicCustomer(String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/customer/public/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Home.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<Home>> getTenantHomes(PageLink pageLink,
      {String type = 'Home', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/tenant/assets',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseHomePageData, response.data!);
  }

  Future<PageData<HomeInfo>> getTenantHomeInfos(PageLink pageLink,
      {String type = 'Home', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/tenant/assetInfos',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseHomeInfoPageData, response.data!);
  }

  Future<Home?> getTenantHome(String assetName,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/tenant/assets',
            queryParameters: {'assetName': assetName},
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Home.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<Home>> getCustomerHomes(String customerId, PageLink pageLink,
      {String type = 'Home', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/customer/$customerId/assets',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseHomePageData, response.data!);
  }

  Future<PageData<HomeInfo>> getCustomerHomeInfos(
      String customerId, PageLink pageLink,
      {String type = 'Home', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/customer/$customerId/assetInfos',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseHomeInfoPageData, response.data!);
  }

  Future<List<Home>> getHomesByIds(List<String> assetIds,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<List<dynamic>>('/api/assets',
        queryParameters: {'assetIds': assetIds.join(',')},
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => Home.fromJson(e)).toList();
  }

  Future<List<Home>> findByQuery(HomeSearchQuery query,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<List<dynamic>>('/api/assets',
        data: jsonEncode(query),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => Home.fromJson(e)).toList();
  }

  Future<List<EntitySubtype>> getHomeTypes(
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<List<dynamic>>('/api/asset/types',
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => EntitySubtype.fromJson(e)).toList();
  }

  Future<Home?> assignHomeToEdge(String edgeId, String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/edge/$edgeId/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Home.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Home?> unassignHomeFromEdge(String edgeId, String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.delete<Map<String, dynamic>>(
            '/api/edge/$edgeId/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Home.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<Home>> getEdgeHomes(String edgeId, PageLink pageLink,
      {String type = 'Home', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/edge/$edgeId/assets',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseHomePageData, response.data!);
  }
}
