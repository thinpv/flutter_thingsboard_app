import 'package:flutter/material.dart';

/// Shared icon registry — 1 nguồn duy nhất map String name → IconData.
///
/// Dùng cho:
/// - Automation/Scene icon picker ([automation_edit_page.dart])
/// - Notify action icon picker (automation action type="notify")
/// - Alert templates trong device profile description (`alertTemplates[].icon`)
/// - Render icon trong tab Thông báo ([notifications_sub_tab.dart]) đọc từ
///   `notification.additionalConfig.icon`
///
/// Giữ key snake_case (khớp với icon name trong Material icons + i18n tiện),
/// Material IconData tương ứng được chọn theo semantic gần nhất. Khi thêm icon
/// mới, thêm vào cả `kSmarthomeIcons` và cân nhắc expose từ picker UI.
const Map<String, IconData> kSmarthomeIcons = {
  // Automation / scene
  'auto_awesome': Icons.auto_awesome,
  'wb_sunny': Icons.wb_sunny,
  'nights_stay': Icons.nights_stay,
  'thermostat': Icons.thermostat,
  'schedule': Icons.schedule,
  'lightbulb': Icons.lightbulb_outline,
  'security': Icons.security,
  'home': Icons.home_outlined,

  // Alert templates — device state alerts
  'door_open': Icons.sensor_door_outlined,
  'battery_alert': Icons.battery_alert,
  'motion': Icons.directions_run,
  'smoke': Icons.smoke_free_outlined,
  'water_drop': Icons.water_drop_outlined,
  'gas': Icons.local_fire_department_outlined,
  'vibration': Icons.vibration,
  'lock': Icons.lock_outline,

  // Notification / system
  'warning': Icons.warning_amber_rounded,
  'error': Icons.error_outline,
  'info': Icons.info_outline,
  'notifications': Icons.notifications_outlined,
  'system_update': Icons.system_update_alt,
  'build': Icons.build_outlined,
  'devices': Icons.devices_other_outlined,
  'campaign': Icons.campaign_outlined,
};

/// Icon picker row cho automation/scene — tên hiển thị trong UI picker.
/// Giữ subset nhỏ để UI không quá tải.
const List<String> kAutomationIconKeys = [
  'auto_awesome',
  'wb_sunny',
  'nights_stay',
  'thermostat',
  'schedule',
  'lightbulb',
  'security',
  'home',
];

/// Icon picker row cho notify action — tập trung vào cảnh báo / thông tin.
const List<String> kNotifyIconKeys = [
  'notifications',
  'info',
  'warning',
  'error',
  'security',
  'home',
  'lightbulb',
  'campaign',
];

/// Palette hex cho color picker (automation + notify dùng chung).
const List<String> kSmarthomeColors = [
  '#2196F3', // blue
  '#FF9800', // orange
  '#4CAF50', // green
  '#E91E63', // pink
  '#9C27B0', // purple
  '#FF5722', // deep orange
  '#607D8B', // blue grey
  '#00BCD4', // cyan
];

/// Resolve icon name → IconData. Trả về [fallback] nếu name không có trong
/// registry hoặc null.
IconData iconByName(String? name,
    {IconData fallback = Icons.notifications_outlined}) {
  if (name == null || name.isEmpty) return fallback;
  return kSmarthomeIcons[name] ?? fallback;
}

/// Parse hex string `#RRGGBB` → Color. Trả [fallback] nếu không parse được.
Color colorByHex(String? hex, {Color fallback = const Color(0xFF2196F3)}) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return fallback;
  }
}
