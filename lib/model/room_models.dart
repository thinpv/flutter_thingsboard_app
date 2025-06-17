import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_client/thingsboard_client.dart';
import 'package:uuid/uuid.dart';

class Room extends Asset {
  List<DeviceInRoom> _deviceInRooms = [];
  List<String> _gatewayIds = [];

  Room() : super(const Uuid().v4(), 'Room');

  Room.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    final info = json['additionalInfo'] as Map<String, dynamic>? ?? {};
    _deviceInRooms = (info['devices'] as List<dynamic>?)
            ?.map(
              (e) =>
                  e is Map<String, dynamic> ? DeviceInRoom.fromJson(e) : null,
            )
            .whereType<DeviceInRoom>()
            .toList() ??
        [];
    _gatewayIds = (info['gatewayIds'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];
  }

  @override
  Map<String, dynamic> toJson() {
    additionalInfo ??= {};
    additionalInfo!['devices'] = _deviceInRooms;
    additionalInfo!['gatewayIds'] = _gatewayIds;
    return super.toJson();
  }

  List<DeviceInRoom> get deviceInRooms => _deviceInRooms;
  List<String> get gatewayIds => _gatewayIds;

  DeviceInRoom? findDevice(String deviceId, int epId) {
    for (final deviceInRoom in _deviceInRooms) {
      if (deviceInRoom.deviceId == deviceId && deviceInRoom.epId == epId) {
        return deviceInRoom;
      }
    }
    return null;
  }

  void addDevice(String deviceId, int epId) {
    if (findDevice(deviceId, epId) == null) {
      _deviceInRooms.add(DeviceInRoom(deviceId, epId: epId));
      updateGatewayList();
    }
  }

  void addDeviceInRoom(DeviceInRoom deviceInRoom) {
    if (findDevice(deviceInRoom.deviceId, deviceInRoom.epId ?? 0) == null) {
      _deviceInRooms.add(deviceInRoom);
      updateGatewayList();
    }
  }

  void removeDevice(String deviceId, int epId) {
    DeviceInRoom? deviceInRoom = findDevice(deviceId, epId);
    if (deviceInRoom != null) {
      _deviceInRooms.remove(deviceInRoom);
      updateGatewayList();
    }
  }

  void removeDeviceInRoom(DeviceInRoom deviceInRoom) {
    if (findDevice(deviceInRoom.deviceId, deviceInRoom.epId ?? 0) != null) {
      _deviceInRooms.remove(deviceInRoom);
      updateGatewayList();
    }
  }

  void updateGatewayList() {
    _gatewayIds.clear();
    for (final deviceInRoom in _deviceInRooms) {
      final device =
          DeviceManager.instance.getMyDeviceInfoById(deviceInRoom.deviceId);
      if (device != null) {
        String id = device.id!.id ?? '';
        if (device.gatewayId != null) id = device.gatewayId!;
        if (!_gatewayIds.contains(id)) {
          _gatewayIds.add(id);
        }
      }
    }
  }

  String getDisplayName() {
    if (label != null && label!.isNotEmpty) {
      return label!;
    } else {
      return name;
    }
  }
}

class RoomAdd extends Room {
  RoomAdd() : super();
}

class RoomInfo extends Room {
  String? customerTitle;
  bool? customerIsPublic;
  String roomProfileName = 'Room';

  RoomInfo.fromJson(Map<String, dynamic> json)
      : customerTitle = json['customerTitle'],
        customerIsPublic = json['customerIsPublic'],
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    if (customerTitle != null) json['customerTitle'] = customerTitle;
    if (customerIsPublic != null) json['customerIsPublic'] = customerIsPublic;
    json['assetProfileName'] = roomProfileName;
    return json;
  }

  @override
  String toString() {
    return 'RoomInfo{${assetString('roomProfileName: $roomProfileName, customerTitle: $customerTitle, customerIsPublic: $customerIsPublic')}}';
  }
}

class DeviceInRoom {
  String deviceId;
  int? epId;
  String? epName;

  DeviceInRoom(this.deviceId, {this.epId, this.epName});

  factory DeviceInRoom.fromJson(Map<String, dynamic> json) {
    return DeviceInRoom(
      json['id'] as String,
      epId: json['epId'] as int?,
      epName: json['epName'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': deviceId,
      if (epId != null) 'epId': epId,
      if (epName != null) 'epName': epName,
    };
  }

  Map<String, dynamic> buildRoom() {
    return {
      'id': DeviceManager.instance.getMyDeviceInfoById(deviceId)!.name,
      if (epId != null) 'epId': epId,
      if (epName != null) 'epName': epName,
    };
  }
}

class RoomSearchQuery extends EntitySearchQuery {
  List<String> roomTypes;

  RoomSearchQuery({
    required RelationsSearchParameters parameters,
    required this.roomTypes,
    String? relationType,
  }) : super(parameters: parameters, relationType: relationType);

  @override
  Map<String, dynamic> toJson() {
    var json = super.toJson();
    json['roomTypes'] = roomTypes;
    return json;
  }

  @override
  String toString() {
    return 'RoomSearchQuery{${entitySearchQueryString('roomTypes: $roomTypes')}}';
  }
}
