import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: onoff0|onoff|rl (toggle), power (W), energy (kWh), volt (V), curr (A)
class SmartPlugControl extends StatelessWidget {
  const SmartPlugControl({required this.telemetry, required this.onRpc, super.key});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  bool get _isOn =>
      isOn(telemetry['onoff0'] ?? telemetry['onoff'] ?? telemetry['rl0'] ?? telemetry['rl']);

  @override
  Widget build(BuildContext context) {
    final power = (telemetry['power'] as num?)?.toDouble() ?? 0;
    final hasEnergy = telemetry['energy'] != null || telemetry['volt'] != null || telemetry['curr'] != null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 24),
        Center(
          child: PowerButton(
            isOn: _isOn,
            icon: Icons.power_settings_new,
            onTap: () => onRpc('toggle', {}),
            size: 120,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _isOn ? 'Đang bật' : 'Đã tắt',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _isOn ? null : Colors.grey,
                ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Real-time power bar ──
        if (telemetry['power'] != null) ...[
          Row(
            children: [
              const Icon(Icons.bolt, size: 18, color: Colors.orange),
              const SizedBox(width: 6),
              Text('Công suất hiện tại',
                  style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Text(
                '${power.toStringAsFixed(1)} W',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.orange,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (power / 3000).clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            color: power > 2400 ? Colors.red : power > 1500 ? Colors.orange : Colors.green,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 24),
        ],

        // ── Metrics grid ──
        if (hasEnergy)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              if (telemetry['energy'] != null)
                InfoCard(
                  icon: Icons.electric_meter,
                  label: 'Điện năng',
                  value: '${telemetry['energy']} kWh',
                  iconColor: Colors.green,
                  color: Colors.green.shade50,
                ),
              if (telemetry['volt'] != null)
                InfoCard(
                  icon: Icons.electrical_services,
                  label: 'Điện áp',
                  value: '${telemetry['volt']} V',
                  iconColor: Colors.blue,
                  color: Colors.blue.shade50,
                ),
              if (telemetry['curr'] != null)
                InfoCard(
                  icon: Icons.speed,
                  label: 'Dòng điện',
                  value: '${telemetry['curr']} A',
                  iconColor: Colors.purple,
                  color: Colors.purple.shade50,
                ),
            ],
          ),
      ],
    );
  }
}
