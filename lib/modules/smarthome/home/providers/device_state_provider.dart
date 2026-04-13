import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_profile_ui_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

/// Telemetry keys the device cards care about. Everything here is pulled in
/// one shared EntityDataQuery subscription instead of one-per-device, which
/// keeps WebSocket subscription counts flat regardless of device count.
const _cardTelemetryKeys = <String>[
  'onoff0', 'onoff1', 'onoff2', 'onoff3',
  'bt', 'bt0', 'bt1', 'bt2',
  'dim', 'h', 's', 'l', 'ct', 'color_mode',
  'temp', 'hum', 'pressure',
  'pir', 'lux', 'distance',
  'door', 'leak', 'smoke', 'gas', 'vibration',
  'bat', 'pin',
  'lock', 'action',
  'pos',
  'power', 'volt', 'curr', 'energy',
  'pm1_0', 'pm2_5', 'pm10', 'co2',
  'stt',
  'cpu', 'mem', 'uptime', 'dev_cnt',
];

/// Server attributes pulled in the same subscription.
const _cardServerAttrs = <String>['active', 'ui_type', 'default_label'];

/// Converts TB's text-encoded active flag to bool. TB returns booleans as
/// the literal string "true"/"false" through entity data queries.
bool _resolveOnline(String? active) =>
    active == 'true' || active == '1' || active == 'True';

/// Resolves profileImage + fallback uiType for every device in parallel.
/// `DeviceProfileUiService.getProfileMeta` is cached per profile ID, so 400
/// devices sharing ~20 profiles only hit the network ~20 times.
Future<List<SmarthomeDevice>> _resolveProfileMeta(
    List<SmarthomeDevice> devices) {
  final svc = DeviceProfileUiService();
  return Future.wait(devices.map((d) async {
    final meta = await svc.getProfileMeta(d.deviceProfileId);
    return d.copyWith(
      uiType: meta.uiType,
      profileImage: meta.profileImage,
    );
  }));
}

/// Live device stream backed by a single EntityDataQuery WebSocket
/// subscription.
///
/// The query resolves all devices related to [rootAssetId] via a Contains
/// relation and subscribes to their latest telemetry + key server attributes.
/// TB streams both the initial page and incremental updates on the same cmd
/// id, so a room with 400 devices still only consumes one subscription
/// instead of 800 (per-device telemetry + per-device server attr).
///
/// The stream yields a snapshot of the current device list whenever TB sends
/// an update. Updates are merged into the existing state map so partial
/// payloads (e.g. only `onoff0` changed) don't wipe previously-received keys.
Stream<List<SmarthomeDevice>> _entityDataStream(
  List<SmarthomeDevice> initial,
  String rootAssetId,
  void Function(void Function()) onDispose,
) async* {
  if (initial.isEmpty) {
    yield [];
    return;
  }

  final stateMap = {for (final d in initial) d.id: d};
  // Separate telemetry cache so partial updates can merge without losing
  // previously-received keys.
  final telMap = {for (final d in initial) d.id: <String, dynamic>{}};

  final controller = StreamController<List<SmarthomeDevice>>.broadcast();
  onDispose(controller.close);

  final latestKeys = <EntityKey>[
    for (final k in _cardServerAttrs)
      EntityKey(type: EntityKeyType.SERVER_ATTRIBUTE, key: k),
    for (final k in _cardTelemetryKeys)
      EntityKey(type: EntityKeyType.TIME_SERIES, key: k),
  ];

  final query = EntityDataQuery(
    entityFilter: RelationsQueryFilter(
      rootEntity: AssetId(rootAssetId),
      filters: [
        RelationEntityTypeFilter('Contains', [EntityType.DEVICE]),
      ],
    ),
    // `isDynamic: true` asks TB to keep streaming updates as entities enter
    // or leave the query result (e.g. gateway provisions a new sub-device).
    pageLink: EntityDataPageLink(pageSize: 1024, isDynamic: true),
    entityFields: [
      EntityKey(type: EntityKeyType.ENTITY_FIELD, key: 'name'),
      EntityKey(type: EntityKeyType.ENTITY_FIELD, key: 'label'),
    ],
    latestValues: latestKeys,
  );

  final cmd = EntityDataCmd(
    query: query,
    latestCmd: LatestValueCmd(keys: latestKeys),
  );

  final telemetryService =
      getIt<ITbClientService>().client.getTelemetryService();
  final subscriber = TelemetrySubscriber(telemetryService, [cmd]);
  onDispose(subscriber.unsubscribe);

  subscriber.entityDataStream.listen((update) {
    final toProcess = <EntityData>[];
    if (update.data != null) toProcess.addAll(update.data!.data);
    if (update.update != null) toProcess.addAll(update.update!);

    for (final ed in toProcess) {
      final id = ed.entityId.id!;
      var device = stateMap[id];
      if (device == null) {
        // New device appeared in the query result after the initial page
        // (e.g. gateway just connected a new sub-device).
        device = SmarthomeDevice(
          id: id,
          name: ed.field('name') ?? id,
          type: '',
          label: ed.field('label'),
        );
        telMap[id] = {};
      }

      // Merge telemetry values.
      final tel = telMap[id]!;
      final tsMap = ed.latest[EntityKeyType.TIME_SERIES];
      if (tsMap != null) {
        for (final entry in tsMap.entries) {
          if (entry.value.value != null) {
            tel[entry.key] = entry.value.value;
          }
        }
      }

      // Server attrs.
      final serverAttrs = ed.latest[EntityKeyType.SERVER_ATTRIBUTE];
      String? active;
      String? uiType;
      String? defaultLabel;
      if (serverAttrs != null) {
        active = serverAttrs['active']?.value;
        uiType = serverAttrs['ui_type']?.value;
        defaultLabel = serverAttrs['default_label']?.value;
      }

      stateMap[id] = device.copyWith(
        label: (device.label == null || device.label!.isEmpty)
            ? defaultLabel
            : null,
        uiType: uiType,
        isOnline: active != null ? _resolveOnline(active) : null,
        telemetry: Map.unmodifiable(tel),
      );
    }

    if (!controller.isClosed) {
      controller.add(List.unmodifiable(stateMap.values));
    }
  });

  subscriber.subscribe();

  yield List.unmodifiable(stateMap.values);
  yield* controller.stream;
}

/// Streams devices in [roomId] with live telemetry + connectivity updates.
final devicesInRoomProvider =
    StreamProvider.family<List<SmarthomeDevice>, String>(
  (ref, roomId) async* {
    debugPrint('[SmartHome] devicesInRoomProvider start: roomId=$roomId');
    final raw = await HomeService().fetchDevicesInRoom(roomId);
    debugPrint('[SmartHome] devicesInRoomProvider fetched ${raw.length} devices for room=$roomId');
    // Yield raw devices immediately so cards appear without waiting for
    // profile image resolution (which can take seconds with many devices).
    // Profile meta resolves concurrently and the WebSocket stream will
    // push uiType via server attribute anyway.
    yield* _entityDataStreamWithMeta(raw, roomId, ref.onDispose);
  },
);

/// Streams devices directly under the home asset (gateways + unassigned).
final devicesInHomeProvider =
    StreamProvider.family<List<SmarthomeDevice>, String>(
  (ref, homeId) async* {
    debugPrint('[SmartHome] devicesInHomeProvider start: homeId=$homeId');
    final raw = await HomeService().fetchDevicesInHome(homeId);
    debugPrint('[SmartHome] devicesInHomeProvider fetched ${raw.length} devices for home=$homeId');
    yield* _entityDataStreamWithMeta(raw, homeId, ref.onDispose);
  },
);

/// Starts the entity data stream immediately (no wait for profile meta), then
/// injects profileImage once it resolves in the background.
///
/// Devices appear in the UI as soon as REST fetch completes. uiType arrives
/// via the WebSocket server-attribute subscription. profileImage arrives once
/// profile meta resolves — typically within a few hundred ms for cached profiles.
Stream<List<SmarthomeDevice>> _entityDataStreamWithMeta(
  List<SmarthomeDevice> raw,
  String rootAssetId,
  void Function(void Function()) onDispose,
) async* {
  // profileImage cache: deviceId → image URL (populated by _resolveProfileMeta)
  final imageMap = <String, String?>{};

  // Giữ snapshot cuối cùng từ WS để merge image vào đúng data
  List<SmarthomeDevice>? lastSnapshot;

  // Controller that merges WebSocket updates with profileImage injections.
  final merged = StreamController<List<SmarthomeDevice>>.broadcast();
  onDispose(merged.close);

  // Start WebSocket stream — yields raw devices immediately.
  final wsStream = _entityDataStream(raw, rootAssetId, onDispose);

  // Forward WebSocket updates, overriding profileImage from our cache.
  wsStream.listen(
    (devices) {
      lastSnapshot = devices;
      if (merged.isClosed) return;
      if (imageMap.isEmpty) {
        merged.add(devices);
      } else {
        merged.add(devices
            .map((d) => imageMap.containsKey(d.id)
                ? d.copyWith(profileImage: imageMap[d.id])
                : d)
            .toList());
      }
    },
    onError: (Object e) { if (!merged.isClosed) merged.addError(e); },
    onDone: () { if (!merged.isClosed) merged.close(); },
  );

  // Resolve profile meta concurrently — re-emit LAST WS snapshot với images.
  // Không dùng `withMeta` trực tiếp vì nó là stale REST data (không có telemetry).
  _resolveProfileMeta(raw).then((withMeta) {
    debugPrint('[SmartHome] profile meta resolved for $rootAssetId: ${withMeta.length} devices');
    if (merged.isClosed) return;
    int withImage = 0;
    for (final d in withMeta) {
      imageMap[d.id] = d.profileImage;
      if (d.profileImage != null) withImage++;
    }
    debugPrint('[SmartHome] imageMap populated: ${imageMap.length} entries, $withImage with image, lastSnapshot=${lastSnapshot?.length}');
    final base = lastSnapshot;
    if (base != null) {
      final injected = base
          .map((d) => imageMap.containsKey(d.id)
              ? d.copyWith(profileImage: imageMap[d.id])
              : d)
          .toList();
      final injectedCount = injected.where((d) => d.profileImage != null).length;
      debugPrint('[SmartHome] re-emitting snapshot: ${injected.length} devices, $injectedCount with profileImage');
      merged.add(injected);
    } else {
      debugPrint('[SmartHome] lastSnapshot is null — no re-emit, images will inject via next WS update');
    }
  }).catchError((e) {
    debugPrint('[SmartHome] _resolveProfileMeta error: $e');
  });

  yield* merged.stream;
}
