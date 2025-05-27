import 'package:thingsboard_app/provider/DeviceManager.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class Scenario extends AssetInfo {
  late SmartScene smartScene;

  Scenario.fromJson(super.json) : super.fromJson();

  static Future<Scenario> fromAssetInfo(AssetInfo assetInfo) async {
    final scenario = Scenario.fromJson(assetInfo.toJson());
    scenario.smartScene = await SmartScene.fromAssetInfo(assetInfo);
    return scenario;
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
    additionalInfo ??= {};
    if (active != null) {
      smartScene.active = active;
      additionalInfo?['active'] = active;
    }
    if (ifConditions != null) {
      smartScene.ifConditions = ifConditions;
      additionalInfo?['if'] = ifConditions.map((e) => e.toJson()).toList();
    }
    if (thenActions != null) {
      smartScene.thenActions = thenActions;
      additionalInfo?['then'] = thenActions.map((e) => e.toJson()).toList();
    }
    if (precondition != null) {
      smartScene.precondition = precondition;
      additionalInfo?['precondition'] = precondition.toJson();
    }
    if (areaIds != null) {
      smartScene.areaIds = areaIds;
      additionalInfo?['areaIds'] = areaIds;
    }
  }

  @override
  String toString() {
    return 'Scenario{${assetString('assetProfileName: $assetProfileName, customerTitle: $customerTitle, customerIsPublic: $customerIsPublic')}}';
  }
}

class SmartScene {
  late bool active;
  late List<SceneCondition> ifConditions;
  late List<SceneAction> thenActions;
  ScenePrecondition? precondition;
  List<String>? areaIds;

  SmartScene({
    required this.active,
    required this.ifConditions,
    required this.thenActions,
    this.precondition,
    this.areaIds,
  });
  static Future<SmartScene> fromAssetInfo(AssetInfo assetInfo) async {
    final active = assetInfo.additionalInfo != null
        ? (assetInfo.additionalInfo?['active'] as bool? ?? false)
        : false;
    final ifConditionsRaw = assetInfo.additionalInfo?['if'] as List?;
    final List<SceneCondition> ifConditions = [];
    if (ifConditionsRaw != null) {
      for (final e in ifConditionsRaw) {
        if (e['device'] is String) {
          final device =
              await DeviceManager.instance.getDeviceById(e['device']);
          if (device != null) {
            ifConditions.add(SceneCondition(
              device,
              e['condition'] as String,
            ));
          }
        }
      }
    }
    final thenActionsRaw = assetInfo.additionalInfo?['then'] as List?;
    final List<SceneAction> thenActions = [];
    if (thenActionsRaw != null) {
      for (final e in thenActionsRaw) {
        if (e['device'] is String) {
          final device =
              await DeviceManager.instance.getDeviceById(e['device']);
          if (device != null) {
            thenActions.add(SceneAction(
              device,
              e['action'] as String,
            ));
          }
        }
      }
    }
    final precondition = assetInfo.additionalInfo?['precondition'] != null
        ? ScenePrecondition(
            assetInfo.additionalInfo!['precondition']['from'] as String,
            assetInfo.additionalInfo!['precondition']['to'] as String)
        : null;
    final areaIds = (assetInfo.additionalInfo?['areaIds'] as List?)
        ?.map((e) => e as String)
        .toList();

    return SmartScene(
      active: active,
      ifConditions: ifConditions,
      thenActions: thenActions,
      precondition: precondition,
      areaIds: areaIds,
    );
  }

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
  String condition;

  SceneCondition(
    this.device,
    this.condition,
  );

  SceneCondition.empty(this.device) : condition = '';

  Map<String, dynamic> toJson() => {
        'device': device.id?.id,
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
      'device': device.id?.id,
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
