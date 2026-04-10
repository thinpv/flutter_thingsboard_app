import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: rl/rl0-rl4 (relays), volt, curr, power, energy, modeInput, statusStartup
class ElectricalSwitchView extends StatelessWidget {
  const ElectricalSwitchView({
    required this.telemetry,
    required this.onRpc,
    super.key,
  });
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  List<String> get _relayKeys {
    final keys = <String>[];
    for (int i = 0; i <= 4; i++) {
      if (telemetry.containsKey('rl$i')) keys.add('rl$i');
    }
    if (keys.isEmpty && telemetry.containsKey('rl')) keys.add('rl');
    return keys.isNotEmpty ? keys : ['rl'];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final relays = _relayKeys;
    final anyOn = relays.any((k) => isOn(telemetry[k]));
    final allOn = relays.every((k) => isOn(telemetry[k]));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const SizedBox(height: 12),

        // ── Master toggle ──
        Center(
          child: PowerButton(
            isOn: anyOn,
            icon: Icons.power_settings_new,
            size: 88,
            onTap: () {
              final target = allOn ? 0 : 1;
              onRpc('setValue', {for (final k in relays) k: target});
            },
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            allOn ? 'Tất cả bật' : anyOn ? 'Một số đang bật' : 'Tất cả tắt',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: anyOn ? cs.primary : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        const SizedBox(height: 28),

        // ── Relay rows ──
        Text('Relay', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        ...relays.asMap().entries.map((e) {
          final on = isOn(telemetry[e.value]);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              borderRadius: BorderRadius.circular(14),
              color: on
                  ? cs.primaryContainer.withValues(alpha: 0.5)
                  : cs.surfaceContainerLow,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onRpc('setValue', {e.value: on ? 0 : 1}),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.power_settings_new,
                          size: 26, color: on ? cs.primary : Colors.grey),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          relays.length == 1 ? 'Relay' : 'Relay ${e.key + 1}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Switch(
                        value: on,
                        activeColor: cs.primary,
                        onChanged: (_) => onRpc('setValue', {e.value: on ? 0 : 1}),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        // ── Energy monitoring ──
        const SizedBox(height: 8),
        if (telemetry['power'] != null || telemetry['volt'] != null) ...[
          Text('Đo lường điện', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          // Live power indicator
          if (telemetry['power'] != null) ...[
            _PowerBar(power: (telemetry['power'] as num).toDouble()),
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
                InfoCard(icon: Icons.electric_meter, label: 'Điện năng',
                    value: '${telemetry['energy']} kWh', iconColor: Colors.green, color: Colors.green.shade50),
              if (telemetry['volt'] != null)
                InfoCard(icon: Icons.electrical_services, label: 'Điện áp',
                    value: '${telemetry['volt']} V', iconColor: Colors.blue, color: Colors.blue.shade50),
              if (telemetry['curr'] != null)
                InfoCard(icon: Icons.speed, label: 'Dòng điện',
                    value: '${telemetry['curr']} A', iconColor: Colors.purple, color: Colors.purple.shade50),
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
    final color = power > 2400 ? Colors.red : power > 1500 ? Colors.orange : Colors.green;
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: color),
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
