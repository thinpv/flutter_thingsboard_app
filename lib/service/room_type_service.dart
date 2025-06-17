import 'dart:convert';

import 'package:thingsboard_app/model/room_type_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

PageData<RoomType> parseRoomTypePageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => RoomType.fromJson(json));
}

PageData<RoomTypeInfo> parseRoomTypeInfoPageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => RoomTypeInfo.fromJson(json));
}

class RoomTypeService {
  static RoomTypeService? _instance;
  final ThingsboardClient _tbClient;

  factory RoomTypeService(ThingsboardClient tbClient) {
    return RoomTypeService._internal(tbClient);
  }

  RoomTypeService._internal(this._tbClient);

  static void init(ThingsboardClient client) {
    _instance = RoomTypeService._internal(client);
  }

  static RoomTypeService get instance {
    if (_instance == null) {
      throw Exception('RoomTypeService chưa được khởi tạo!');
    }
    return _instance!;
  }

  Future<PageData<RoomType>> getRoomTypes(PageLink pageLink,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/assetProfiles',
        queryParameters: pageLink.toQueryParameters(),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseRoomTypePageData, response.data!);
  }

  Future<RoomType?> getRoomType(String roomTypeId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/assetProfile/$roomTypeId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? RoomType.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<RoomType> saveRoomType(RoomType assetProfile,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<Map<String, dynamic>>(
        '/api/assetProfile',
        data: jsonEncode(assetProfile),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return RoomType.fromJson(response.data!);
  }

  Future<void> deleteRoomType(String roomTypeId,
      {RequestConfig? requestConfig}) async {
    await _tbClient.delete('/api/assetProfile/$roomTypeId',
        options: defaultHttpOptionsFromConfig(requestConfig));
  }

  Future<RoomType> setDefaultRoomType(String roomTypeId,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<Map<String, dynamic>>(
        '/api/assetProfile/$roomTypeId/default',
        options: defaultHttpOptionsFromConfig(requestConfig));
    return RoomType.fromJson(response.data!);
  }

  Future<RoomTypeInfo> getDefaultRoomTypeInfo(
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/assetProfileInfo/default',
        options: defaultHttpOptionsFromConfig(requestConfig));
    return RoomTypeInfo.fromJson(response.data!);
  }

  Future<RoomTypeInfo?> getRoomTypeInfo(String roomTypeId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/assetProfileInfo/$roomTypeId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null
            ? RoomTypeInfo.fromJson(response.data!)
            : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<RoomTypeInfo>> getRoomTypeInfos(PageLink pageLink,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/assetProfileInfos',
        queryParameters: pageLink.toQueryParameters(),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseRoomTypeInfoPageData, response.data!);
  }
}
