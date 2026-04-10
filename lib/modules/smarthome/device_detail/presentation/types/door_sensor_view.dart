import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: door (true/1=closed), bat/pin
class DoorSensorView extends StatelessWidget {
  const DoorSensorView({required this.telemetry, super.key});
  final Map<String, dynamic> telemetry;

  bool get _isClosed => isOn(telemetry['door']);

  @override
  Widget build(BuildContext context) {
    final closed = _isClosed;
    final color = closed ? Colors.green : Colors.orange;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 32),

        // ── Status icon ──
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color, width: 3),
            ),
            child: Icon(
              closed ? Icons.sensor_door : Icons.sensor_door_outlined,
              size: 64,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            closed ? 'Cửa đóng' : 'Cửa mở',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              closed ? 'Không phát hiện xâm nhập' : 'Chú ý: cửa đang mở',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),

        if (batLevel(telemetry) != null)
          BatteryIndicator(level: batLevel(telemetry)!.toDouble()),
      ],
    );
  }
}
