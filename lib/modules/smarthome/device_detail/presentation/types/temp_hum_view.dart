import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: temp (°C), hum (%), pressure (hPa), bat/pin
class TempHumView extends StatelessWidget {
  const TempHumView({required this.telemetry, super.key});
  final Map<String, dynamic> telemetry;

  @override
  Widget build(BuildContext context) {
    final temp = (telemetry['temp'] as num?)?.toDouble();
    final hum = (telemetry['hum'] as num?)?.toDouble();
    final pressure = (telemetry['pressure'] as num?)?.toDouble();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 16),

        // ── Temperature gauge ──
        if (temp != null) ...[
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: GaugePainter(
                  value: temp,
                  min: -10,
                  max: 50,
                  color: _tempColor(temp),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        temp.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _tempColor(temp),
                              height: 1,
                            ),
                      ),
                      Text(
                        '°C',
                        style: TextStyle(
                          fontSize: 20,
                          color: _tempColor(temp),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: _TempBadge(temp: temp),
          ),
          const SizedBox(height: 24),
        ],

        // ── Humidity bar ──
        if (hum != null) ...[
          _HumidityCard(hum: hum),
          const SizedBox(height: 12),
        ],

        // ── Pressure + battery ──
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            if (pressure != null)
              InfoCard(
                icon: Icons.compress,
                label: 'Áp suất',
                value: '${pressure.toStringAsFixed(0)} hPa',
                iconColor: Colors.blueGrey,
                color: Colors.blueGrey.shade50,
              ),
            if (batLevel(telemetry) != null)
              InfoCard(
                icon: Icons.battery_std,
                label: 'Pin',
                value: '${batLevel(telemetry)}%',
                iconColor: Colors.green,
                color: Colors.green.shade50,
              ),
          ],
        ),
      ],
    );
  }

  Color _tempColor(double t) {
    if (t < 10) return Colors.blue;
    if (t < 20) return Colors.cyan;
    if (t < 28) return Colors.green;
    if (t < 35) return Colors.orange;
    return Colors.red;
  }
}

class _TempBadge extends StatelessWidget {
  const _TempBadge({required this.temp});
  final double temp;

  static String _label(double t) {
    if (t < 10) return '🥶 Rất lạnh';
    if (t < 20) return '❄️ Mát';
    if (t < 28) return '✅ Thoải mái';
    if (t < 35) return '🌡️ Nóng';
    return '🔥 Rất nóng';
  }

  static Color _color(double t) {
    if (t < 10) return Colors.blue;
    if (t < 20) return Colors.cyan;
    if (t < 28) return Colors.green;
    if (t < 35) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(temp);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label(temp),
        style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}

class _HumidityCard extends StatelessWidget {
  const _HumidityCard({required this.hum});
  final double hum;

  Color get _color {
    if (hum < 30) return Colors.orange;
    if (hum > 70) return Colors.blue;
    return Colors.teal;
  }

  String get _label {
    if (hum < 30) return 'Quá khô';
    if (hum < 40) return 'Khô';
    if (hum <= 60) return 'Thoải mái';
    if (hum <= 70) return 'Ẩm';
    return 'Quá ẩm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_outlined, color: _color, size: 20),
              const SizedBox(width: 8),
              Text('Độ ẩm', style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Text(
                '${hum.toStringAsFixed(0)}%  $_label',
                style: TextStyle(
                    color: _color, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: hum / 100,
            backgroundColor: Colors.grey.shade200,
            color: _color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
