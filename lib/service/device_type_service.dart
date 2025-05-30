import 'dart:convert';

import 'package:thingsboard_app/model/device_type_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

PageData<DeviceType> parseDeviceTypePageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => DeviceType.fromJson(json));
}

PageData<DeviceTypeInfo> parseDeviceTypeInfoPageData(
    Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => DeviceTypeInfo.fromJson(json));
}

class DeviceTypeService {
  static DeviceTypeService? _instance;
  final ThingsboardClient _tbClient;

  factory DeviceTypeService(ThingsboardClient tbClient) {
    return DeviceTypeService._internal(tbClient);
  }

  DeviceTypeService._internal(this._tbClient);

  static void init(ThingsboardClient client) {
    _instance = DeviceTypeService._internal(client);
  }

  static DeviceTypeService get instance {
    if (_instance == null) {
      throw Exception('DeviceTypeService chưa được khởi tạo!');
    }
    return _instance!;
  }

  Future<PageData<DeviceType>> getDeviceTypes(PageLink pageLink,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/deviceProfiles',
        queryParameters: pageLink.toQueryParameters(),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseDeviceTypePageData, response.data!);
  }

  Future<DeviceType?> getDeviceType(String deviceProfileId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/deviceProfile/$deviceProfileId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null
            ? DeviceType.fromJson(response.data!)
            : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<DeviceType> saveDeviceType(DeviceType deviceProfile,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<Map<String, dynamic>>(
        '/api/deviceProfile',
        data: jsonEncode(deviceProfile),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return DeviceType.fromJson(response.data!);
  }

  Future<void> deleteDeviceType(String deviceProfileId,
      {RequestConfig? requestConfig}) async {
    await _tbClient.delete('/api/deviceProfile/$deviceProfileId',
        options: defaultHttpOptionsFromConfig(requestConfig));
  }

  Future<DeviceType> setDefaultDeviceType(String deviceProfileId,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<Map<String, dynamic>>(
        '/api/deviceProfile/$deviceProfileId/default',
        options: defaultHttpOptionsFromConfig(requestConfig));
    return DeviceType.fromJson(response.data!);
  }

  Future<DeviceTypeInfo> getDefaultDeviceTypeInfo(
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/deviceProfileInfo/default',
        options: defaultHttpOptionsFromConfig(requestConfig));
    return DeviceTypeInfo.fromJson(response.data!);
  }

  Future<DeviceTypeInfo?> getDeviceTypeInfo(String deviceProfileId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/deviceProfileInfo/$deviceProfileId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null
            ? DeviceTypeInfo.fromJson(response.data!)
            : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<DeviceTypeInfo>> getDeviceTypeInfos(PageLink pageLink,
      {DeviceTransportType? transportType,
      RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    if (transportType != null) {
      queryParams['transportType'] = transportType.toShortString();
    }
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/deviceProfileInfos',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseDeviceTypeInfoPageData, response.data!);
  }

  Future<List<String>> getDeviceTypeDevicesAttributesKeys(
      {String? deviceProfileId, RequestConfig? requestConfig}) async {
    var queryParams = <String, dynamic>{};
    if (deviceProfileId != null) {
      queryParams['deviceProfileId'] = deviceProfileId;
    }
    var response = await _tbClient.get<List<String>>(
        '/api/deviceProfile/devices/keys/attributes',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!;
  }

  Future<List<String>> getDeviceTypeDevicesTimeseriesKeys(
      {String? deviceProfileId, RequestConfig? requestConfig}) async {
    var queryParams = <String, dynamic>{};
    if (deviceProfileId != null) {
      queryParams['deviceProfileId'] = deviceProfileId;
    }
    var response = await _tbClient.get<List<String>>(
        '/api/deviceProfile/devices/keys/timeseries',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!;
  }
}
