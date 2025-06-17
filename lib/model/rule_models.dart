import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_client/thingsboard_client.dart';
import 'package:uuid/uuid.dart';

RuleCondition parseRuleCondition(Map<String, dynamic> json) {
  if (json['type'] == 'device') {
    return RuleConditionDevice.fromJson(json);
  }
  throw Exception('Unknown RuleCondition type: ${json['type']}');
}

RuleAction parseRuleAction(Map<String, dynamic> json) {
  if (json['type'] == 'device') {
    return RuleActionDevice.fromJson(json);
  } else if (json['type'] == 'room') {
    return RuleActionRoom.fromJson(json);
  } else if (json['type'] == 'delay') {
    return RuleActionDelay.fromJson(json);
  }
  throw Exception('Unknown RuleAction type: ${json['type']}');
}

class Rule extends Asset {
  bool active = true;
  String conditionType = 'or';
  List<RuleCondition> ifConditions = [];
  List<RuleAction> thenActions = [];
  ScenePrecondition? precondition;
  List<String>? areaIds;
  String? gatewayId;

  Rule() : super(const Uuid().v4(), 'Rule');

  Rule.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    final info = json['additionalInfo'] as Map<String, dynamic>? ?? {};
    active = info['active'] as bool? ?? true;
    conditionType = info['type'] as String? ?? 'or';
    ifConditions = (info['if'] as List<dynamic>? ?? [])
        .map((e) => parseRuleCondition(e))
        .toList();
    thenActions = (info['then'] as List<dynamic>? ?? [])
        .map((e) => parseRuleAction(e))
        .toList();
    precondition = info['precondition'] != null
        ? ScenePrecondition.fromJson(info['precondition'])
        : null;
    areaIds =
        (info['areaIds'] as List<dynamic>?)?.map((e) => e as String).toList();
    gatewayId = info['gatewayId'] as String?;
  }

  @override
  Map<String, dynamic> toJson() {
    gatewayId = calculateDeviceSave();
    additionalInfo ??= {};
    additionalInfo!['active'] = active;
    additionalInfo!['type'] = conditionType;
    additionalInfo!['if'] = ifConditions.map((e) => e.toJson()).toList();
    additionalInfo!['then'] = thenActions.map((e) => e.toJson()).toList();
    if (precondition != null) {
      additionalInfo!['precondition'] = precondition!.toJson();
    }
    if (areaIds != null) additionalInfo!['areaIds'] = areaIds;
    if (gatewayId != null) {
      additionalInfo!['gatewayId'] = gatewayId;
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

  String? calculateDeviceSave() {
    String? gatewayId = null;
    for (var ifCondition in ifConditions) {
      if (ifCondition is! RuleConditionDevice) continue;
      if (ifCondition.deviceId.isEmpty) return null;
      final myDevice =
          DeviceManager.instance.getMyDeviceInfoById(ifCondition.deviceId);
      String? deviceId = myDevice?.gatewayId ?? myDevice?.id?.id;
      if (deviceId == null) return null;
      if (gatewayId == null) {
        gatewayId = deviceId; // gán id đầu tiên tìm thấy
      } else if (gatewayId != deviceId) {
        return null; // nếu có nhiều id khác nhau thì trả về null
      }
    }
    for (var thenAction in thenActions) {
      if (thenAction is! RuleActionDevice) continue;
      if (thenAction.deviceId.isEmpty) return null;
      final myDevice =
          DeviceManager.instance.getMyDeviceInfoById(thenAction.deviceId);
      String? deviceId = myDevice?.gatewayId ?? myDevice?.id?.id;
      if (deviceId == null) return null;
      if (gatewayId == null) {
        gatewayId = deviceId; // gán id đầu tiên tìm thấy
      } else if (gatewayId != deviceId) {
        return null; // nếu có nhiều id khác nhau thì trả về null
      }
    }
    return gatewayId;
  }

  Map<String, dynamic> buildRule() {
    return {
      'name': name,
      'active': active,
      'type': conditionType,
      'if': ifConditions.map((e) => e.buildRule()).toList(),
      'then': thenActions.map((e) => e.buildRule()).toList(),
      'precondition': precondition?.toJson(),
      'areaIds': areaIds,
      // if (gatewayId != null) 'gatewayId': gatewayId,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class RuleAdd extends Rule {
  RuleAdd() : super();
}

class RuleCondition {
  String type;
  String? description;

  RuleCondition(this.type, {this.description});

  RuleCondition.fromJson(Map<String, dynamic> json)
      : type = json['type'],
        description = json['description'];

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
    };
  }

  Map<String, dynamic> buildRule() {
    return {
      'type': type,
      'description': description,
    };
  }
}

class RuleConditionDevice extends RuleCondition {
  String deviceId;
  Map<String, dynamic> condition;

  RuleConditionDevice(
    String description,
    this.deviceId,
    this.condition,
  ) : super('device', description: description);

  @override
  RuleConditionDevice.fromJson(Map<String, dynamic> json)
      : deviceId = json['deviceId'],
        condition = json['condition'],
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'deviceId': deviceId,
      'condition': condition,
    };
  }

  @override
  Map<String, dynamic> buildRule() {
    return {
      'type': type,
      'id': DeviceManager.instance.getMyDeviceInfoById(deviceId)!.name,
      'condition': condition,
    };
  }
}

class RuleAction {
  String type;
  String? description;

  RuleAction(this.type, {this.description});

  RuleAction.fromJson(Map<String, dynamic> json)
      : type = json['type'],
        description = json['description'];

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
    };
  }

  Map<String, dynamic> buildRule() {
    return {
      'type': type,
      'description': description,
    };
  }
}

class RuleActionDevice extends RuleAction {
  String deviceId;
  Map<String, dynamic> action;

  RuleActionDevice(
    String description,
    this.deviceId,
    this.action,
  ) : super('device', description: description);

  @override
  RuleActionDevice.fromJson(Map<String, dynamic> json)
      : deviceId = json['deviceId'],
        action = json['action'],
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'deviceId': deviceId,
      'action': action,
    };
  }

  @override
  Map<String, dynamic> buildRule() {
    return {
      'type': type,
      'id': DeviceManager.instance.getMyDeviceInfoById(deviceId)!.name,
      'action': action,
    };
  }
}

class RuleActionRoom extends RuleAction {
  String roomId;
  Map<String, dynamic> action;

  RuleActionRoom(
    String description,
    this.roomId,
    this.action,
  ) : super('room', description: description);

  @override
  RuleActionRoom.fromJson(Map<String, dynamic> json)
      : roomId = json['roomId'],
        action = json['action'],
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'roomId': roomId,
      'action': action,
    };
  }

  @override
  Map<String, dynamic> buildRule() {
    return {
      'type': 'group',
      'id': roomId,
      'action': action,
    };
  }
}

class RuleActionDelay extends RuleAction {
  int delay;

  RuleActionDelay(String description, this.delay)
      : super('delay', description: description);

  @override
  RuleActionDelay.fromJson(Map<String, dynamic> json)
      : delay = json['delay'] ?? 0,
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'delay': delay,
    };
  }

  @override
  Map<String, dynamic> buildRule() {
    return {
      'type': type,
      'delay': delay,
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

class RuleInfo extends Rule {
  String? customerTitle;
  bool? customerIsPublic;
  String ruleProfileName = 'Rule';

  RuleInfo.fromJson(Map<String, dynamic> json)
      : customerTitle = json['customerTitle'],
        customerIsPublic = json['customerIsPublic'],
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    if (customerTitle != null) json['customerTitle'] = customerTitle;
    if (customerIsPublic != null) json['customerIsPublic'] = customerIsPublic;
    json['assetProfileName'] = ruleProfileName;
    return json;
  }

  @override
  String toString() {
    return 'RuleInfo{${assetString('ruleProfileName: $ruleProfileName, customerTitle: $customerTitle, customerIsPublic: $customerIsPublic')}}';
  }
}

class RuleSearchQuery extends EntitySearchQuery {
  List<String> ruleTypes;

  RuleSearchQuery(
      {required RelationsSearchParameters parameters,
      required this.ruleTypes,
      String? relationType})
      : super(parameters: parameters, relationType: relationType);

  @override
  Map<String, dynamic> toJson() {
    var json = super.toJson();
    json['ruleTypes'] = ruleTypes;
    return json;
  }

  @override
  String toString() {
    return 'RuleSearchQuery{${entitySearchQueryString('ruleTypes: $ruleTypes')}}';
  }
}
