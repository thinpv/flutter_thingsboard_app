import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class MinihubV1Models extends MyDeviceInfo {
  MinihubV1Models.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  void subscribe(ThingsboardClient tbClient) {
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

    var subscription = TelemetrySubscriber(telemetryService, [cmd]);

    subscription.entityDataStream.listen((entityDataUpdate) {
      print('[WebSocket Data]: Received entity data update: $entityDataUpdate');
    });

    subscription.subscribe();
  }
}
