import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: leak (0/1), bat/pin
class LeakSensorView extends StatelessWidget {
  const LeakSensorView({required this.telemetry, super.key});
  final Map<String, dynamic> telemetry;

  bool get _detected => isOn(telemetry['leak']);

  @override
  Widget build(BuildContext context) {
    final detected = _detected;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 32),
        AlertCircle(
          icon: Icons.water_drop_outlined,
          label: detected ? 'PHÁT HIỆN RÒ NƯỚC!' : 'Không rò nước',
          detected: detected,
          alertColor: Colors.blue,
        ),
        if (detected) ...[
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vui lòng kiểm tra nguồn nước và khóa van nước ngay!',
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
        if (batLevel(telemetry) != null)
          BatteryIndicator(level: batLevel(telemetry)!.toDouble()),
      ],
    );
  }
}
