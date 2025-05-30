import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class Scenario extends Asset {
  SmartScene smartScene;

  Scenario(String name)
      : smartScene = SmartScene(),
        super(name, 'Scenario');

  Scenario.fromJson(Map<String, dynamic> json)
      : smartScene = SmartScene.fromJson(json),
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['additionalInfo'] = smartScene;
    return json;
  }
}

class ScenarioAdd extends Scenario {
  ScenarioAdd(String name) : super(name);
}

class SmartScene {
  bool active = true;
  List<SceneCondition> ifConditions = [];
  List<SceneAction> thenActions = [];
  ScenePrecondition? precondition;
  List<String>? areaIds;

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
  }

  Map<String, dynamic> toJson() {
    return {
      'active': active,
      'if': ifConditions.map((e) => e.toJson()).toList(),
      'then': thenActions.map((e) => e.toJson()).toList(),
      if (precondition != null) 'precondition': precondition!.toJson(),
      if (areaIds != null) 'areaIds': areaIds,
    };
  }
}

class SceneCondition {
  DeviceInfo device;
  String condition;

  SceneCondition(
    this.device,
    this.condition,
  );

  SceneCondition.fromJson(Map<String, dynamic> json)
      : condition = json['condition'],
        device = DeviceManager.instance.getDeviceById(json['device']) ??
            (throw Exception('Device not found: ${json['device']}'));

  Map<String, dynamic> toJson() {
    return {
      'device': device.id?.id,
      'condition': condition,
    };
  }
}

class SceneAction {
  DeviceInfo device;
  String action;

  SceneAction(
    this.device,
    this.action,
  );

  SceneAction.fromJson(Map<String, dynamic> json)
      : action = json['action'],
        device = DeviceManager.instance.getDeviceById(json['device']) ??
            (throw Exception('Device not found: ${json['device']}'));

  Map<String, dynamic> toJson() {
    return {
      'device': device.id?.id,
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
