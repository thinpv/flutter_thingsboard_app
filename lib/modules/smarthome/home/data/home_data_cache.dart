import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';

/// Hive-backed cache cho danh sách homes / rooms / devices của user hiện tại.
///
/// Mục đích: cho phép cache-first render — provider yield ngay snapshot cũ
/// để UI hiện ra tức thì, song song fetch HTTP để lấy bản mới. Không có TTL
/// vì mỗi lần đọc cache đều luôn kèm fetch mạng đè lên.
///
/// Chỉ persist các field "khung" (id, name, label, profileId, icon, order…).
/// Telemetry và isOnline đến từ WebSocket — không lưu cache.
class HomeDataCache {
  HomeDataCache._();
  static final instance = HomeDataCache._();

  static const _boxName = 'smarthome_data_cache';

  Box<String>? _box;
  bool get isReady => _box != null && _box!.isOpen;

  Future<void> init() async {
    if (isReady) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  // ─── Homes ──────────────────────────────────────────────────────────────────
  static const _homesKey = 'homes';

  List<SmarthomeHome>? getHomes() {
    final raw = _box?.get(_homesKey);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => _homeFromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveHomes(List<SmarthomeHome> homes) async {
    if (!isReady) return;
    await _box!.put(_homesKey, jsonEncode(homes.map(_homeToJson).toList()));
  }

  // ─── Rooms (per home) ───────────────────────────────────────────────────────
  String _roomsKey(String homeId) => 'rooms:$homeId';

  List<SmarthomeRoom>? getRooms(String homeId) {
    final raw = _box?.get(_roomsKey(homeId));
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => _roomFromJson(e as Map<String, dynamic>, homeId))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRooms(String homeId, List<SmarthomeRoom> rooms) async {
    if (!isReady) return;
    await _box!
        .put(_roomsKey(homeId), jsonEncode(rooms.map(_roomToJson).toList()));
  }

  // ─── Devices (per parent — room or home asset) ─────────────────────────────
  String _devicesKey(String parentId) => 'devices:$parentId';

  List<SmarthomeDevice>? getDevices(String parentId) {
    final raw = _box?.get(_devicesKey(parentId));
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => _deviceFromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDevices(
      String parentId, List<SmarthomeDevice> devices) async {
    if (!isReady) return;
    await _box!.put(
      _devicesKey(parentId),
      jsonEncode(devices.map(_deviceToJson).toList()),
    );
  }

  /// Xoá toàn bộ cache (gọi khi logout / chuyển user).
  Future<void> clear() async {
    await _box?.clear();
  }

  // ─── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> _homeToJson(SmarthomeHome h) => {
        'id': h.id,
        'name': h.name,
        if (h.accentColor != null) 'accentColor': h.accentColor,
      };

  SmarthomeHome _homeFromJson(Map<String, dynamic> j) => SmarthomeHome(
        id: j['id'] as String,
        name: j['name'] as String,
        accentColor: j['accentColor'] as String?,
      );

  Map<String, dynamic> _roomToJson(SmarthomeRoom r) => {
        'id': r.id,
        'name': r.name,
        if (r.icon != null) 'icon': r.icon,
        'order': r.order,
      };

  SmarthomeRoom _roomFromJson(Map<String, dynamic> j, String homeId) =>
      SmarthomeRoom(
        id: j['id'] as String,
        homeId: homeId,
        name: j['name'] as String,
        icon: j['icon'] as String?,
        order: (j['order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> _deviceToJson(SmarthomeDevice d) => {
        'id': d.id,
        'name': d.name,
        'type': d.type,
        if (d.label != null) 'label': d.label,
        if (d.deviceProfileId != null) 'deviceProfileId': d.deviceProfileId,
        if (d.profileName != null) 'profileName': d.profileName,
        if (d.gatewayName != null) 'gatewayName': d.gatewayName,
        if (d.profileImage != null) 'profileImage': d.profileImage,
        if (d.isOnline) 'isOnline': true,
        if (d.telemetry.isNotEmpty) 'telemetry': d.telemetry,
      };

  SmarthomeDevice _deviceFromJson(Map<String, dynamic> j) => SmarthomeDevice(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String? ?? '',
        label: j['label'] as String?,
        deviceProfileId: j['deviceProfileId'] as String?,
        profileName: j['profileName'] as String?,
        gatewayName: j['gatewayName'] as String?,
        profileImage: j['profileImage'] as String?,
        isOnline: j['isOnline'] as bool? ?? false,
        telemetry: (j['telemetry'] as Map<String, dynamic>?) ?? const {},
      );
}
