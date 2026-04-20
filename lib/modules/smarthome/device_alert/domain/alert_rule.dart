/// Một alert rule cụ thể trên device (instance), lưu ở SERVER_SCOPE attr
/// `alertConfig.rules[]`. Tham chiếu đến template trong profile qua [key].
///
/// Spec: NOTIFICATION_SYSTEM.md §4.1.2.
class AlertRule {
  const AlertRule({
    required this.key,
    required this.op,
    required this.severity,
    required this.enabled,
    this.value,
    this.message,
  });

  /// Khớp với `AlertTemplate.key` của profile.
  final String key;

  /// Operator (lấy từ template, user không đổi).
  final String op;

  /// `info` / `warning` / `critical`.
  final String severity;

  /// Per-rule toggle. Rule Chain skip nếu false.
  final bool enabled;

  /// Threshold user customize. Với `<>` dùng `[min, max]`.
  final dynamic value;

  /// Message custom user gõ. Nếu null/rỗng → fallback `defaultMessage` của
  /// template ở Rule Chain.
  final String? message;

  factory AlertRule.fromJson(Map<String, dynamic> json) {
    return AlertRule(
      key: json['key'] as String,
      op: json['op'] as String? ?? '==',
      severity: json['severity'] as String? ?? 'warning',
      enabled: json['enabled'] as bool? ?? false,
      value: json['value'],
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'op': op,
        'severity': severity,
        'enabled': enabled,
        if (value != null) 'value': value,
        if (message != null && message!.isNotEmpty) 'message': message,
      };

  AlertRule copyWith({
    String? op,
    String? severity,
    bool? enabled,
    dynamic value,
    String? message,
  }) {
    return AlertRule(
      key: key,
      op: op ?? this.op,
      severity: severity ?? this.severity,
      enabled: enabled ?? this.enabled,
      value: value ?? this.value,
      message: message ?? this.message,
    );
  }
}
