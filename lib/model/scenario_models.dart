import 'package:thingsboard_client/thingsboard_client.dart';

class Scenario extends AssetInfo {
  late SmartScene smartScene;

  Scenario.fromJson(super.json) : super.fromJson() {
    smartScene = SmartScene(active: true, ifConditions: [], thenActions: []);
  }

  Scenario.fromAssetInfo(AssetInfo info) : super.fromJson(info.toJson()) {
    smartScene = SmartScene(active: true, ifConditions: [], thenActions: []);
    smartScene.active = additionalInfo != null
        ? (additionalInfo?['active'] as bool? ?? false)
        : false;
    smartScene.ifConditions = (additionalInfo?['ifConditions'] as List?)
            ?.map((e) => SceneCondition(
                  DeviceInfo.fromJson(e['device']),
                  e['op'] as String,
                  e['condition'] as String,
                ))
            .toList() ??
        [];
    smartScene.thenActions = (additionalInfo?['thenActions'] as List?)
            ?.map((e) => SceneAction(
                  DeviceInfo.fromJson(e['device']),
                  e['action'] as String,
                ))
            .toList() ??
        [];
    smartScene.precondition = additionalInfo?['precondition'] != null
        ? ScenePrecondition(additionalInfo!['precondition']['from'] as String,
            additionalInfo!['precondition']['to'] as String)
        : null;
    smartScene.areaIds =
        (additionalInfo?['areaIds'] as List?)?.map((e) => e as String).toList();
  }

  void update({
    String? name,
    bool? active,
    List<SceneCondition>? ifConditions,
    List<SceneAction>? thenActions,
    ScenePrecondition? precondition,
    List<String>? areaIds,
  }) {
    if (name != null) {
      this.name = name;
    }
    if (active != null) {
      smartScene.active = active;
    }
    if (ifConditions != null) {
      smartScene.ifConditions = ifConditions;
    }
    if (thenActions != null) {
      smartScene.thenActions = thenActions;
    }
    if (precondition != null) {
      smartScene.precondition = precondition;
    }
    if (areaIds != null) {
      smartScene.areaIds = areaIds;
    }
    additionalInfo = {
      'active': smartScene.active,
      'ifConditions': smartScene.ifConditions.map((e) => e.toJson()).toList(),
      'thenActions': smartScene.thenActions.map((e) => e.toJson()).toList(),
      if (smartScene.precondition != null)
      'precondition': smartScene.precondition!.toJson(),
      if (smartScene.areaIds != null) 'areaIds': smartScene.areaIds,
    };
  }

  @override
  String toString() {
    return 'Scenario{${assetString('assetProfileName: $assetProfileName, customerTitle: $customerTitle, customerIsPublic: $customerIsPublic')}}';
  }
}

class SmartScene {
  bool active;
  List<SceneCondition> ifConditions;
  List<SceneAction> thenActions;
  ScenePrecondition? precondition;
  List<String>? areaIds;

  SmartScene({
    required this.active,
    required this.ifConditions,
    required this.thenActions,
    this.precondition,
    this.areaIds,
  });

  Map<String, dynamic> toJson() => {
        'active': active,
        'if': ifConditions.map((e) => e.toJson()).toList(),
        'then': thenActions.map((e) => e.toJson()).toList(),
        if (precondition != null) 'precondition': precondition!.toJson(),
        if (areaIds != null) 'areaIds': areaIds,
      };
}

class SceneCondition {
  DeviceInfo device;
  String op;
  String condition;

  SceneCondition(
    this.device,
    this.op,
    this.condition,
  );

  SceneCondition.empty(this.device)
      : op = '',
        condition = '';

  Map<String, dynamic> toJson() => {
        'device': device.name,
        'op': op,
        'condition': condition,
      };
}

class SceneAction {
  DeviceInfo device;
  String action;

  SceneAction(
    this.device,
    this.action,
  );

  SceneAction.empty(this.device) : action = '';

  Map<String, dynamic> toJson() {
    return {
      'name': device.toJson(),
      'action': action,
    };
  }
}

class ScenePrecondition {
  String from;
  String to;

  ScenePrecondition(this.from, this.to);

  Map<String, dynamic> toJson() => {
        'type': 'time',
        'from': from,
        'to': to,
      };
}
