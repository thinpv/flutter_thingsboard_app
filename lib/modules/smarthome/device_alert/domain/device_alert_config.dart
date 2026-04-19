import 'package:thingsboard_app/modules/smarthome/device_alert/domain/alert_rule.dart';

/// Cấu hình cảnh báo lưu ở SERVER_SCOPE attr `alert_config` của Device.
///
/// Spec: NOTIFICATION_SYSTEM.md §4.1.2.
class DeviceAlertConfig {
  const DeviceAlertConfig({this.rules = const []});

  static const empty = DeviceAlertConfig();

  /// Chỉ chứa rule user đã từng tương tác. Rule chưa bao giờ bật → không có
  /// entry; UI fallback default từ profile template.
  final List<AlertRule> rules;

  factory DeviceAlertConfig.fromJson(Map<String, dynamic> json) {
    final rules = (json['rules'] as List<dynamic>?)
            ?.map((e) => AlertRule.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <AlertRule>[];
    return DeviceAlertConfig(rules: rules);
  }

  Map<String, dynamic> toJson() => {
        'rules': rules.map((r) => r.toJson()).toList(),
      };

  /// Replace rule có cùng `key`, hoặc append nếu chưa có.
  DeviceAlertConfig upsertRule(AlertRule rule) {
    final next = List<AlertRule>.from(rules);
    final idx = next.indexWhere((r) => r.key == rule.key);
    if (idx >= 0) {
      next[idx] = rule;
    } else {
      next.add(rule);
    }
    return DeviceAlertConfig(rules: next);
  }

  AlertRule? findByKey(String key) {
    for (final r in rules) {
      if (r.key == key) return r;
    }
    return null;
  }
}
