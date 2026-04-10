import 'dart:math' as math;

import 'package:flutter/material.dart';

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

// ─── Online Badge ─────────────────────────────────────────────────────────────

class OnlineBadge extends StatelessWidget {
  const OnlineBadge({required this.isOnline, super.key});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.12),
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
              color: isOnline ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isOnline ? Colors.green.shade700 : Colors.grey.shade600,
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
    final color = activeColor ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOn
              ? color.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isOn ? color : Colors.grey.shade300,
            width: 3,
          ),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: (glowColor ?? color).withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: size * 0.4,
          color: isOn ? color : Colors.grey.shade400,
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
    final c = color ?? Theme.of(context).colorScheme.primaryContainer;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: iconColor ?? Theme.of(context).colorScheme.primary),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
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
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
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
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Theme.of(context).colorScheme.primary,
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
        ? Colors.green
        : level > 20
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
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
            size: 28,
          ),
          const SizedBox(width: 12),
          Text('Pin', style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            '${level.round()}%',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
    final color = detected ? alertColor : Colors.grey;
    return Column(
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color, width: 3),
          ),
          child: Icon(icon, size: 60, color: color),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
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
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
        ..color = Colors.grey.shade200
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
