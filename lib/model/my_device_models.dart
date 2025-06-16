import 'package:flutter/material.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class MyDevice extends Device {
  MyDevice.fromJson(Map<String, dynamic> json) : super.fromJson(json);
}

class MyDeviceInfo extends DeviceInfo with ChangeNotifier {
  bool isGateway = false;
  String? gatewayId;
  TelemetrySubscriber? subscription;

  MyDeviceInfo.fromJson(Map<String, dynamic> json)
      : gatewayId = json['additionalInfo'] != null &&
                json['additionalInfo']['lastConnectedGateway'] != null
            ? json['additionalInfo']['lastConnectedGateway']
            : null,
        isGateway = json['additionalInfo'] != null &&
            json['additionalInfo']['gateway'] != null,
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

  void subscribe(ThingsboardClient tbClient) {
    print('-----------subscribe to MyDevice: $name');
    var entityFilter =
        EntityNameFilter(entityType: EntityType.DEVICE, entityNameFilter: name);
    var deviceFields = <EntityKey>[
      EntityKey(type: EntityKeyType.ENTITY_FIELD, key: 'name'),
      EntityKey(type: EntityKeyType.ENTITY_FIELD, key: 'type'),
      EntityKey(type: EntityKeyType.ENTITY_FIELD, key: 'createdTime')
    ];
    var deviceTelemetry = <EntityKey>[
      EntityKey(type: EntityKeyType.TIME_SERIES, key: 'temperature'),
      EntityKey(type: EntityKeyType.TIME_SERIES, key: 'humidity')
    ];

    var devicesQuery = EntityDataQuery(
        entityFilter: entityFilter,
        entityFields: deviceFields,
        latestValues: deviceTelemetry,
        pageLink: EntityDataPageLink(
            pageSize: 10,
            sortOrder: EntityDataSortOrder(
                key: EntityKey(
                    type: EntityKeyType.ENTITY_FIELD, key: 'createdTime'),
                direction: EntityDataSortOrderDirection.DESC)));

    var currentTime = DateTime.now().millisecondsSinceEpoch;
    var timeWindow = Duration(hours: 1).inMilliseconds;

    var tsCmd = TimeSeriesCmd(
        keys: ['temperature', 'humidity'],
        startTs: currentTime - timeWindow,
        timeWindow: timeWindow);

    var cmd = EntityDataCmd(query: devicesQuery, tsCmd: tsCmd);

    var telemetryService = tbClient.getTelemetryService();

    subscription = TelemetrySubscriber(telemetryService, [cmd]);
    if (subscription != null) {
      subscription!.entityDataStream.listen((entityDataUpdate) {
        print(
            '[WebSocket Data]: Received entity data update: $entityDataUpdate');
      });
      subscription!.subscribe();
    }
  }

  void unsubscribe() {
    if (subscription != null) {
      print('-----------unsubscribe from MyDevice: $name');
      subscription!.unsubscribe();
      subscription = null;
    }
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
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
