import 'package:thingsboard_client/thingsboard_client.dart';

class MyDevice extends Device {
  MyDevice.fromJson(Map<String, dynamic> json) : super.fromJson(json);
}

class MyDeviceInfo extends DeviceInfo {
  String? gatewayId;

  MyDeviceInfo.fromJson(Map<String, dynamic> json)
      : gatewayId = json['additionalInfo'] != null &&
                json['additionalInfo']['lastConnectedGateway'] != null
            ? json['additionalInfo']['lastConnectedGateway']
            : null,
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    additionalInfo ??= {};
    if (gatewayId != null) {
      additionalInfo!['lastConnectedGateway'] = gatewayId;
    }
    return super.toJson();
  }

  String getDisplayName() {
    if (label != null && label!.isNotEmpty) {
      return label!;
    } else {
      return name;
    }
  }
}

class MyDeviceSearchQuery extends EntitySearchQuery {
  List<String> deviceTypes;

  MyDeviceSearchQuery(
      {required RelationsSearchParameters parameters,
      required this.deviceTypes,
      String? relationType})
      : super(parameters: parameters, relationType: relationType);

  @override
  Map<String, dynamic> toJson() {
    var json = super.toJson();
    json['deviceTypes'] = deviceTypes;
    return json;
  }

  @override
  String toString() {
    return 'DeviceSearchQuery{${entitySearchQueryString('deviceTypes: $deviceTypes')}}';
  }
}

class MyDeviceCredentials extends BaseData<DeviceCredentialsId> {
  DeviceId deviceId;
  DeviceCredentialsType credentialsType;
  String credentialsId;
  String? credentialsValue;

  MyDeviceCredentials.fromJson(Map<String, dynamic> json)
      : deviceId = DeviceId.fromJson(json['deviceId']),
        credentialsType =
            deviceCredentialsTypeFromString(json['credentialsType']),
        credentialsId = json['credentialsId'],
        credentialsValue = json['credentialsValue'],
        super.fromJson(json, (id) => DeviceCredentialsId(id));

  @override
  Map<String, dynamic> toJson() {
    var json = super.toJson();
    json['deviceId'] = deviceId.toJson();
    json['credentialsType'] = credentialsType.toShortString();
    json['credentialsId'] = credentialsId;
    if (credentialsValue != null) {
      json['credentialsValue'] = credentialsValue;
    }
    return json;
  }

  @override
  String toString() {
    return 'DeviceCredentials{${baseDataString('deviceId: $deviceId, credentialsType: ${credentialsType.toShortString()}, '
        'credentialsId: $credentialsId, credentialsValue: $credentialsValue')}}';
  }
}
