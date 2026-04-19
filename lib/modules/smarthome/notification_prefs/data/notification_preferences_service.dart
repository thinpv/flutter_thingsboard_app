import 'package:hive_flutter/hive_flutter.dart';

/// Local Hive-backed preferences cho category notification.
///
/// Categories khớp với spec NOTIFICATION_SYSTEM.md §6.4 (FCM `data.category`):
///   - `device_alert` — UC1 cảnh báo thiết bị + alarm system
///   - `automation` — UC2 push từ action `notify` của automation
///   - `system_announcement` — UC3 admin broadcast
///
/// Mặc định BẬT cho mọi category. User toggle OFF → key được lưu thành false.
class NotificationPreferencesService {
  NotificationPreferencesService._();
  static final instance = NotificationPreferencesService._();

  static const _boxName = 'notification_prefs';

  Box<bool>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<bool>(_boxName);
  }

  /// True (mặc định) = nhận push. False = mute category này.
  bool isEnabled(String category) {
    final box = _box;
    if (box == null) return true;
    return box.get(category, defaultValue: true) ?? true;
  }

  Future<void> setEnabled(String category, bool enabled) async {
    final box = _box;
    if (box == null) return;
    await box.put(category, enabled);
  }
}
