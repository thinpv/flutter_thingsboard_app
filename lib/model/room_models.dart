import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_client/thingsboard_client.dart';
import 'package:uuid/uuid.dart';

class Room extends Asset {
  List<String> _deviceIds = [];
  List<String> _gatewayIds = [];

  Room() : super(const Uuid().v4(), 'Room');

  Room.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    final info = json['additionalInfo'] as Map<String, dynamic>? ?? {};
    _deviceIds = (info['deviceIds'] as List<dynamic>?)
            ?.map((e) => e as String)
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
    additionalInfo!['deviceIds'] = _deviceIds;
    additionalInfo!['gatewayIds'] = _gatewayIds;
    return super.toJson();
  }

  List<String> get deviceIds => _deviceIds;
  List<String> get gatewayIds => _gatewayIds;

  void addDevice(String deviceId) {
    if (!_deviceIds.contains(deviceId)) {
      _deviceIds.add(deviceId);
      updateGatewayList();
    }
  }

  void removeDevice(String deviceId) {
    if (_deviceIds.contains(deviceId)) {
      _deviceIds.remove(deviceId);
      updateGatewayList();
    }
  }

  void updateGatewayList() {
    _gatewayIds.clear();
    for (final deviceId in _deviceIds) {
      final device = DeviceManager.instance.getMyDeviceInfoById(deviceId);
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

  DeviceInRoom(this.deviceId, {this.epId});

  toJson() {
    return {
      'id': deviceId,
      if (epId != null) 'epId': epId,
    };
  }
}

class RoomSearchQuery extends EntitySearchQuery {
  List<String> roomTypes;

  RoomSearchQuery(
      {required RelationsSearchParameters parameters,
      required this.roomTypes,
      String? relationType})
      : super(parameters: parameters, relationType: relationType);

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
