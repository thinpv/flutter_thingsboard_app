import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: smoke (0/1), bat/pin
class SmokeSensorView extends StatelessWidget {
  const SmokeSensorView({required this.telemetry, super.key});
  final Map<String, dynamic> telemetry;

  bool get _detected => isOn(telemetry['smoke']);

  @override
  Widget build(BuildContext context) {
    final detected = _detected;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 32),
        AlertCircle(
          icon: Icons.local_fire_department_outlined,
          label: detected ? 'PHÁT HIỆN KHÓI!' : 'Bình thường',
          detected: detected,
          alertColor: Colors.red,
        ),
        if (detected) ...[
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vui lòng thoát khỏi khu vực và gọi cứu hỏa ngay lập tức!',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
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
