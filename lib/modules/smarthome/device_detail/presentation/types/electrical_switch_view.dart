import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

/// Energy-metering wall switch — same gang detection as [SwitchControl] but
/// adds live power monitoring (W/V/A/kWh). Suits products that report relay
/// state plus electrical readings (e.g. Aqara T1, Lumi ctrl_ln1/2).
class ElectricalSwitchView extends StatelessWidget {
  const ElectricalSwitchView({
    required this.telemetry,
    required this.onRpc,
    super.key,
  });
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gangs = detectSwitchGangs(telemetry);
    final anyOn = gangs.any((g) => isOn(telemetry[g.key]));
    final allOn = gangs.every((g) => isOn(telemetry[g.key]));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const SizedBox(height: 8),

        // ── Master toggle ──
        Center(
          child: PowerButton(
            isOn: anyOn,
            icon: Icons.power_settings_new,
            size: 88,
            onTap: () {
              final target = allOn ? 0 : 1;
              onRpc('setValue', {for (final g in gangs) g.key: target});
            },
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            allOn
                ? 'Tất cả bật'
                : anyOn
                    ? 'Một số đang bật'
                    : 'Tất cả tắt',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: anyOn ? cs.primary : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Wall plate ──
        WallPlateView(
          buttons: [
            for (final g in gangs)
              WallPlateButton(
                label: g.label,
                isOn: isOn(telemetry[g.key]),
                onTap: () => onRpc(
                    'setValue', {g.key: isOn(telemetry[g.key]) ? 0 : 1}),
              ),
          ],
        ),

        // ── Energy monitoring ──
        if (telemetry['power'] != null || telemetry['volt'] != null) ...[
          const SizedBox(height: 24),
          Text('Đo lường điện', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          if (telemetry['power'] != null) ...[
            _PowerBar(power: doubleVal(telemetry['power']) ?? 0),
            const SizedBox(height: 16),
          ],
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
      ],
    );
  }
}

class _PowerBar extends StatelessWidget {
  const _PowerBar({required this.power});
  final double power;

  @override
  Widget build(BuildContext context) {
    final color = power > 2400
        ? Colors.red
        : power > 1500
            ? Colors.orange
            : Colors.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt, size: 16, color: color),
            const SizedBox(width: 6),
            Text('Công suất', style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(
              '${power.toStringAsFixed(1)} W',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (power / 3000).clamp(0.0, 1.0),
          backgroundColor: Colors.grey.shade200,
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
