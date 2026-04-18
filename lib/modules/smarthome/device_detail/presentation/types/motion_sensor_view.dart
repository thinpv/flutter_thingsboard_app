import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: pir (0/1), lux, bat/pin, sensi (sensitivity 0-100)
class MotionSensorView extends StatelessWidget {
  const MotionSensorView({required this.telemetry, super.key});
  final Map<String, dynamic> telemetry;

  bool get _detected => isOn(telemetry['pir']);

  @override
  Widget build(BuildContext context) {
    final detected = _detected;
    final lux = numVal(telemetry['lux']);
    final distance = numVal(telemetry['distance']);

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
                    color: MpColors.amberSoft,
                  ),
                ),
              // Inner circle
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: detected ? MpColors.amberSoft : MpColors.surfaceAlt,
                  border: Border.all(
                    color: detected ? MpColors.amber : MpColors.border,
                    width: 2,
                  ),
                ),
                child: Icon(
                  detected
                      ? Icons.directions_walk
                      : Icons.motion_photos_off_outlined,
                  size: 60,
                  color: detected ? MpColors.amber : MpColors.text3,
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
              style: TextStyle(
                    fontSize: 18,
                    color: detected ? MpColors.amber : MpColors.text3,
                    fontWeight: FontWeight.w600,
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
                iconColor: MpColors.amber,
              ),
            if (distance != null)
              InfoCard(
                icon: Icons.social_distance,
                label: 'Khoảng cách',
                value: '${(distance / 100).toStringAsFixed(1)} m',
                iconColor: MpColors.text2,
              ),
            if (batLevel(telemetry) != null)
              InfoCard(
                icon: Icons.battery_std,
                label: 'Pin',
                value: '${batLevel(telemetry)}%',
                iconColor: MpColors.green,
              ),
          ],
        ),
      ],
    );
  }
}
