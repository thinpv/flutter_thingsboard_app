import 'package:flutter/material.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';

/// Builds the inner content of a [DeviceCard] from [ProfileMetadata].
///
/// When profile metadata is available (backend patch A-S-2 deployed), the card:
/// - Uses [UiHints.primaryState] to determine the toggle key / main indicator
/// - Uses [UiHints.summaryStates] to show compact metric chips
/// - Uses [ProfileMetadata.colorPrimary] as accent if provided
///
/// When metadata is absent (empty ProfileMetadata), callers should fall back
/// to the legacy [DeviceCard] logic (hardcoded uiType switch).
class CardComposer {
  CardComposer._();

  /// Returns true if [meta] contains enough hints to drive the card.
  /// Callers should fall back to legacy rendering when this returns false.
  static bool canCompose(ProfileMetadata meta) {
    return !meta.isEmpty;
  }

  /// Resolves whether the primary state key is ON for this device.
  ///
  /// Priority:
  /// 1. [UiHints.primaryState] key in telemetry
  /// 2. 'onoff0' fallback
  static bool resolveIsOn(SmarthomeDevice device, ProfileMetadata meta) {
    final key = meta.uiHints?.primaryState ?? 'onoff0';
    final raw = device.telemetry[key];
    if (raw == null) return false;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final s = raw.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 'on';
  }

  /// Returns true if the primary state is a controllable bool/toggle.
  static bool hasPrimaryToggle(ProfileMetadata meta) {
    final key = meta.uiHints?.primaryState ?? 'onoff0';
    final def = meta.states[key];
    if (def == null) return false;
    return def.controllable && def.type == 'bool';
  }

  /// Builds the summary metric chips row from [UiHints.summaryStates].
  ///
  /// Each chip shows `value unit` for the corresponding key.
  /// Returns null if summaryStates is empty.
  static Widget? buildSummaryRow(
    BuildContext context,
    SmarthomeDevice device,
    ProfileMetadata meta,
  ) {
    final keys = meta.uiHints?.summaryStates ?? [];
    if (keys.isEmpty) return null;

    final chips = <Widget>[];
    for (final k in keys) {
      final raw = device.telemetry[k];
      if (raw == null) continue;
      final def = meta.states[k];
      final unit = def?.unit ?? '';
      final precision = def?.precision ?? _inferPrecision(raw);
      final display = _formatValue(raw, precision);
      chips.add(_MetricChip(value: '$display$unit'));
    }

    if (chips.isEmpty) return null;
    return Wrap(spacing: 6, children: chips);
  }

  /// Resolves the icon for the card — prefers metadata icon over uiType fallback.
  static IconData resolveIcon(SmarthomeDevice device, ProfileMetadata meta) {
    final iconName = meta.icon;
    if (iconName != null) {
      return _iconFromName(iconName);
    }
    // Prefer meta.uiType (from description JSON — always the correct short key)
    // over device.effectiveUiType which may be the full TB type string.
    final type = (meta.uiType != 'auto' && meta.uiType.isNotEmpty)
        ? meta.uiType
        : device.effectiveUiType;
    return _iconForUiType(type);
  }

  /// Resolves the primary accent color from metadata hex string.
  static Color? resolveAccentColor(ProfileMetadata meta) {
    final hex = meta.colorPrimary;
    if (hex == null) return null;
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return null;
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  static String _formatValue(dynamic v, int precision) {
    if (v == null) return '—';
    final n = v is num ? v : num.tryParse(v.toString());
    if (n == null) return v.toString();
    return n.toStringAsFixed(precision);
  }

  static int _inferPrecision(dynamic v) {
    final n = v is num ? v : num.tryParse(v.toString());
    if (n == null) return 0;
    return n == n.truncate() ? 0 : 1;
  }

  static IconData _iconFromName(String name) => switch (name) {
        'lightbulb' || 'lightbulb_outline' => Icons.lightbulb_outline,
        'ac_unit' => Icons.ac_unit,
        'electrical_services' => Icons.electrical_services,
        'blinds' => Icons.blinds,
        'sensor_door' || 'sensor_door_outlined' => Icons.sensor_door_outlined,
        'thermostat' => Icons.thermostat,
        'videocam' || 'videocam_outlined' => Icons.videocam_outlined,
        'router' || 'router_outlined' => Icons.router_outlined,
        'toggle_on' || 'toggle_on_outlined' => Icons.toggle_on_outlined,
        'lock' || 'lock_outline' => Icons.lock_outline,
        'local_fire_department' => Icons.local_fire_department_outlined,
        'water_drop' || 'water_drop_outlined' => Icons.water_drop_outlined,
        'air' => Icons.air,
        'grass' => Icons.grass,
        'power_settings_new' => Icons.power_settings_new,
        'motion_photos_on' => Icons.motion_photos_on_outlined,
        'settings_remote' => Icons.settings_remote_outlined,
        _ => Icons.devices_other,
      };

  static IconData _iconForUiType(String type) => switch (type) {
        'light' => Icons.lightbulb_outline,
        'airConditioner' => Icons.ac_unit,
        'smartPlug' => Icons.electrical_services,
        'curtain' => Icons.blinds,
        'doorSensor' => Icons.sensor_door_outlined,
        'motionSensor' => Icons.motion_photos_on_outlined,
        'tempHumidity' => Icons.thermostat,
        'camera' => Icons.videocam_outlined,
        'gateway' => Icons.router_outlined,
        'switch' => Icons.toggle_on_outlined,
        'remote' || 'button' || 'sceneSwitch' => Icons.settings_remote_outlined,
        'lock' => Icons.lock_outline,
        'smokeSensor' => Icons.local_fire_department_outlined,
        'leakSensor' => Icons.water_drop_outlined,
        'airQuality' => Icons.air,
        'soilSensor' => Icons.grass,
        'electricalSwitch' => Icons.power_settings_new,
        _ => Icons.devices_other,
      };
}

// ─── Small metric chip ─────────────────────────────────────────────────────────

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
