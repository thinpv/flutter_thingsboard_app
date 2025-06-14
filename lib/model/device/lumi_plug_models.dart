import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class LumiPlug extends MyDeviceInfo {
  int bt = -1;

  LumiPlug.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  void subscribe(ThingsboardClient tbClient) {
    print('-----------subscribe to LumiPlug: $name');
    var entityFilter =
        EntityNameFilter(entityType: EntityType.DEVICE, entityNameFilter: name);
    var deviceFields = <EntityKey>[
      EntityKey(type: EntityKeyType.ENTITY_FIELD, key: 'name'),
      // EntityKey(type: EntityKeyType.ENTITY_FIELD, key: 'type'),
      // EntityKey(type: EntityKeyType.ENTITY_FIELD, key: 'createdTime')
    ];
    var deviceTelemetry = <EntityKey>[
      EntityKey(type: EntityKeyType.TIME_SERIES, key: 'bt'),
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
        keys: ['bt'],
        startTs: currentTime - timeWindow,
        timeWindow: timeWindow);

    var cmd = EntityDataCmd(query: devicesQuery, tsCmd: tsCmd);

    var telemetryService = tbClient.getTelemetryService();

    subscription = TelemetrySubscriber(telemetryService, [cmd]);
    if (subscription != null) {
      subscription!.entityDataStream.listen((entityDataUpdate) {
        print(
            '[WebSocket Data]: Received entity data update: $entityDataUpdate');
        entityDataUpdate.update?.forEach((entityData) {
          var btValue = entityData.timeseries['bt'];
          if (btValue != null && btValue.isNotEmpty) {
            bt = int.parse(btValue.last.value ?? '0');
          }
        });
        notifyListeners();
      });
      subscription!.subscribe();
    }
  }

  @override
  String toString() {
    return 'LumiPlug(bt: $bt)';
  }
}
