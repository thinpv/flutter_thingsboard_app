import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';

// ─── Metric icon + color resolver ─────────────────────────────────────────────

({IconData icon, Color color, bool pulse}) _resolveMetric(
    String key, dynamic raw) {
  final n = raw is num ? raw.toDouble() : double.tryParse(raw.toString());

  switch (key) {
    case 'temp':
      final t = n ?? 25;
      return (
        icon: Icons.device_thermostat,
        color: t < 18
            ? const Color(0xFF42A5F5)
            : t < 26
                ? const Color(0xFF66BB6A)
                : t < 32
                    ? const Color(0xFFFFA726)
                    : const Color(0xFFEF5350),
        pulse: t > 35,
      );

    case 'hum':
      final h = n ?? 50;
      return (
        icon: Icons.water_drop,
        color: h < 30
            ? const Color(0xFFFFA726)
            : h < 70
                ? const Color(0xFF42A5F5)
                : const Color(0xFF1565C0),
        pulse: false,
      );

    case 'power':
      final p = n ?? 0;
      return (
        icon: Icons.bolt,
        color: p < 1
            ? MpColors.text3
            : p < 100
                ? const Color(0xFF66BB6A)
                : p < 500
                    ? const Color(0xFFFFA726)
                    : const Color(0xFFEF5350),
        pulse: p > 1000,
      );

    case 'energy':
      return (
        icon: Icons.electric_meter,
        color: const Color(0xFF7E57C2),
        pulse: false,
      );

    case 'pir':
      final detected = raw == 1 || raw == true || raw == '1';
      return (
        icon: Icons.motion_photos_on_outlined,
        color: detected ? const Color(0xFFFFA726) : MpColors.text3,
        pulse: detected,
      );

    case 'door':
      final open = raw == false || raw == 0 || raw == '0';
      return (
        icon: open ? Icons.sensor_door_outlined : Icons.door_front_door_outlined,
        color: open ? const Color(0xFFFFA726) : const Color(0xFF66BB6A),
        pulse: open,
      );

    case 'lux':
      final l = n ?? 0;
      return (
        icon: Icons.wb_sunny_outlined,
        color: l < 100
            ? MpColors.text3
            : l < 500
                ? const Color(0xFFFDD835)
                : const Color(0xFFFFA726),
        pulse: false,
      );

    case 'co2':
      final c = n ?? 400;
      return (
        icon: Icons.air,
        color: c < 800
            ? const Color(0xFF66BB6A)
            : c < 1500
                ? const Color(0xFFFFA726)
                : const Color(0xFFEF5350),
        pulse: c > 1500,
      );

    case 'pm25':
      final p = n ?? 0;
      return (
        icon: Icons.grain,
        color: p < 12
            ? const Color(0xFF66BB6A)
            : p < 35
                ? const Color(0xFFFFA726)
                : const Color(0xFFEF5350),
        pulse: p > 35,
      );

    case 'smoke':
      final on = raw == 1 || raw == true || raw == '1';
      return (
        icon: Icons.local_fire_department_outlined,
        color: on ? const Color(0xFFEF5350) : MpColors.text3,
        pulse: on,
      );

    case 'leak':
      final on = raw == 1 || raw == true || raw == '1';
      return (
        icon: Icons.water_damage_outlined,
        color: on ? const Color(0xFF1565C0) : MpColors.text3,
        pulse: on,
      );

    case 'bat':
    case 'pin':
      final b = n ?? 100;
      return (
        icon: b > 60
            ? Icons.battery_full
            : b > 20
                ? Icons.battery_3_bar
                : Icons.battery_1_bar,
        color: b > 20 ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
        pulse: b < 10,
      );

    case 'volt':
      return (icon: Icons.electric_bolt, color: const Color(0xFFFDD835), pulse: false);

    case 'curr':
      return (icon: Icons.waves, color: const Color(0xFF42A5F5), pulse: false);

    default:
      return (icon: Icons.sensors, color: MpColors.text3, pulse: false);
  }
}

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
      chips.add(_MetricChip(metricKey: k, raw: raw, label: '$display$unit'));
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

// ─── Small metric chip with icon ──────────────────────────────────────────────

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.metricKey,
    required this.raw,
    required this.label,
  });
  final String metricKey;
  final dynamic raw;
  final String label;

  @override
  Widget build(BuildContext context) {
    final m = _resolveMetric(metricKey, raw);
    final iconWidget = m.pulse
        ? _PulsingIcon(icon: m.icon, color: m.color, size: 9)
        : Icon(m.icon, size: 9, color: m.color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: MpColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: MpColors.text2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulsing icon (for alert states) ─────────────────────────────────────────

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Icon(widget.icon, size: widget.size, color: widget.color),
      ),
    );
  }
}
