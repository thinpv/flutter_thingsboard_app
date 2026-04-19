import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/device_alert/domain/device_alert_config.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_alert_service.dart';

final deviceAlertServiceProvider = Provider<DeviceAlertService>((ref) {
  return DeviceAlertService();
});

/// Đọc `alert_config` SERVER_SCOPE của device.
final deviceAlertConfigProvider = FutureProvider.autoDispose
    .family<DeviceAlertConfig, String>((ref, deviceId) {
  return ref.read(deviceAlertServiceProvider).fetchConfig(deviceId);
});

/// Đọc `mute_until_ts` SERVER_SCOPE. Trả về null nếu không có hoặc đã quá hạn.
final deviceMuteUntilProvider =
    FutureProvider.autoDispose.family<int?, String>((ref, deviceId) async {
  final ts = await ref.read(deviceAlertServiceProvider).fetchMuteUntil(deviceId);
  if (ts == null) return null;
  if (ts < DateTime.now().millisecondsSinceEpoch) return null;
  return ts;
});
