import 'dart:convert';

import 'package:thingsboard_app/model/room_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

PageData<RoomInfo> parseRoomInfoPageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => RoomInfo.fromJson(json));
}

PageData<Room> parseRoomPageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => Room.fromJson(json));
}

class RoomService {
  static RoomService? _instance;
  final ThingsboardClient _tbClient;

  factory RoomService(ThingsboardClient tbClient) {
    return RoomService._internal(tbClient);
  }

  RoomService._internal(this._tbClient);

  static void init(ThingsboardClient client) {
    _instance = RoomService._internal(client);
  }

  static RoomService get instance {
    if (_instance == null) {
      throw Exception('RoomService chưa được khởi tạo!');
    }
    return _instance!;
  }

  Future<Room?> getRoom(String assetId, {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Room.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<RoomInfo?> getRoomInfo(String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/asset/info/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? RoomInfo.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Room> saveRoom(Room asset, {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<Map<String, dynamic>>('/api/asset',
        data: jsonEncode(asset),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return Room.fromJson(response.data!);
  }

  Future<void> deleteRoom(String assetId,
      {RequestConfig? requestConfig}) async {
    await _tbClient.delete('/api/asset/$assetId',
        options: defaultHttpOptionsFromConfig(requestConfig));
  }

  Future<Room?> assignRoomToCustomer(String customerId, String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/customer/$customerId/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Room.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Room?> unassignRoomFromCustomer(String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.delete<Map<String, dynamic>>(
            '/api/customer/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Room.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Room?> assignRoomToPublicCustomer(String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/customer/public/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Room.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<Room>> getTenantRooms(PageLink pageLink,
      {String type = 'Room', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/tenant/assets',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseRoomPageData, response.data!);
  }

  Future<PageData<RoomInfo>> getTenantRoomInfos(PageLink pageLink,
      {String type = 'Room', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/tenant/assetInfos',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseRoomInfoPageData, response.data!);
  }

  Future<Room?> getTenantRoom(String assetName,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/tenant/assets',
            queryParameters: {'assetName': assetName},
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Room.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<Room>> getCustomerRooms(String customerId, PageLink pageLink,
      {String type = 'Room', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/customer/$customerId/assets',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseRoomPageData, response.data!);
  }

  Future<PageData<RoomInfo>> getCustomerRoomInfos(
      String customerId, PageLink pageLink,
      {String type = 'Room', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/customer/$customerId/assetInfos',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseRoomInfoPageData, response.data!);
  }

  Future<List<Room>> getRoomsByIds(List<String> assetIds,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<List<dynamic>>('/api/assets',
        queryParameters: {'assetIds': assetIds.join(',')},
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => Room.fromJson(e)).toList();
  }

  Future<List<Room>> findByQuery(RoomSearchQuery query,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<List<dynamic>>('/api/assets',
        data: jsonEncode(query),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => Room.fromJson(e)).toList();
  }

  Future<List<EntitySubtype>> getRoomTypes(
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<List<dynamic>>('/api/asset/types',
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => EntitySubtype.fromJson(e)).toList();
  }

  Future<Room?> assignRoomToEdge(String edgeId, String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/edge/$edgeId/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Room.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<Room?> unassignRoomFromEdge(String edgeId, String assetId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.delete<Map<String, dynamic>>(
            '/api/edge/$edgeId/asset/$assetId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Room.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<Room>> getEdgeRooms(String edgeId, PageLink pageLink,
      {String type = 'Room', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/edge/$edgeId/assets',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseRoomPageData, response.data!);
  }
}
