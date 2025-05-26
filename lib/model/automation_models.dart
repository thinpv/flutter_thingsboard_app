import 'package:thingsboard_client/thingsboard_client.dart';

class Automation extends AssetInfo {
  SmartScene? smartScene;

  Automation.fromJson(super.json) : super.fromJson() {}

  Automation.fromAssetInfo(AssetInfo info) : super.fromJson(info.toJson()) {
    smartScene?.active = (additionalInfo?['active'] as bool?)!;
    smartScene?.ifConditions = (additionalInfo?['ifConditions'] as List?)
        ?.map((e) => SceneCondition(
              entityId: e['entityId'],
              key: e['key'],
              condition: e['condition'],
              value: e['value'],
            ))
        .toList();
    smartScene?.thenActions = (additionalInfo?['thenActions'] as List?)
        ?.map((e) => SceneAction(
              type: e['type'],
              entityId: e['entityId'],
              method: e['method'],
              params: e['params'] != null
                  ? Map<String, dynamic>.from(e['params'])
                  : null,
              automationId: e['automationId'],
              action: e['action'],
            ))
        .toList();
    smartScene?.precondition = additionalInfo?['precondition'] != null
        ? ScenePrecondition(
            from: additionalInfo!['precondition']['from'],
            to: additionalInfo!['precondition']['to'],
          )
        : null;
    smartScene?.areaIds =
        (additionalInfo?['areaIds'] as List?)?.map((e) => e as String).toList();
  }

  void update(
      {String? name,
      bool? active,
      List<SceneCondition>? ifConditions,
      List<SceneAction>? thenActions,
      ScenePrecondition? precondition,
      List<String>? areaIds,}) {
    this.name = name!;
    smartScene ??= SmartScene(
      active: active,
      ifConditions: ifConditions ?? [],
      thenActions: thenActions ?? [],
      precondition: precondition,
      areaIds: areaIds,
    );
  }

  @override
  String toString() {
    return 'Automation{${assetString('assetProfileName: $assetProfileName, customerTitle: $customerTitle, customerIsPublic: $customerIsPublic')}}';
  }
}

class SmartScene {
  bool? active;
  List<SceneCondition>? ifConditions;
  List<SceneAction>? thenActions;
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
        'if': ifConditions?.map((e) => e.toJson()).toList(),
        'then': thenActions?.map((e) => e.toJson()).toList(),
        if (precondition != null) 'precondition': precondition!.toJson(),
        if (areaIds != null) 'areaIds': areaIds,
      };
}

class SceneCondition {
  final String entityId;
  final String key;
  final String condition;
  final dynamic value;

  SceneCondition({
    required this.entityId,
    required this.key,
    required this.condition,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
        'entityId': entityId,
        'key': key,
        'condition': condition,
        'value': value,
      };
}

class SceneAction {
  final String type; // 'rpc' or 'automation'
  final String entityId;
  final String? method;
  final Map<String, dynamic>? params;
  final String? automationId;
  final String? action;

  SceneAction({
    required this.type,
    required this.entityId,
    this.method,
    this.params,
    this.automationId,
    this.action,
  });

  Map<String, dynamic> toJson() {
    if (type == 'rpc') {
      return {
        'type': type,
        'entityId': entityId,
        'method': method,
        'params': params,
      };
    } else {
      return {
        'type': type,
        'automationId': automationId,
        'action': action,
      };
    }
  }
}

class ScenePrecondition {
  final String from;
  final String to;

  ScenePrecondition({required this.from, required this.to});

  Map<String, dynamic> toJson() => {
        'type': 'time',
        'from': from,
        'to': to,
      };
}
