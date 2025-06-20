import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_client/thingsboard_client.dart';
import 'package:uuid/uuid.dart';

class Scene extends Asset {
  List<DeviceInScene> _deviceInScenes = [];
  List<String> _gatewayIds = [];

  Scene({String? name}) : super(const Uuid().v4(), 'Scene') {
    label = name;
  }

  Scene.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    final info = json['additionalInfo'] as Map<String, dynamic>? ?? {};
    _deviceInScenes = (info['devices'] as List<dynamic>?)
            ?.map(
              (e) =>
                  e is Map<String, dynamic> ? DeviceInScene.fromJson(e) : null,
            )
            .whereType<DeviceInScene>()
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
    additionalInfo!['devices'] = _deviceInScenes;
    additionalInfo!['gatewayIds'] = _gatewayIds;
    return super.toJson();
  }

  List<DeviceInScene> get deviceInScenes => _deviceInScenes;
  List<String> get gatewayIds => _gatewayIds;

  DeviceInScene? findDevice(String deviceId, int? epId) {
    for (final deviceInScene in _deviceInScenes) {
      if (deviceInScene.deviceId == deviceId && deviceInScene.epId == epId) {
        return deviceInScene;
      }
    }
    return null;
  }

  void addDevice(String deviceId, int epId) {
    if (findDevice(deviceId, epId) == null) {
      _deviceInScenes.add(DeviceInScene(deviceId, epId: epId));
      updateGatewayList();
    }
  }

  void addDeviceInScene(DeviceInScene deviceInScene) {
    if (findDevice(deviceInScene.deviceId, deviceInScene.epId ?? 0) == null) {
      _deviceInScenes.add(deviceInScene);
      updateGatewayList();
    }
  }

  void removeDevice(String deviceId, int epId) {
    DeviceInScene? deviceInScene = findDevice(deviceId, epId);
    if (deviceInScene != null) {
      _deviceInScenes.remove(deviceInScene);
      updateGatewayList();
    }
  }

  void removeDeviceInScene(DeviceInScene deviceInScene) {
    if (findDevice(deviceInScene.deviceId, deviceInScene.epId) != null) {
      _deviceInScenes.remove(deviceInScene);
      updateGatewayList();
    }
  }

  void updateGatewayList() {
    _gatewayIds.clear();
    for (final deviceInScene in _deviceInScenes) {
      final device =
          DeviceManager.instance.getMyDeviceInfoById(deviceInScene.deviceId);
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

class SceneAdd extends Scene {
  SceneAdd() : super();
}

class SceneInfo extends Scene {
  String? customerTitle;
  bool? customerIsPublic;
  String roomProfileName = 'Scene';

  SceneInfo.fromJson(Map<String, dynamic> json)
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
    return 'SceneInfo{${assetString('roomProfileName: $roomProfileName, customerTitle: $customerTitle, customerIsPublic: $customerIsPublic')}}';
  }
}

class DeviceInScene {
  String deviceId;
  int? epId;
  String? epName;

  DeviceInScene(this.deviceId, {this.epId, this.epName});

  factory DeviceInScene.fromJson(Map<String, dynamic> json) {
    return DeviceInScene(
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

  Map<String, dynamic> buildScene() {
    return {
      'id': DeviceManager.instance.getMyDeviceInfoById(deviceId)!.name,
      if (epId != null) 'epId': epId,
      if (epName != null) 'epName': epName,
    };
  }

  @override
  toString() {
    return toJson().toString();
  }
}

class SceneSearchQuery extends EntitySearchQuery {
  List<String> roomTypes;

  SceneSearchQuery({
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
    return 'SceneSearchQuery{${entitySearchQueryString('roomTypes: $roomTypes')}}';
  }
}
