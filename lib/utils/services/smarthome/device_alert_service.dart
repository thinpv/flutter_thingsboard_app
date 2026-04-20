import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/device_alert/domain/device_alert_config.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

/// Read/write `alertConfig` và `muteUntilTs` SERVER_SCOPE attributes
/// trên Device. Tuân thủ NOTIFICATION_SYSTEM.md §4.1.
class DeviceAlertService {
  DeviceAlertService();

  static const _kAlertConfigKey = 'alertConfig';
  static const _kMuteUntilKey = 'muteUntilTs';

  ThingsboardClient get _client => getIt<ITbClientService>().client;

  Future<DeviceAlertConfig> fetchConfig(String deviceId) async {
    final entries = await _client.getAttributeService().getAttributesByScope(
          DeviceId(deviceId),
          'SERVER_SCOPE',
          [_kAlertConfigKey],
        );
    for (final e in entries) {
      if (e.getKey() == _kAlertConfigKey) {
        final raw = e.getValue();
        if (raw is Map<String, dynamic>) {
          return DeviceAlertConfig.fromJson(raw);
        }
      }
    }
    return DeviceAlertConfig.empty;
  }

  Future<void> saveConfig(String deviceId, DeviceAlertConfig config) async {
    await _client.getAttributeService().saveEntityAttributesV2(
          DeviceId(deviceId),
          'SERVER_SCOPE',
          {_kAlertConfigKey: config.toJson()},
        );
  }

  /// Lấy timestamp mute hiện tại (millisecondsSinceEpoch) hoặc null nếu
  /// chưa set / đã hết hạn.
  Future<int?> fetchMuteUntil(String deviceId) async {
    final entries = await _client.getAttributeService().getAttributesByScope(
          DeviceId(deviceId),
          'SERVER_SCOPE',
          [_kMuteUntilKey],
        );
    for (final e in entries) {
      if (e.getKey() == _kMuteUntilKey) {
        final raw = e.getValue();
        if (raw is int) return raw;
        if (raw is String) return int.tryParse(raw);
      }
    }
    return null;
  }

  Future<void> setMuteUntil(String deviceId, int? untilMs) async {
    await _client.getAttributeService().saveEntityAttributesV2(
          DeviceId(deviceId),
          'SERVER_SCOPE',
          {_kMuteUntilKey: untilMs},
        );
  }

  /// Convenience: tắt mute (set null).
  Future<void> clearMute(String deviceId) => setMuteUntil(deviceId, null);
}
