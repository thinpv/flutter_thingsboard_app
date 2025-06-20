import 'dart:convert';

import 'package:thingsboard_app/model/scene_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

PageData<SceneInfo> parseSceneInfoPageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => SceneInfo.fromJson(json));
}

PageData<Scene> parseScenePageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => Scene.fromJson(json));
}

class SceneService {
  static SceneService? _instance;
  final ThingsboardClient _tbClient;

  factory SceneService(ThingsboardClient tbClient) {
    return SceneService._internal(tbClient);
  }

  SceneService._internal(this._tbClient);

  static void init(ThingsboardClient client) {
    _instance = SceneService._internal(client);
  }

  static SceneService get instance {
    if (_instance == null) {
      throw Exception('SceneService chưa được khởi tạo!');
    }
    return _instance!;
  }

  Future<Scene?> getScene(String assetId, {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Scene.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<SceneInfo?> getSceneInfo(String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/asset/info/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? SceneInfo.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Scene> saveScene(Scene asset, {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<Map<String, dynamic>>('/api/asset',
        data: jsonEncode(asset),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return Scene.fromJson(response.data!);
  }

  Future<void> deleteScene(String assetId,
      {RequestConfig? requestConfig}) async {
    await _tbClient.delete('/api/asset/$assetId',
        options: defaultHttpOptionsFromConfig(requestConfig));
  }

  Future<Scene?> assignSceneToCustomer(String customerId, String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/customer/$customerId/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Scene.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Scene?> unassignSceneFromCustomer(String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.delete<Map<String, dynamic>>(
            '/api/customer/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Scene.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Scene?> assignSceneToPublicCustomer(String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/customer/public/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Scene.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<Scene>> getTenantScenes(PageLink pageLink,
      {String type = 'Scene', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/tenant/assets',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseScenePageData, response.data!);
  }

  Future<PageData<SceneInfo>> getTenantSceneInfos(PageLink pageLink,
      {String type = 'Scene', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/tenant/assetInfos',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseSceneInfoPageData, response.data!);
  }

  Future<Scene?> getTenantScene(String assetName,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/tenant/assets',
            queryParameters: {'assetName': assetName},
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Scene.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<Scene>> getCustomerScenes(String customerId, PageLink pageLink,
      {String type = 'Scene', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/customer/$customerId/assets',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseScenePageData, response.data!);
  }

  Future<PageData<SceneInfo>> getCustomerSceneInfos(
      String customerId, PageLink pageLink,
      {String type = 'Scene', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/customer/$customerId/assetInfos',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseSceneInfoPageData, response.data!);
  }

  Future<List<Scene>> getScenesByIds(List<String> assetIds,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<List<dynamic>>('/api/assets',
        queryParameters: {'assetIds': assetIds.join(',')},
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => Scene.fromJson(e)).toList();
  }

  Future<List<Scene>> findByQuery(SceneSearchQuery query,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<List<dynamic>>('/api/assets',
        data: jsonEncode(query),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => Scene.fromJson(e)).toList();
  }

  Future<List<EntitySubtype>> getSceneTypes(
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<List<dynamic>>('/api/asset/types',
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => EntitySubtype.fromJson(e)).toList();
  }

  Future<Scene?> assignSceneToEdge(String edgeId, String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/edge/$edgeId/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Scene.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Scene?> unassignSceneFromEdge(String edgeId, String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.delete<Map<String, dynamic>>(
            '/api/edge/$edgeId/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Scene.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<Scene>> getEdgeScenes(String edgeId, PageLink pageLink,
      {String type = 'Scene', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/edge/$edgeId/assets',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseScenePageData, response.data!);
  }
}
