import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys (Tuya 4-gang): bt, bt2, bt3, bt4 — all on/off
// Keys (BLE switch): rl, rl0, rl1, rl2, rl3
// Keys (Zigbee switch): onoff0, onoff1, onoff2, onoff3
class SwitchControl extends StatelessWidget {
  const SwitchControl({required this.telemetry, required this.onRpc, super.key});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  // Detect and normalise gang keys regardless of protocol
  List<({String key, String label})> get _gangs {
    // Tuya TS0601: bt, bt2, bt3, bt4
    if (telemetry.containsKey('bt')) {
      final keys = ['bt'];
      for (int i = 2; telemetry.containsKey('bt$i'); i++) keys.add('bt$i');
      return keys
          .asMap()
          .entries
          .map((e) => (key: e.value, label: 'Công tắc ${e.key + 1}'))
          .toList();
    }
    // BLE relay: rl0, rl1... or rl
    if (telemetry.containsKey('rl0')) {
      final keys = <String>[];
      for (int i = 0; telemetry.containsKey('rl$i'); i++) keys.add('rl$i');
      return keys
          .asMap()
          .entries
          .map((e) => (key: e.value, label: 'Relay ${e.key + 1}'))
          .toList();
    }
    if (telemetry.containsKey('rl')) {
      return [(key: 'rl', label: 'Relay')];
    }
    // Zigbee onoff: onoff0, onoff1...
    if (telemetry.containsKey('onoff0')) {
      final keys = <String>[];
      for (int i = 0; telemetry.containsKey('onoff$i'); i++) {
        keys.add('onoff$i');
      }
      return keys
          .asMap()
          .entries
          .map((e) => (key: e.value, label: 'Công tắc ${e.key + 1}'))
          .toList();
    }
    // Fallback
    return [(key: 'bt', label: 'Công tắc')];
  }

  bool _gangOn(String key) => isOn(telemetry[key]);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gangs = _gangs;
    final allOn = gangs.every((g) => _gangOn(g.key));
    final anyOn = gangs.any((g) => _gangOn(g.key));

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
            activeColor: cs.primary,
            onTap: () {
              final target = allOn ? 0 : 1;
              final data = <String, dynamic>{
                for (final g in gangs) g.key: target,
              };
              onRpc('setValue', data);
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

        // ── Individual gangs ──
        ...gangs.map((g) {
          final on = _gangOn(g.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: on
                  ? cs.primaryContainer.withValues(alpha: 0.5)
                  : cs.surfaceContainerLow,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onRpc('setValue', {g.key: on ? 0 : 1}),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: on
                              ? cs.primary.withValues(alpha: 0.15)
                              : Colors.grey.shade200,
                        ),
                        child: Icon(
                          Icons.lightbulb_outline,
                          color: on ? cs.primary : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              on ? 'Đang bật' : 'Đã tắt',
                              style: TextStyle(
                                fontSize: 13,
                                color: on ? cs.primary : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: on,
                        activeColor: cs.primary,
                        onChanged: (_) => onRpc('setValue', {g.key: on ? 0 : 1}),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        // ── Power info ──
        if (telemetry['power'] != null || telemetry['energy'] != null) ...[
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              if (telemetry['power'] != null)
                InfoCard(
                  icon: Icons.bolt,
                  label: 'Công suất',
                  value: '${telemetry['power']} W',
                  iconColor: Colors.orange,
                  color: Colors.orange.shade50,
                ),
              if (telemetry['energy'] != null)
                InfoCard(
                  icon: Icons.electric_meter,
                  label: 'Điện năng',
                  value: '${telemetry['energy']} kWh',
                  iconColor: Colors.green,
                  color: Colors.green.shade50,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
