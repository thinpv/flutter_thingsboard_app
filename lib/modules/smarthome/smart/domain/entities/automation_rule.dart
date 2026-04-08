/// Unified automation rule — same schema for both server-side and gateway-local rules.
/// See CLAUDE.md "Unified Automation Rule Format" for full spec.
class AutomationRule {
  const AutomationRule({
    required this.id,
    required this.name,
    required this.executionTarget,
    this.icon = 'auto_awesome',
    this.color = '#2196F3',
    this.enabled = true,
    this.ts,
    this.schedule,
    this.conditionMatch = ConditionMatch.all,
    this.conditions = const [],
    this.actions = const [],
  });

  factory AutomationRule.fromJson(Map<String, dynamic> json) {
    return AutomationRule(
      id: json['id'] as String,
      name: json['name'] as String,
      executionTarget: json['execution_target'] as String,
      icon: json['icon'] as String? ?? 'auto_awesome',
      color: json['color'] as String? ?? '#2196F3',
      enabled: json['enabled'] as bool? ?? true,
      ts: json['ts'] as int?,
      schedule: json['schedule'] != null
          ? RuleSchedule.fromJson(json['schedule'] as Map<String, dynamic>)
          : null,
      conditionMatch: json['condition_match'] == 'any'
          ? ConditionMatch.any
          : ConditionMatch.all,
      conditions: (json['conditions'] as List<dynamic>? ?? [])
          .map((c) => RuleCondition.fromJson(c as Map<String, dynamic>))
          .toList(),
      actions: (json['actions'] as List<dynamic>? ?? [])
          .map((a) => RuleAction.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String name;
  final String icon;
  final String color;
  final bool enabled;
  final int? ts;

  /// 'server' or 'gw:{gateway_device_id}'
  final String executionTarget;

  final RuleSchedule? schedule;
  final ConditionMatch conditionMatch;
  final List<RuleCondition> conditions;
  final List<RuleAction> actions;

  bool get isGatewayRule => executionTarget.startsWith('gw:');
  String? get gatewayId =>
      isGatewayRule ? executionTarget.substring(3) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'enabled': enabled,
        'ts': ts ?? DateTime.now().millisecondsSinceEpoch,
        'execution_target': executionTarget,
        if (schedule != null) 'schedule': schedule!.toJson(),
        'condition_match': conditionMatch == ConditionMatch.any ? 'any' : 'all',
        'conditions': conditions.map((c) => c.toJson()).toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
      };

  AutomationRule copyWith({bool? enabled}) {
    return AutomationRule(
      id: id,
      name: name,
      icon: icon,
      color: color,
      enabled: enabled ?? this.enabled,
      ts: DateTime.now().millisecondsSinceEpoch,
      executionTarget: executionTarget,
      schedule: schedule,
      conditionMatch: conditionMatch,
      conditions: conditions,
      actions: actions,
    );
  }
}

enum ConditionMatch { all, any }

// ─── Schedule ────────────────────────────────────────────────────────────────

class RuleSchedule {
  const RuleSchedule({
    this.days = 127,
    this.timeFrom,
    this.timeTo,
  });

  factory RuleSchedule.fromJson(Map<String, dynamic> json) {
    return RuleSchedule(
      days: json['days'] as int? ?? 127,
      timeFrom: json['time_from'] as String?,
      timeTo: json['time_to'] as String?,
    );
  }

  /// Bitmask: bit0=CN, 1=T2 … 6=T7. 127 = every day.
  final int days;
  final String? timeFrom;
  final String? timeTo;

  Map<String, dynamic> toJson() => {
        'days': days,
        if (timeFrom != null) 'time_from': timeFrom,
        if (timeTo != null) 'time_to': timeTo,
      };
}

// ─── Condition ───────────────────────────────────────────────────────────────

class RuleCondition {
  const RuleCondition({required this.raw});

  factory RuleCondition.fromJson(Map<String, dynamic> json) {
    return RuleCondition(raw: json);
  }

  final Map<String, dynamic> raw;

  String get type => raw['type'] as String? ?? '';

  Map<String, dynamic> toJson() => raw;
}

// ─── Action ──────────────────────────────────────────────────────────────────

class RuleAction {
  const RuleAction({required this.raw});

  factory RuleAction.fromJson(Map<String, dynamic> json) {
    return RuleAction(raw: json);
  }

  final Map<String, dynamic> raw;

  String get type => raw['type'] as String? ?? '';

  Map<String, dynamic> toJson() => raw;
}

// ─── Index entry (stored in Gateway rule_index) ───────────────────────────────

class RuleIndexEntry {
  const RuleIndexEntry({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.ts,
    this.status = 'active',
  });

  factory RuleIndexEntry.fromJson(Map<String, dynamic> json) {
    return RuleIndexEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? 'auto_awesome',
      color: json['color'] as String? ?? '#2196F3',
      enabled: json['enabled'] as bool? ?? true,
      ts: json['ts'] as int,
      status: json['status'] as String? ?? 'active',
    );
  }

  factory RuleIndexEntry.fromRule(AutomationRule rule) {
    return RuleIndexEntry(
      id: rule.id,
      name: rule.name,
      icon: rule.icon,
      color: rule.color,
      enabled: rule.enabled,
      ts: rule.ts ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  final String id;
  final String name;
  final String icon;
  final String color;
  final bool enabled;
  final int ts;
  final String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'enabled': enabled,
        'ts': ts,
        'status': status,
      };
}
