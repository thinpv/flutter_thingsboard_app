import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: pir (0/1), lux, bat/pin, sensi (sensitivity 0-100)
class MotionSensorView extends StatelessWidget {
  const MotionSensorView({required this.telemetry, super.key});
  final Map<String, dynamic> telemetry;

  bool get _detected => isOn(telemetry['pir']);

  @override
  Widget build(BuildContext context) {
    final detected = _detected;
    final lux = telemetry['lux'] as num?;
    final distance = telemetry['distance'] as num?;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 32),

        // ── Motion ring animation ──
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              if (detected)
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withValues(alpha: 0.07),
                  ),
                ),
              // Inner circle
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: detected
                      ? Colors.orange.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.08),
                  border: Border.all(
                    color: detected ? Colors.orange : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Icon(
                  detected ? Icons.directions_walk : Icons.motion_photos_off_outlined,
                  size: 60,
                  color: detected ? Colors.orange : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              detected ? 'Phát hiện chuyển động!' : 'Không có chuyển động',
              key: ValueKey(detected),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: detected ? Colors.orange.shade800 : Colors.grey,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Sensor metrics ──
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            if (lux != null)
              InfoCard(
                icon: Icons.light_mode_outlined,
                label: 'Ánh sáng',
                value: '${lux.toStringAsFixed(0)} lux',
                iconColor: Colors.amber,
                color: Colors.amber.shade50,
              ),
            if (distance != null)
              InfoCard(
                icon: Icons.social_distance,
                label: 'Khoảng cách',
                value: '${(distance / 100).toStringAsFixed(1)} m',
                iconColor: Colors.teal,
                color: Colors.teal.shade50,
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
}
