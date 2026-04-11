/// Khả năng automation của thiết bị: conditions và actions có thể dùng.
/// Dùng để populate automation builder UI thay vì hard-code theo uiType.
class AutomationCaps {
  const AutomationCaps({
    this.conditions = const [],
    this.actions = const [],
  });

  factory AutomationCaps.fromJson(Map<String, dynamic> json) {
    return AutomationCaps(
      conditions: (json['conditions'] as List<dynamic>?)
              ?.map((e) => ConditionCap.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      actions: (json['actions'] as List<dynamic>?)
              ?.map((e) => ActionCap.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Các condition có thể dùng trong automation rule.
  final List<ConditionCap> conditions;

  /// Các action có thể dùng trong automation rule.
  final List<ActionCap> actions;

  Map<String, dynamic> toJson() => {
        'conditions': conditions.map((c) => c.toJson()).toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
      };
}

/// Một condition khả thi: key telemetry + danh sách operator hỗ trợ.
class ConditionCap {
  const ConditionCap({required this.key, this.ops = const []});

  factory ConditionCap.fromJson(Map<String, dynamic> json) {
    return ConditionCap(
      key: json['key'] as String,
      ops: (json['ops'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  final String key;

  /// Operators hợp lệ: '>', '<', '>=', '<=', '==', '!=', '<>'
  final List<String> ops;

  Map<String, dynamic> toJson() => {'key': key, 'ops': ops};
}

/// Một action khả thi trong automation rule.
class ActionCap {
  const ActionCap({required this.method, this.param});

  factory ActionCap.fromJson(Map<String, dynamic> json) {
    return ActionCap(
      method: json['method'] as String,
      param: json['param'] as String?,
    );
  }

  final String method;

  /// Tên param chính (nếu có). Ví dụ: setValue → 'onoff0'.
  final String? param;

  Map<String, dynamic> toJson() => {
        'method': method,
        if (param != null) 'param': param,
      };
}
