import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_client/thingsboard_client.dart';
import 'package:uuid/uuid.dart';

class Scenario extends Asset {
  String? displayName;
  SmartScene smartScene;

  Scenario(this.displayName)
      : smartScene = SmartScene(),
        super(const Uuid().v4(), 'Scenario');

  Scenario.fromJson(Map<String, dynamic> json)
      : displayName = json['additionalInfo'] != null &&
                json['additionalInfo']['name'] != null
            ? json['additionalInfo']['name']
            : null,
        smartScene = SmartScene.fromJson(json),
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['additionalInfo'] = smartScene.toJson();
    json['additionalInfo']['name'] = displayName;
    json['additionalInfo']['description'] = displayName;
    return json;
  }
}

class ScenarioAdd extends Scenario {
  ScenarioAdd(String displayName) : super(displayName);
}

class SmartScene {
  bool active = true;
  List<SceneCondition> ifConditions = [];
  List<SceneAction> thenActions = [];
  ScenePrecondition? precondition;
  List<String>? areaIds;
  String? deviceSave; // the device which will check the rule

  SmartScene();

  SmartScene.fromJson(Map<String, dynamic> json) {
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
    deviceSave = info['deviceSave'] as String?;
  }

  Map<String, dynamic> toJson() {
    return {
      'active': active,
      'if': ifConditions.map((e) => e.toJson()).toList(),
      'then': thenActions.map((e) => e.toJson()).toList(),
      if (precondition != null) 'precondition': precondition!.toJson(),
      if (areaIds != null) 'areaIds': areaIds,
      if (deviceSave != null) 'deviceSave': deviceSave,
      if (deviceSave != null) 'deviceSaveName': DeviceManager.instance.getMyDeviceInfoById(deviceSave!)?.name,
    };
  }

  void calculateDeviceSave() {
    String? deviceSaveId;
    for (var ifCondition in ifConditions) {
      final myDevice =
          DeviceManager.instance.getMyDeviceInfoById(ifCondition.device);
      String? deviceId = myDevice?.gatewayId ?? myDevice?.id?.id;
      if (deviceId == null) {
        deviceSave = null;
        return;
      }
      if (deviceSaveId == null) {
        deviceSaveId = deviceId;
      } else if (deviceId != deviceSaveId) {
        deviceSave = null;
        return;
      }
    }
    for (var thenAction in thenActions) {
      final myDevice =
          DeviceManager.instance.getMyDeviceInfoById(thenAction.device);
      String? deviceId = myDevice?.gatewayId ?? myDevice?.id?.id;
      if (deviceId == null) {
        deviceSave = null;
        return;
      }
      if (deviceSaveId == null) {
        deviceSaveId = deviceId;
      } else if (deviceId != deviceSaveId) {
        deviceSave = null;
        return;
      }
    }
    deviceSave = deviceSaveId;
  }
}

class SceneCondition {
  String device;
  String condition;

  SceneCondition(
    this.device,
    this.condition,
  );

  SceneCondition.fromJson(Map<String, dynamic> json)
      : device = json['device'],
        condition = json['condition'];

  Map<String, dynamic> toJson() {
    return {
      'device': device,
      'condition': condition,
    };
  }
}

class SceneAction {
  String device;
  String action;

  SceneAction(
    this.device,
    this.action,
  );

  SceneAction.fromJson(Map<String, dynamic> json)
      : device = json['device'],
        action = json['action'];

  Map<String, dynamic> toJson() {
    return {
      'device': device,
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
