import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';

// ─── Helpers (top-level, accessible from all type files) ─────────────────────

/// True if value is on — handles int 1, string "1"/"true", or bool true.
/// Gateway/TB may publish any of these encodings, so be defensive.
bool isOn(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return false;
}

/// Coerce a telemetry value to num. Handles num, numeric String
/// (e.g. "27.44" — TB stores telemetry as String when gateway publishes
/// quoted values), and bool (true→1, false→0). Returns null if unparseable.
num? numVal(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is bool) return v ? 1 : 0;
  if (v is String) return num.tryParse(v);
  return null;
}

double? doubleVal(dynamic v) => numVal(v)?.toDouble();
int? intVal(dynamic v) => numVal(v)?.toInt();

/// Battery level from `bat` (Zigbee) or `pin` (BLE).
num? batLevel(Map<String, dynamic> t) => numVal(t['bat']) ?? numVal(t['pin']);

/// Detect on/off switch gang keys regardless of which key convention the
/// gateway publishes. Returns the keys in physical order with localized
/// labels. Always returns at least one entry.
///
/// Detected gang list for a multi-channel switch.
///
/// Detection priority:
///   1. [meta] — if profile defines `onoff*` states, use those (authoritative
///      channel count even if some channels have no telemetry yet).
///   2. Telemetry keys — fall back to continuous-key scan for each convention:
///      - Tuya TS0601:    bt, bt2, bt3, bt4
///      - BLE relay:      rl0..rlN, or single rl
///      - Zigbee on/off:  onoff0..onoffN
///
/// Using [meta] ensures the correct number of buttons is shown from the moment
/// the profile loads, even if some channels have never changed state and
/// therefore have no entry in ThingsBoard telemetry yet.
List<({String key, String label})> detectSwitchGangs(
    Map<String, dynamic> telemetry, {ProfileMetadata? meta}) {
  // ── 1. Profile metadata takes precedence for onoff* channels ──────────────
  if (meta != null && meta.states.isNotEmpty) {
    final onoffKeys = meta.states.keys
        .where((k) => k.startsWith('onoff'))
        .toList()
      ..sort();
    if (onoffKeys.isNotEmpty) {
      return [
        for (var i = 0; i < onoffKeys.length; i++)
          (key: onoffKeys[i], label: 'Nút ${i + 1}'),
      ];
    }
  }

  // ── 2. Telemetry-based detection (fallback when no meta) ──────────────────
  // Tuya TS0601: bt, bt2, bt3, bt4
  if (telemetry.containsKey('bt')) {
    final keys = ['bt'];
    for (var i = 2; telemetry.containsKey('bt$i'); i++) {
      keys.add('bt$i');
    }
    return [
      for (var i = 0; i < keys.length; i++)
        (key: keys[i], label: 'Nút ${i + 1}'),
    ];
  }
  // BLE relay: rl0, rl1...
  if (telemetry.containsKey('rl0')) {
    final keys = <String>[];
    for (var i = 0; telemetry.containsKey('rl$i'); i++) {
      keys.add('rl$i');
    }
    return [
      for (var i = 0; i < keys.length; i++)
        (key: keys[i], label: 'Nút ${i + 1}'),
    ];
  }
  if (telemetry.containsKey('rl')) {
    return [(key: 'rl', label: 'Công tắc')];
  }
  // Zigbee on/off: onoff0, onoff1...
  if (telemetry.containsKey('onoff0')) {
    final keys = <String>[];
    for (var i = 0; telemetry.containsKey('onoff$i'); i++) {
      keys.add('onoff$i');
    }
    return [
      for (var i = 0; i < keys.length; i++)
        (key: keys[i], label: 'Nút ${i + 1}'),
    ];
  }
  // Fallback so the UI never renders empty.
  return [(key: 'onoff0', label: 'Công tắc')];
}

// ─── Online Badge ─────────────────────────────────────────────────────────────

class OnlineBadge extends StatelessWidget {
  const OnlineBadge({required this.isOnline, super.key});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline ? MpColors.greenSoft : MpColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? MpColors.green : MpColors.text3,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isOnline ? MpColors.green : MpColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Power Button ─────────────────────────────────────────────────────────────

class PowerButton extends StatelessWidget {
  const PowerButton({
    required this.isOn,
    required this.onTap,
    required this.icon,
    this.size = 100,
    this.activeColor,
    this.glowColor,
    super.key,
  });
  final bool isOn;
  final VoidCallback onTap;
  final IconData icon;
  final double size;
  final Color? activeColor;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? MpColors.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOn ? color.withValues(alpha: 0.1) : MpColors.surfaceAlt,
          border: Border.all(
            color: isOn ? color : MpColors.border,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          size: size * 0.4,
          color: isOn ? color : MpColors.text3,
        ),
      ),
    );
  }
}

// ─── Info Card ────────────────────────────────────────────────────────────────

class InfoCard extends StatelessWidget {
  const InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.iconColor,
    super.key,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? MpColors.surfaceAlt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor ?? MpColors.text2),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MpColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: MpColors.text3),
          ),
        ],
      ),
    );
  }
}

// ─── Detail Row ───────────────────────────────────────────────────────────────

class DetailRow extends StatelessWidget {
  const DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: MpColors.text3),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 14, color: MpColors.text)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MpColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Tile ────────────────────────────────────────────────────────────────

class InfoTile extends StatelessWidget {
  const InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    super.key,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: MpColors.text3),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 14, color: MpColors.text)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? MpColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Battery Indicator ────────────────────────────────────────────────────────

class BatteryIndicator extends StatelessWidget {
  const BatteryIndicator({required this.level, super.key});
  final double level;

  @override
  Widget build(BuildContext context) {
    final color = level > 50
        ? MpColors.green
        : level > 20
            ? MpColors.amber
            : MpColors.red;
    final bg = level > 50
        ? MpColors.greenSoft
        : level > 20
            ? MpColors.amberSoft
            : MpColors.redSoft;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            level > 80
                ? Icons.battery_full
                : level > 50
                    ? Icons.battery_5_bar
                    : level > 20
                        ? Icons.battery_3_bar
                        : Icons.battery_1_bar,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 10),
          const Text('Pin',
              style: TextStyle(fontSize: 14, color: MpColors.text)),
          const Spacer(),
          Text(
            '${level.round()}%',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Alert Circle (smoke/leak) ────────────────────────────────────────────────

class AlertCircle extends StatelessWidget {
  const AlertCircle({
    required this.icon,
    required this.label,
    required this.detected,
    required this.alertColor,
    super.key,
  });
  final IconData icon;
  final String label;
  final bool detected;
  final Color alertColor;

  @override
  Widget build(BuildContext context) {
    final color = detected ? alertColor : MpColors.text3;
    return Column(
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, size: 60, color: color),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Slider Section ───────────────────────────────────────────────────────────

class SliderSection extends StatelessWidget {
  const SliderSection({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.divisions,
    this.activeColor,
    super.key,
  });
  final IconData icon;
  final String label;
  final String valueLabel;
  final double value, min, max;
  final int? divisions;
  final Color? activeColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: MpColors.text3),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontSize: 14, color: MpColors.text)),
            const Spacer(),
            Text(
              valueLabel,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MpColors.text),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: activeColor,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}

// ─── Wall Plate Buttons ───────────────────────────────────────────────────────

/// Tuya-style wall plate visualisation. Each button maps to one gang. Layout
/// adapts to button count (1: single, 2: row, 3: row, 4: 2×2 grid) to match
/// real physical wall plates.
class WallPlateButton {
  const WallPlateButton({
    required this.label,
    required this.isOn,
    required this.onTap,
    this.icon = Icons.lightbulb_outline,
  });
  final String label;
  final bool isOn;
  final VoidCallback onTap;
  final IconData icon;
}

class WallPlateView extends StatelessWidget {
  const WallPlateView({required this.buttons, super.key});
  final List<WallPlateButton> buttons;

  @override
  Widget build(BuildContext context) {
    final n = buttons.length;
    if (n == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MpColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: switch (n) {
        1 => _singleLayout(),
        2 => _rowLayout(),
        3 => _rowLayout(),
        _ => _gridLayout(),
      },
    );
  }

  Widget _singleLayout() => SizedBox(
        height: 220,
        child: _Button(button: buttons[0]),
      );

  Widget _rowLayout() => SizedBox(
        height: 200,
        child: Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _Button(button: buttons[i])),
            ],
          ],
        ),
      );

  Widget _gridLayout() {
    // 2×2 (or 2×ceil(n/2)) grid for 4+ gangs.
    final rows = <Widget>[];
    for (var i = 0; i < buttons.length; i += 2) {
      final left = buttons[i];
      final right = i + 1 < buttons.length ? buttons[i + 1] : null;
      if (i > 0) rows.add(const SizedBox(height: 12));
      rows.add(SizedBox(
        height: 130,
        child: Row(
          children: [
            Expanded(child: _Button(button: left)),
            const SizedBox(width: 12),
            Expanded(
              child: right != null
                  ? _Button(button: right)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.button});
  final WallPlateButton button;

  @override
  Widget build(BuildContext context) {
    final isOn = button.isOn;
    return InkWell(
      onTap: button.onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isOn ? MpColors.text : MpColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOn ? MpColors.text : MpColors.border,
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOn
                    ? MpColors.amberSoft
                    : MpColors.surfaceAlt,
              ),
              child: Icon(
                button.icon,
                color: isOn ? MpColors.amber : MpColors.text3,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                button.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isOn ? MpColors.bg : MpColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              isOn ? 'BẬT' : 'TẮT',
              style: TextStyle(
                color: isOn ? MpColors.bg.withValues(alpha: 0.6) : MpColors.text3,
                fontWeight: FontWeight.w500,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Gauge Painter ────────────────────────────────────────────────────────────

class GaugePainter extends CustomPainter {
  const GaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.color,
  });
  final double value, min, max;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const startAngle = 2.4;
    const sweepTotal = 4.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      Paint()
        ..color = const Color(0xFFE0E0DA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal * fraction,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(GaugePainter old) => old.value != value;
}
