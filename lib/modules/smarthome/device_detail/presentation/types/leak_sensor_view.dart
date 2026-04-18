import 'package:flutter/material.dart';

import 'package:thingsboard_app/config/themes/mp_colors.dart';
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
          alertColor: MpColors.blue,
        ),
        if (detected) ...[
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MpColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MpColors.blue.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: MpColors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vui lòng kiểm tra nguồn nước và khóa van nước ngay!',
                    style: TextStyle(color: MpColors.blue, fontWeight: FontWeight.w500),
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
