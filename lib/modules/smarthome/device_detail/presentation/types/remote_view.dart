import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: bt/bt0..btN (button events), action, bat/pin
class RemoteView extends StatelessWidget {
  const RemoteView({required this.telemetry, super.key});
  final Map<String, dynamic> telemetry;

  List<({int index, String key, dynamic value})> get _buttons {
    final result = <({int index, String key, dynamic value})>[];
    // Single button remote: bt
    if (telemetry.containsKey('bt')) {
      result.add((index: 0, key: 'bt', value: telemetry['bt']));
    }
    // Multi-button: bt0, bt1, bt2... or bt2, bt3, bt4 (Tuya 3/4-gang)
    for (int i = 0; i <= 9; i++) {
      final key = i == 0 ? 'bt0' : 'bt$i';
      if (telemetry.containsKey(key)) {
        result.add((index: i, key: key, value: telemetry[key]));
      }
    }
    if (result.isEmpty) {
      // show placeholder buttons
      for (int i = 1; i <= 4; i++) {
        result.add((index: i, key: 'bt$i', value: null));
      }
    }
    return result;
  }

  String _eventLabel(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    switch (s) {
      case '1':
      case 'single':
        return 'Nhấn 1 lần';
      case '2':
      case 'double':
        return 'Nhấn 2 lần';
      case '3':
      case 'triple':
        return 'Nhấn 3 lần';
      case 'hold':
        return 'Giữ';
      case 'release':
        return 'Thả';
      case '0':
        return '—';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttons = _buttons;
    final action = telemetry['action']?.toString();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 16),

        // ── Remote illustration ──
        Center(
          child: Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade700,
                  ),
                  child: const Icon(Icons.sensors, color: Colors.white54, size: 18),
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  (buttons.length).clamp(1, 6),
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Last action ──
        if (action != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app, color: Colors.deepPurple.shade400, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Sự kiện: $action',
                  style: TextStyle(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Button status grid ──
        Text(
          'Nút bấm',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            for (final btn in buttons)
              _ButtonCard(
                index: btn.index,
                label: 'Nút ${btn.index + 1}',
                event: _eventLabel(btn.value),
                active: btn.value != null && btn.value.toString() != '0',
              ),
          ],
        ),
        const SizedBox(height: 24),

        if (batLevel(telemetry) != null)
          BatteryIndicator(level: batLevel(telemetry)!.toDouble()),
      ],
    );
  }
}

class _ButtonCard extends StatelessWidget {
  const _ButtonCard({
    required this.index,
    required this.label,
    required this.event,
    required this.active,
  });
  final int index;
  final String label;
  final String event;
  final bool active;

  static const _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.red,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.4) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                Icons.radio_button_checked,
                size: 16,
                color: active ? color : Colors.grey.shade400,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? color : Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            event,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
