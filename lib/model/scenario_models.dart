import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_client/thingsboard_client.dart';
import 'package:uuid/uuid.dart';

class Scenario extends Asset {
  bool active = true;
  List<SceneCondition> ifConditions = [];
  List<SceneAction> thenActions = [];
  ScenePrecondition? precondition;
  List<String>? areaIds;
  String? deviceCheck;

  Scenario() : super(const Uuid().v4(), 'Scenario');

  Scenario.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    final info = json['additionalInfo'] as Map<String, dynamic>? ?? {};
    active = info['active'] as bool? ?? true;
    ifConditions = (info['if'] as List<dynamic>? ?? [])
        .map((e) => SceneCondition.fromJson(e))
        .toList();
    thenActions = (info['then'] as List<dynamic>? ?? [])
        .map((e) => SceneAction.fromJson(e))
        .toList();
    precondition = info['precondition'] != null
        ? ScenePrecondition.fromJson(info['precondition'])
        : null;
    areaIds =
        (info['areaIds'] as List<dynamic>?)?.map((e) => e as String).toList();
    deviceCheck = info['deviceCheck'] as String?;
  }

  @override
  Map<String, dynamic> toJson() {
    additionalInfo ??= {};
    additionalInfo!['name'] = name;
    additionalInfo!['active'] = active;
    additionalInfo!['if'] = ifConditions.map((e) => e.toJson()).toList();
    additionalInfo!['then'] = thenActions.map((e) => e.toJson()).toList();
    if (precondition != null) {
      additionalInfo!['precondition'] = precondition!.toJson();
    }
    if (areaIds != null) additionalInfo!['areaIds'] = areaIds;
    if (deviceCheck != null) {
      additionalInfo!['deviceCheck'] = deviceCheck;
      final deviceInfo =
          DeviceManager.instance.getMyDeviceInfoById(deviceCheck!);
      additionalInfo!['deviceCheckName'] = deviceInfo?.name;
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

  void calculateDeviceSave() {
    deviceCheck = null;
    for (var ifCondition in ifConditions) {
      final myDevice =
          DeviceManager.instance.getMyDeviceInfoById(ifCondition.device);
      String? deviceId = myDevice?.gatewayId ?? myDevice?.id?.id;
      if (deviceId == null) {
        deviceCheck = null;
        return;
      }
      if (deviceCheck == null) {
        deviceCheck = deviceId;
      } else if (deviceCheck != deviceId) {
        deviceCheck = null;
        return;
      }
    }
    for (var thenAction in thenActions) {
      final myDevice =
          DeviceManager.instance.getMyDeviceInfoById(thenAction.device);
      String? deviceId = myDevice?.gatewayId ?? myDevice?.id?.id;
      if (deviceId == null) {
        deviceCheck = null;
        return;
      }
      if (deviceCheck == null) {
        deviceCheck = deviceId;
      } else if (deviceCheck != deviceId) {
        deviceCheck = null;
        return;
      }
    }
  }
}

class ScenarioAdd extends Scenario {
  ScenarioAdd() : super();
}

class SceneCondition {
  String device;
  String name;
  Map<String, dynamic> condition;

  SceneCondition(
    this.device,
    this.name,
    this.condition,
  );

  SceneCondition.fromJson(Map<String, dynamic> json)
      : device = json['device'],
        name = json['name'],
        condition = json['condition'];

  Map<String, dynamic> toJson() {
    return {
      'device': device,
      'deviceName': DeviceManager.instance.getMyDeviceInfoById(device)?.name,
      'name': name,
      'condition': condition,
    };
  }
}

class SceneAction {
  String device;
  String name;
  Map<String, dynamic> action;

  SceneAction(
    this.device,
    this.name,
    this.action,
  );

  SceneAction.fromJson(Map<String, dynamic> json)
      : device = json['device'],
        name = json['name'],
        action = json['action'];

  Map<String, dynamic> toJson() {
    return {
      'device': device,
      'deviceName': DeviceManager.instance.getMyDeviceInfoById(device)?.name,
      'name': name,
      'action': action,
    };
  }
}

class ScenePrecondition {
  String from;
  String to;

  ScenePrecondition(this.from, this.to);

  ScenePrecondition.fromJson(Map<String, dynamic> json)
      : from = json['from'],
        to = json['to'];

  Map<String, dynamic> toJson() => {
        'type': 'time',
        'from': from,
        'to': to,
      };
}

class ScenarioInfo extends Scenario {
  String? customerTitle;
  bool? customerIsPublic;
  String scenarioProfileName = 'Scenario';

  ScenarioInfo.fromJson(Map<String, dynamic> json)
      : customerTitle = json['customerTitle'],
        customerIsPublic = json['customerIsPublic'],
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    if (customerTitle != null) json['customerTitle'] = customerTitle;
    if (customerIsPublic != null) json['customerIsPublic'] = customerIsPublic;
    json['assetProfileName'] = scenarioProfileName;
    return json;
  }

  @override
  String toString() {
    return 'ScenarioInfo{${assetString('scenarioProfileName: $scenarioProfileName, customerTitle: $customerTitle, customerIsPublic: $customerIsPublic')}}';
  }
}

class ScenarioSearchQuery extends EntitySearchQuery {
  List<String> scenarioTypes;

  ScenarioSearchQuery(
      {required RelationsSearchParameters parameters,
      required this.scenarioTypes,
      String? relationType})
      : super(parameters: parameters, relationType: relationType);

  @override
  Map<String, dynamic> toJson() {
    var json = super.toJson();
    json['scenarioTypes'] = scenarioTypes;
    return json;
  }

  @override
  String toString() {
    return 'ScenarioSearchQuery{${entitySearchQueryString('scenarioTypes: $scenarioTypes')}}';
  }
}
