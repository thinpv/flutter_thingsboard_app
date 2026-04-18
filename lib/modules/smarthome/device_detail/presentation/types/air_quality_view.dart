import 'package:flutter/material.dart';

import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: pm1_0, pm2_5, pm10, co2, temp, hum, bat/pin
class AirQualityView extends StatelessWidget {
  const AirQualityView({required this.telemetry, super.key});
  final Map<String, dynamic> telemetry;

  @override
  Widget build(BuildContext context) {
    final pm25 = doubleVal(telemetry['pm2_5']);
    final pm10 = doubleVal(telemetry['pm10']);
    final pm1 = doubleVal(telemetry['pm1_0']);
    final co2 = doubleVal(telemetry['co2']);
    final temp = doubleVal(telemetry['temp']);
    final hum = doubleVal(telemetry['hum']);

    final aqi = _calcAqi(pm25);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 16),

        // ── AQI hero card ──
        if (aqi != null) ...[
          _AqiHeroCard(aqi: aqi, pm25: pm25),
          const SizedBox(height: 20),
        ],

        // ── CO2 card ──
        if (co2 != null) ...[
          _Co2Card(co2: co2),
          const SizedBox(height: 16),
        ],

        // ── PM grid ──
        if (pm25 != null || pm10 != null || pm1 != null) ...[
          const Text(
            'Hạt bụi mịn',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MpColors.text,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (pm1 != null)
                Expanded(
                  child: InfoCard(
                    icon: Icons.grain,
                    label: 'PM1.0',
                    value: '${pm1.toStringAsFixed(0)} µg/m³',
                    iconColor: MpColors.green,
                    color: MpColors.greenSoft,
                  ),
                ),
              if (pm1 != null && (pm25 != null || pm10 != null))
                const SizedBox(width: 10),
              if (pm25 != null)
                Expanded(
                  child: InfoCard(
                    icon: Icons.grain,
                    label: 'PM2.5',
                    value: '${pm25.toStringAsFixed(0)} µg/m³',
                    iconColor: _pm25Color(pm25),
                    color: _pm25Color(pm25).withValues(alpha: 0.08),
                  ),
                ),
              if (pm25 != null && pm10 != null) const SizedBox(width: 10),
              if (pm10 != null)
                Expanded(
                  child: InfoCard(
                    icon: Icons.grain,
                    label: 'PM10',
                    value: '${pm10.toStringAsFixed(0)} µg/m³',
                    iconColor: _pm10Color(pm10),
                    color: _pm10Color(pm10).withValues(alpha: 0.08),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Temp + hum ──
        if (temp != null || hum != null) ...[
          Row(
            children: [
              if (temp != null)
                Expanded(
                  child: InfoCard(
                    icon: Icons.thermostat,
                    label: 'Nhiệt độ',
                    value: '${temp.toStringAsFixed(1)} °C',
                    iconColor: MpColors.amber,
                    color: MpColors.amberSoft,
                  ),
                ),
              if (temp != null && hum != null) const SizedBox(width: 10),
              if (hum != null)
                Expanded(
                  child: InfoCard(
                    icon: Icons.water_drop_outlined,
                    label: 'Độ ẩm',
                    value: '${hum.toStringAsFixed(0)}%',
                    iconColor: MpColors.blue,
                    color: MpColors.blue.withValues(alpha: 0.08),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        if (batLevel(telemetry) != null)
          BatteryIndicator(level: batLevel(telemetry)!.toDouble()),
      ],
    );
  }

  int? _calcAqi(double? pm25) {
    if (pm25 == null) return null;
    // Simple linear AQI approximation
    if (pm25 <= 12) return ((pm25 / 12) * 50).round();
    if (pm25 <= 35.4) return (((pm25 - 12.1) / (35.4 - 12.1)) * 50 + 50).round();
    if (pm25 <= 55.4) return (((pm25 - 35.5) / (55.4 - 35.5)) * 50 + 100).round();
    if (pm25 <= 150.4) return (((pm25 - 55.5) / (150.4 - 55.5)) * 100 + 150).round();
    return 300;
  }

  Color _pm25Color(double v) {
    if (v <= 12) return MpColors.green;
    if (v <= 35.4) return MpColors.amber;
    if (v <= 55.4) return MpColors.amber;
    return MpColors.red;
  }

  Color _pm10Color(double v) {
    if (v <= 54) return MpColors.green;
    if (v <= 154) return MpColors.amber;
    if (v <= 254) return MpColors.amber;
    return MpColors.red;
  }
}

class _AqiHeroCard extends StatelessWidget {
  const _AqiHeroCard({required this.aqi, this.pm25});
  final int aqi;
  final double? pm25;

  static ({String label, Color color, IconData icon}) _meta(int aqi) {
    if (aqi <= 50) return (label: 'Tốt', color: MpColors.green, icon: Icons.sentiment_very_satisfied);
    if (aqi <= 100) return (label: 'Trung bình', color: MpColors.amber, icon: Icons.sentiment_neutral);
    if (aqi <= 150) return (label: 'Không lành mạnh\n(nhóm nhạy cảm)', color: MpColors.amber, icon: Icons.sentiment_dissatisfied);
    if (aqi <= 200) return (label: 'Không lành mạnh', color: MpColors.red, icon: Icons.sentiment_very_dissatisfied);
    return (label: 'Rất nguy hiểm', color: MpColors.violet, icon: Icons.warning_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta(aqi);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            meta.color.withValues(alpha: 0.15),
            meta.color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: meta.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$aqi',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: meta.color,
                  height: 1,
                ),
              ),
              const Text(
                'AQI',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: MpColors.text3,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(meta.icon, color: meta.color, size: 32),
                const SizedBox(height: 6),
                Text(
                  meta.label,
                  style: TextStyle(
                    color: meta.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (pm25 != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'PM2.5: ${pm25!.toStringAsFixed(1)} µg/m³',
                    style: const TextStyle(color: MpColors.text3, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Co2Card extends StatelessWidget {
  const _Co2Card({required this.co2});
  final double co2;

  Color get _color {
    if (co2 < 600) return MpColors.green;
    if (co2 < 1000) return MpColors.amber;
    if (co2 < 1500) return MpColors.amber;
    return MpColors.red;
  }

  String get _label {
    if (co2 < 600) return 'Rất tốt';
    if (co2 < 1000) return 'Bình thường';
    if (co2 < 1500) return 'Cao';
    return 'Rất cao — Cần thông gió!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.co2, color: _color, size: 22),
              const SizedBox(width: 8),
              const Text(
                'CO₂',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MpColors.text,
                ),
              ),
              const Spacer(),
              Text(
                '${co2.toStringAsFixed(0)} ppm — $_label',
                style: TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (co2 / 2000).clamp(0.0, 1.0),
              backgroundColor: MpColors.surfaceAlt,
              color: _color,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
