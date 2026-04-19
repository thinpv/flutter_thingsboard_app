import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/notification_prefs/data/notification_preferences_service.dart';

/// Categories app hỗ trợ filter (spec §6.4).
class NotifCategory {
  static const deviceAlert = 'device_alert';
  static const automation = 'automation';
  static const systemAnnouncement = 'system_announcement';

  static const all = [deviceAlert, automation, systemAnnouncement];
}

final notificationPrefsServiceProvider =
    Provider<NotificationPreferencesService>((ref) {
  return NotificationPreferencesService.instance;
});

/// Reactive state per-category. Read fallback `true` nếu chưa init.
class NotificationPrefsNotifier extends StateNotifier<Map<String, bool>> {
  NotificationPrefsNotifier(this._svc) : super(_load(_svc));

  final NotificationPreferencesService _svc;

  static Map<String, bool> _load(NotificationPreferencesService svc) {
    return {for (final c in NotifCategory.all) c: svc.isEnabled(c)};
  }

  Future<void> setEnabled(String category, bool enabled) async {
    await _svc.setEnabled(category, enabled);
    state = {...state, category: enabled};
  }
}

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, Map<String, bool>>((ref) {
  return NotificationPrefsNotifier(ref.read(notificationPrefsServiceProvider));
});
