import 'package:flutter/material.dart';

import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: temp, hum (soil moisture %), phSoil, phWater, ecSoil, ecWater, percentOxyWater, bat/pin
class SoilSensorView extends StatelessWidget {
  const SoilSensorView({required this.telemetry, super.key});
  final Map<String, dynamic> telemetry;

  @override
  Widget build(BuildContext context) {
    final temp = doubleVal(telemetry['temp']);
    final hum = doubleVal(telemetry['hum']); // soil moisture %
    final phSoil = doubleVal(telemetry['phSoil']);
    final phWater = doubleVal(telemetry['phWater']);
    final ecSoil = doubleVal(telemetry['ecSoil']);
    final ecWater = doubleVal(telemetry['ecWater']);
    final oxyWater = doubleVal(telemetry['percentOxyWater']);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 16),

        // ── Soil moisture hero ──
        if (hum != null) ...[
          _SoilMoistureCard(hum: hum),
          const SizedBox(height: 16),
        ],

        // ── Temperature ──
        if (temp != null) ...[
          InfoCard(
            icon: Icons.thermostat,
            label: 'Nhiệt độ đất',
            value: '${temp.toStringAsFixed(1)} °C',
            iconColor: MpColors.amber,
            color: MpColors.amberSoft,
          ),
          const SizedBox(height: 12),
        ],

        // ── pH section ──
        if (phSoil != null || phWater != null) ...[
          const Text(
            'Độ pH',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MpColors.text,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (phSoil != null)
                Expanded(child: _PhCard(value: phSoil, label: 'pH đất', icon: Icons.yard)),
              if (phSoil != null && phWater != null) const SizedBox(width: 10),
              if (phWater != null)
                Expanded(child: _PhCard(value: phWater, label: 'pH nước', icon: Icons.water)),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── EC section ──
        if (ecSoil != null || ecWater != null) ...[
          const Text(
            'Độ dẫn điện (EC)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MpColors.text,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (ecSoil != null)
                Expanded(
                  child: InfoCard(
                    icon: Icons.electric_bolt,
                    label: 'EC đất',
                    value: '${ecSoil.toStringAsFixed(0)} µS/cm',
                    iconColor: MpColors.amber,
                    color: MpColors.amberSoft,
                  ),
                ),
              if (ecSoil != null && ecWater != null) const SizedBox(width: 10),
              if (ecWater != null)
                Expanded(
                  child: InfoCard(
                    icon: Icons.electric_bolt,
                    label: 'EC nước',
                    value: '${ecWater.toStringAsFixed(0)} µS/cm',
                    iconColor: MpColors.blue,
                    color: MpColors.blue.withValues(alpha: 0.08),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Dissolved oxygen ──
        if (oxyWater != null) ...[
          InfoCard(
            icon: Icons.bubble_chart,
            label: 'Oxy hòa tan',
            value: '${oxyWater.toStringAsFixed(1)}%',
            iconColor: MpColors.blue,
            color: MpColors.blue.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 16),
        ],

        if (batLevel(telemetry) != null)
          BatteryIndicator(level: batLevel(telemetry)!.toDouble()),
      ],
    );
  }
}

class _SoilMoistureCard extends StatelessWidget {
  const _SoilMoistureCard({required this.hum});
  final double hum;

  Color get _color {
    if (hum < 20) return MpColors.red;
    if (hum < 40) return MpColors.amber;
    if (hum <= 70) return MpColors.green;
    return MpColors.blue;
  }

  String get _label {
    if (hum < 20) return 'Rất khô — cần tưới ngay!';
    if (hum < 40) return 'Khô — nên tưới nước';
    if (hum <= 70) return 'Độ ẩm tốt';
    return 'Ẩm ướt';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _color.withValues(alpha: 0.15),
            _color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop, color: _color, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Độ ẩm đất',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MpColors.text,
                ),
              ),
              const Spacer(),
              Text(
                '${hum.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: hum / 100,
              backgroundColor: MpColors.surfaceAlt,
              color: _color,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _label,
            style: TextStyle(color: _color, fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PhCard extends StatelessWidget {
  const _PhCard({required this.value, required this.label, required this.icon});
  final double value;
  final String label;
  final IconData icon;

  Color get _color {
    if (value < 5.5) return MpColors.red;
    if (value < 6.0) return MpColors.amber;
    if (value <= 7.0) return MpColors.green;
    if (value <= 7.5) return MpColors.green;
    return MpColors.blue;
  }

  String get _phLabel {
    if (value < 5.5) return 'Acid mạnh';
    if (value < 6.0) return 'Acid nhẹ';
    if (value <= 7.0) return 'Trung tính';
    if (value <= 7.5) return 'Kiềm nhẹ';
    return 'Kiềm mạnh';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: MpColors.text2, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _color,
              height: 1,
            ),
          ),
          Text(
            _phLabel,
            style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
