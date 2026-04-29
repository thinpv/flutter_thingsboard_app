import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/home/data/home_data_cache.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/data/profile_metadata_cache.dart';
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
  'dim', 'h', 's', 'l', 'ct', 'colorMode',
  'temp', 'hum', 'pressure',
  'pir', 'lux', 'distance',
  'door', 'leak', 'smoke', 'gas', 'vibration',
  'bat', 'pin',
  'lock', 'action',
  'pos',
  'power', 'volt', 'curr', 'energy',
  'pm1_0', 'pm2_5', 'pm10', 'co2',
  'stt',
  'cpu', 'mem', 'uptime', 'devCnt',
];

/// Server attributes pulled in the same subscription.
const _cardServerAttrs = <String>['active', 'uiType', 'defaultLabel'];

/// Client attributes pulled in the same subscription.
/// `name` is published by the gateway via v1/gateway/attributes when a
/// sub-device is provisioned — it holds the human-readable device name.
const _cardClientAttrs = <String>['name'];

/// Converts TB's text-encoded active flag to bool. TB returns booleans as
/// the literal string "true"/"false" through entity data queries.
bool _resolveOnline(String? active) =>
    active == 'true' || active == '1' || active == 'True';

/// Resolves profileImage + uiType + profileName for every device in parallel.
/// `DeviceProfileUiService.getProfileMeta` is cached per profile ID, so 400
/// devices sharing ~20 profiles only hit the network ~20 times.
Future<List<MapEntry<String, DeviceUiMeta>>> _resolveProfileMeta(
    List<SmarthomeDevice> devices) {
  final svc = DeviceProfileUiService();
  return Future.wait(devices.map((d) async {
    final meta = await svc.getProfileMeta(d.deviceProfileId);
    return MapEntry(d.id, meta);
  }));
}

/// Fast Hive-only resolve: returns uiType + profileName + profileImage (if cached).
/// Used to pre-populate maps before WebSocket connects so the first
/// `injectImages()` call already has full data — no HTTP needed for cached profiles.
Future<List<MapEntry<String, DeviceUiMeta>>> _resolveProfileMetaFromHive(
    List<SmarthomeDevice> devices) {
  final cache = ProfileMetadataCache.instance;
  // Deduplicate by profileId so we don't read Hive multiple times for the same profile.
  final profileToDevices = <String, List<String>>{};
  for (final d in devices) {
    if (d.deviceProfileId != null) {
      profileToDevices.putIfAbsent(d.deviceProfileId!, () => []).add(d.id);
    }
  }

  return Future.wait(profileToDevices.entries.map((entry) async {
    final profileId = entry.key;
    final deviceIds = entry.value;
    final cachedMeta = await cache.get(profileId);
    final cachedImage = await cache.getImage(profileId);

    final uiType = (cachedMeta != null && !cachedMeta.isEmpty)
        ? (cachedMeta.uiType == 'auto' ? null : cachedMeta.uiType)
        : null;
    final profileName = (cachedMeta != null && !cachedMeta.isEmpty)
        ? cachedMeta.localizedName('vi')
        : null;

    final meta = DeviceUiMeta(
      uiType: uiType,
      profileName: profileName,
      profileImage: cachedImage,
    );
    // Return one entry per device sharing this profile
    return deviceIds.map((id) => MapEntry(id, meta));
  })).then((lists) => lists.expand((e) => e).toList());
}

/// Populates `profileName` and `profileImage` on a list of devices using the
/// Hive-cached profile metadata. For places that don't subscribe to the live
/// device stream (e.g. automation device picker) but still need the unified
/// 3-level display name priority.
Future<List<SmarthomeDevice>> resolveDeviceProfileMetaFromCache(
    List<SmarthomeDevice> devices) async {
  if (devices.isEmpty) return devices;
  final entries = await _resolveProfileMetaFromHive(devices);
  final metaById = {for (final e in entries) e.key: e.value};
  return devices.map((d) {
    final meta = metaById[d.id];
    if (meta == null) return d;
    return d.copyWith(
      profileName: meta.profileName,
      profileImage: meta.profileImage,
    );
  }).toList();
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
    for (final k in _cardClientAttrs)
      EntityKey(type: EntityKeyType.CLIENT_ATTRIBUTE, key: k),
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
        final rawUiType = serverAttrs['uiType']?.value;
        uiType = (rawUiType != null && rawUiType.isNotEmpty) ? rawUiType : null;
        defaultLabel = serverAttrs['defaultLabel']?.value;
      }

      // Client attrs — `name` is the friendly name published by the gateway
      // via v1/gateway/attributes when it provisions a sub-device.
      final clientAttrs = ed.latest[EntityKeyType.CLIENT_ATTRIBUTE];
      String? clientName;
      if (clientAttrs != null) {
        clientName = clientAttrs['name']?.value;
      }

      stateMap[id] = device.copyWith(
        // defaultLabel (server attr, admin-controlled) → label field (high priority)
        label: (device.label == null || device.label!.isEmpty) && defaultLabel != null
            ? defaultLabel
            : null,
        // clientName (gateway client attr) → gatewayName field (lower priority,
        // ranked after profileName so a UUID-like gateway ID never shows over
        // the human-readable profile type name).
        gatewayName: clientName,
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
///
/// Cache-first: yields the Hive-cached device list immediately so cards
/// appear instantly on warm start, then fetches the fresh list over HTTP
/// and hands off to the WebSocket-backed stream.
final devicesInRoomProvider =
    StreamProvider.family<List<SmarthomeDevice>, String>(
  (ref, roomId) async* {
    final cached = HomeDataCache.instance.getDevices(roomId);
    if (cached != null && cached.isNotEmpty) {
      yield cached;
    }
    final raw = await HomeService().fetchDevicesInRoom(roomId);
    await HomeDataCache.instance.saveDevices(roomId, raw);
    yield* _entityDataStreamWithMeta(raw, roomId, ref.onDispose);
  },
);

/// Streams devices directly under the home asset (gateways + unassigned).
final devicesInHomeProvider =
    StreamProvider.family<List<SmarthomeDevice>, String>(
  (ref, homeId) async* {
    final cached = HomeDataCache.instance.getDevices(homeId);
    if (cached != null && cached.isNotEmpty) {
      yield cached;
    }
    final raw = await HomeService().fetchDevicesInHome(homeId);
    await HomeDataCache.instance.saveDevices(homeId, raw);
    yield* _entityDataStreamWithMeta(raw, homeId, ref.onDispose);
  },
);

/// Starts the entity data stream, ensuring profile metadata is populated before
/// the first emit so device names and icons are correct on the initial render.
///
/// Strategy:
///   1. Try Hive cache (fast, ~1-5ms) — warm on second+ launch within 24h.
///   2. If any device profile is missing from Hive (first install, cache
///      expired, or cleared by a previous refresh), block until the network
///      fetch completes so the first render shows correct names and icons
///      instead of UUID-like device names and generic icons.
///   3. For Hive-hit profiles: background-refresh to keep cache warm.
Stream<List<SmarthomeDevice>> _entityDataStreamWithMeta(
  List<SmarthomeDevice> raw,
  String rootAssetId,
  void Function(void Function()) onDispose,
) async* {
  // Profile meta caches: deviceId → value (populated by _resolveProfileMeta).
  final imageMap = <String, String?>{};
  final uiTypeMap = <String, String?>{};
  // profileName: device type name from profile description (e.g. "LUMI Smart Switch").
  // Used as label fallback when neither device label nor client attr `name` is set.
  final profileNameMap = <String, String?>{};
  // IDs for which profile meta has already been (or is being) resolved.
  final resolvedIds = <String>{for (final d in raw) d.id};

  // Step 1: Pre-populate maps from Hive (local, ~1-5ms) BEFORE WebSocket connects.
  if (raw.isNotEmpty) {
    final hiveMetas = await _resolveProfileMetaFromHive(raw);
    for (final e in hiveMetas) {
      if (e.value.profileImage != null) imageMap[e.key] = e.value.profileImage;
      if (e.value.uiType != null) uiTypeMap[e.key] = e.value.uiType;
      if (e.value.profileName != null) profileNameMap[e.key] = e.value.profileName;
    }
  }

  // Step 2: Don't block on network meta resolution — render whatever Hive
  // gave us (or bare device names on first launch) and let the background
  // refresh below fill in icons/names when the HTTP responses arrive.
  // Blocking here was the dominant cause of cold-start lag; with cache-first
  // device lists already showing instantly, we cannot afford to gate the
  // first render on a profile metadata fetch.

  // Tracks the most recent WebSocket snapshot so profile-meta resolution can
  // re-emit it (with images injected) instead of the stale raw list.
  List<SmarthomeDevice>? lastSnapshot;

  // Single-subscription controller so events buffered before yield* merged.stream
  // are not dropped (broadcast controllers drop events with no listener).
  final merged = StreamController<List<SmarthomeDevice>>();
  onDispose(merged.close);

  List<SmarthomeDevice> injectImages(List<SmarthomeDevice> devices) => devices
      .map((d) {
        var dev = d;
        if (imageMap.containsKey(d.id)) {
          dev = dev.copyWith(profileImage: imageMap[d.id]);
        }
        // Only inject profile uiType if no per-device ui_type server attribute
        // was received from the WebSocket (per-device override takes priority).
        if (uiTypeMap.containsKey(d.id) && dev.uiType == null) {
          dev = dev.copyWith(uiType: uiTypeMap[d.id]);
        }
        // Populate profileName field (3-level displayName priority handles
        // fallback: label > profileName > name).
        if (profileNameMap.containsKey(d.id) &&
            profileNameMap[d.id] != null &&
            dev.profileName != profileNameMap[d.id]) {
          dev = dev.copyWith(profileName: profileNameMap[d.id]);
        }
        return dev;
      })
      .toList();

  // Start WebSocket stream — yields raw devices immediately.
  final wsStream = _entityDataStream(raw, rootAssetId, onDispose);

  // Forward WebSocket updates, overriding profileImage from our cache.
  // Also detect brand-new devices (added after provider started via isDynamic)
  // and resolve their profile meta on the fly.
  wsStream.listen(
    (devices) {
      lastSnapshot = devices;
      if (merged.isClosed) return;
      lastSnapshot = devices;

      // Detect new devices that haven't had profile meta resolved yet.
      final newIds = devices
          .where((d) => !resolvedIds.contains(d.id))
          .map((d) => d.id)
          .toList();
      if (newIds.isNotEmpty) {
        // Mark immediately to avoid duplicate resolution on rapid updates.
        resolvedIds.addAll(newIds);
        _resolveNewDevicesMeta(newIds).then((entries) {
          if (merged.isClosed) return;
          for (final e in entries) {
            imageMap[e.key] = e.value.profileImage;
            if (e.value.uiType != null) uiTypeMap[e.key] = e.value.uiType;
            if (e.value.profileName != null) profileNameMap[e.key] = e.value.profileName;
          }
          final snap = lastSnapshot;
          if (snap != null) merged.add(injectImages(snap));
        });
      }

      merged.add(injectImages(devices));
    },
    onError: (Object e) { if (!merged.isClosed) merged.addError(e); },
    onDone: () { if (!merged.isClosed) merged.close(); },
  );

  // Step 3: Background refresh.
  // - Hive-hit path: keeps cache warm and picks up profile description changes.
  // - Cache-miss + timeout path: re-emits once the network eventually responds,
  //   so the user sees correct names/icons without needing a manual refresh.
  // _profileMetaCache in DeviceProfileUiService deduplicates in-flight requests,
  // so this never sends redundant HTTP calls when step 2 already fetched data.
  if (raw.isNotEmpty) {
    _resolveProfileMeta(raw).then((entries) {
      if (merged.isClosed) return;
      for (final e in entries) {
        imageMap[e.key] = e.value.profileImage;
        if (e.value.uiType != null) uiTypeMap[e.key] = e.value.uiType;
        if (e.value.profileName != null) profileNameMap[e.key] = e.value.profileName;
      }
      // Re-emit the latest snapshot with refreshed meta injected.
      final snap = lastSnapshot ?? raw;
      final injected = injectImages(snap);
      merged.add(injected);
      // Persist profileName + WebSocket-resolved label to Hive so the next
      // warm start shows correct names immediately (no UUID flash on yield cached).
      HomeDataCache.instance.saveDevices(rootAssetId, injected);
    }).catchError((_) {});
  }

  yield* merged.stream;
}

/// Fetches the TB device record for each [deviceIds] entry to obtain its
/// [deviceProfileId], then resolves profile meta (image + uiType) via
/// [DeviceProfileUiService].
/// Used for devices that appeared dynamically via WebSocket (isDynamic) and
/// therefore lack [deviceProfileId] in the in-memory state.
Future<List<MapEntry<String, DeviceUiMeta>>> _resolveNewDevicesMeta(
    List<String> deviceIds) async {
  final client = getIt<ITbClientService>().client;
  final svc = DeviceProfileUiService();
  final results = await Future.wait(deviceIds.map((id) async {
    try {
      final device = await client.getDeviceService().getDevice(id);
      final profileId = device?.deviceProfileId?.id;
      final meta = await svc.getProfileMeta(profileId);
      return MapEntry(id, meta);
    } catch (_) {
      return MapEntry(id, DeviceUiMeta.empty);
    }
  }));
  return results;
}
