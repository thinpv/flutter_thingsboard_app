import 'dart:convert';

import 'package:thingsboard_app/model/device/lumi_plug_models.dart';
import 'package:thingsboard_app/model/device/minihub_v1_models.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

PageData<MyDeviceInfo> parseMyDeviceInfoPageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) {
    if (json['type'] == 'lumi.plug') return LumiPlug.fromJson(json);
    if (json['type'] == 'Minihub V1') {
      return MinihubV1Models.fromJson(json);
    }
    return MyDeviceInfo.fromJson(json);
  });
}

PageData<MyDevice> parseMyDevicePageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => MyDevice.fromJson(json));
}

PageData<Rpc> parseRpcPageData(Map<String, dynamic> json) {
  return PageData.fromJson(json, (json) => Rpc.fromJson(json));
}

class MyDeviceService {
  static MyDeviceService? _instance;
  final ThingsboardClient _tbClient;

  factory MyDeviceService(ThingsboardClient tbClient) {
    return MyDeviceService._internal(tbClient);
  }

  MyDeviceService._internal(this._tbClient);

  static void init(ThingsboardClient client) {
    _instance = MyDeviceService._internal(client);
  }

  static MyDeviceService get instance {
    if (_instance == null) {
      throw Exception('MyDeviceService chưa được khởi tạo!');
    }
    return _instance!;
  }

  Future<MyDevice?> getMyDevice(String deviceId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/device/$deviceId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? MyDevice.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<MyDeviceInfo?> getMyDeviceInfo(String deviceId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/device/info/$deviceId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null
            ? MyDeviceInfo.fromJson(response.data!)
            : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<MyDevice> saveMyDevice(MyDevice device,
      {String? accessToken, RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<Map<String, dynamic>>('/api/device',
        data: jsonEncode(device),
        queryParameters: {'accessToken': accessToken},
        options: defaultHttpOptionsFromConfig(requestConfig));
    return MyDevice.fromJson(response.data!);
  }

  Future<void> deleteMyDevice(String deviceId,
      {RequestConfig? requestConfig}) async {
    await _tbClient.delete('/api/device/$deviceId',
        options: defaultHttpOptionsFromConfig(requestConfig));
  }

  Future<MyDevice?> assignMyDeviceToCustomer(String customerId, String deviceId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/customer/$customerId/device/$deviceId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? MyDevice.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<MyDevice?> unassignMyDeviceFromCustomer(String deviceId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.delete<Map<String, dynamic>>(
            '/api/customer/device/$deviceId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? MyDevice.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<MyDevice?> assignMyDeviceToPublicCustomer(String deviceId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/customer/public/device/$deviceId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? MyDevice.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<MyDevice>> getTenantMyDevices(PageLink pageLink,
      {String type = '', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/tenant/devices',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseMyDevicePageData, response.data!);
  }

  Future<PageData<MyDeviceInfo>> getTenantMyDeviceInfos(PageLink pageLink,
      {String type = '',
      String deviceProfileId = '',
      RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    queryParams['deviceProfileId'] = deviceProfileId;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/tenant/deviceInfos',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseMyDeviceInfoPageData, response.data!);
  }

  Future<MyDevice?> getTenantMyDevice(String deviceName,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/tenant/devices',
            queryParameters: {'deviceName': deviceName},
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? MyDevice.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<MyDevice>> getCustomerMyDevices(
      String customerId, PageLink pageLink,
      {String type = '', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/customer/$customerId/devices',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseMyDevicePageData, response.data!);
  }

  Future<PageData<MyDeviceInfo>> getCustomerMyDeviceInfos(
      String customerId, PageLink pageLink,
      {String type = '',
      String deviceProfileId = '',
      RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    queryParams['deviceProfileId'] = deviceProfileId;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/customer/$customerId/deviceInfos',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseMyDeviceInfoPageData, response.data!);
  }

  Future<List<MyDevice>> getMyDevicesByIds(List<String> deviceIds,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<List<dynamic>>('/api/devices',
        queryParameters: {'deviceIds': deviceIds.join(',')},
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => MyDevice.fromJson(e)).toList();
  }

  Future<List<MyDevice>> findByQuery(MyDeviceSearchQuery query,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<List<dynamic>>('/api/devices',
        data: jsonEncode(query),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => MyDevice.fromJson(e)).toList();
  }

  Future<List<EntitySubtype>> getMyDeviceTypes(
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<List<dynamic>>('/api/device/types',
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!.map((e) => EntitySubtype.fromJson(e)).toList();
  }

  Future<ClaimResult> claimMyDevice(
      String deviceName, ClaimRequest claimRequest,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<Map<String, dynamic>>(
        '/api/customer/device/$deviceName/claim',
        data: jsonEncode(claimRequest),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return ClaimResult.fromJson(response.data!);
  }

  Future<void> reClaimMyDevice(String deviceName,
      {RequestConfig? requestConfig}) async {
    await _tbClient.delete('/api/customer/device/$deviceName/claim',
        options: defaultHttpOptionsFromConfig(requestConfig));
  }

  Future<MyDevice?> assignMyDeviceToTenant(String tenantId, String deviceId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/tenant/$tenantId/device/$deviceId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? MyDevice.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<int> countMyDevicesByMyDeviceProfileIdAndEmptyOtaPackage(
      OtaPackageType otaPackageType, String deviceProfileId,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.get<int>(
        '/api/devices/count/${otaPackageType.toShortString()}',
        queryParameters: {'deviceProfileId': deviceProfileId},
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data!;
  }

  Future<MyDeviceCredentials?> getMyDeviceCredentialsByMyDeviceId(
      String deviceId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/device/$deviceId/credentials',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null
            ? MyDeviceCredentials.fromJson(response.data!)
            : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<MyDeviceCredentials> saveMyDeviceCredentials(
      MyDeviceCredentials deviceCredentials,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post<Map<String, dynamic>>(
        '/api/device/credentials',
        data: jsonEncode(deviceCredentials),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return MyDeviceCredentials.fromJson(response.data!);
  }

  Future<void> handleOneWayMyDeviceRPCRequest(
      String deviceId, dynamic requestBody,
      {RequestConfig? requestConfig}) async {
    await _tbClient.post('/api/plugins/rpc/oneway/$deviceId',
        data: jsonEncode(requestBody),
        options: defaultHttpOptionsFromConfig(requestConfig));
  }

  Future<dynamic> handleTwoWayMyDeviceRPCRequest(
      String deviceId, dynamic requestBody,
      {RequestConfig? requestConfig}) async {
    var response = await _tbClient.post('/api/plugins/rpc/twoway/$deviceId',
        data: jsonEncode(requestBody),
        options: defaultHttpOptionsFromConfig(requestConfig));
    return response.data;
  }

  Future<Rpc?> getPersistedRpc(String rpcId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.get<Map<String, dynamic>>(
            '/api/plugins/rpc/persisted/$rpcId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? Rpc.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<Rpc>> getPersistedRpcByMyDevice(
      String deviceId, RpcStatus rpcStatus, PageLink pageLink,
      {RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['rpcStatus'] = rpcStatus.toShortString();
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/plugins/rpc/persisted/$deviceId',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseRpcPageData, response.data!);
  }

  Future<void> deletePersistedRpc(String rpcId,
      {RequestConfig? requestConfig}) async {
    await _tbClient.delete('/api/plugins/rpc/persisted/$rpcId',
        options: defaultHttpOptionsFromConfig(requestConfig));
  }

  Future<MyDevice?> assignMyDeviceToEdge(String edgeId, String deviceId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.post<Map<String, dynamic>>(
            '/api/edge/$edgeId/device/$deviceId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? MyDevice.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<MyDevice?> unassignMyDeviceFromEdge(String edgeId, String deviceId,
      {RequestConfig? requestConfig}) async {
    return nullIfNotFound(
      (RequestConfig requestConfig) async {
        var response = await _tbClient.delete<Map<String, dynamic>>(
            '/api/edge/$edgeId/device/$deviceId',
            options: defaultHttpOptionsFromConfig(requestConfig));
        return response.data != null ? MyDevice.fromJson(response.data!) : null;
      },
      requestConfig: requestConfig,
    );
  }

  Future<PageData<MyDevice>> getEdgeMyDevices(String edgeId, PageLink pageLink,
      {String type = '', RequestConfig? requestConfig}) async {
    var queryParams = pageLink.toQueryParameters();
    queryParams['type'] = type;
    var response = await _tbClient.get<Map<String, dynamic>>(
        '/api/edge/$edgeId/devices',
        queryParameters: queryParams,
        options: defaultHttpOptionsFromConfig(requestConfig));
    return _tbClient.compute(parseMyDevicePageData, response.data!);
  }
}
