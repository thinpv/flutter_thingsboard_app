/// Mô tả 1 loại cảnh báo khả dụng cho thiết bị, khai báo trong
/// `profile.description.alertTemplates[]`.
///
/// Thiết kế: NOTIFICATION_SYSTEM.md §4.1.1.
class AlertTemplate {
  const AlertTemplate({
    required this.key,
    required this.op,
    required this.severity,
    this.defaultValue,
    this.defaultDuration,
    this.defaultEnabled = false,
    this.labelKey,
    this.icon,
    this.defaultMessage,
  });

  /// Telemetry short-key (`temp`, `door`, `pir`...).
  final String key;

  /// Operator: `>`, `<`, `>=`, `<=`, `==`, `!=`, `<>`.
  final String op;

  /// `info` / `warning` / `critical` (user-facing). Rule Chain map sang
  /// TB alarm severity.
  final String severity;

  /// Threshold mặc định khi user mới bật. Với `<>` dùng `[min, max]`.
  final dynamic defaultValue;

  /// Reserved cho future "offline" template (chưa dùng — offline detection
  /// hiện tại dùng TB native Inactivity alarm ở profileData.alarms).
  final num? defaultDuration;

  /// Trạng thái bật/tắt mặc định cho device mới.
  final bool defaultEnabled;

  /// i18n key cho tên cảnh báo (UI hiển thị). Ví dụ `alert.door_open`.
  final String? labelKey;

  /// Icon name (Material).
  final String? icon;

  /// Message mặc định khi user mới bật.
  final String? defaultMessage;

  factory AlertTemplate.fromJson(Map<String, dynamic> json) {
    return AlertTemplate(
      key: json['key'] as String,
      op: json['op'] as String? ?? '==',
      severity: json['severity'] as String? ?? 'warning',
      defaultValue: json['defaultValue'],
      defaultDuration: json['defaultDuration'] as num?,
      defaultEnabled: json['defaultEnabled'] as bool? ?? false,
      labelKey: json['labelKey'] as String?,
      icon: json['icon'] as String?,
      defaultMessage: json['defaultMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'op': op,
        'severity': severity,
        if (defaultValue != null) 'defaultValue': defaultValue,
        if (defaultDuration != null) 'defaultDuration': defaultDuration,
        if (defaultEnabled) 'defaultEnabled': defaultEnabled,
        if (labelKey != null) 'labelKey': labelKey,
        if (icon != null) 'icon': icon,
        if (defaultMessage != null) 'defaultMessage': defaultMessage,
      };
}
