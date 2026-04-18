import 'package:flutter/material.dart';

import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: lock (LOCK/UNLOCK or true/false), action, bat/pin
class LockView extends StatelessWidget {
  const LockView({required this.telemetry, required this.onRpc, super.key});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String method, Map<String, dynamic> params) onRpc;

  bool get _isLocked {
    final v = telemetry['lock'];
    if (v == null) return true;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    return s == 'lock' || s == 'locked' || s == '1' || s == 'true';
  }

  @override
  Widget build(BuildContext context) {
    final locked = _isLocked;
    final color = locked ? MpColors.violet : MpColors.green;
    final action = telemetry['action']?.toString();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 32),

        // ── Lock status visual ──
        Center(
          child: GestureDetector(
            onTap: () => onRpc('toggle', {}),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.1),
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 72,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              locked ? 'Đã khóa' : 'Đã mở khóa',
              key: ValueKey(locked),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Center(
          child: Text(
            'Nhấn để ${locked ? "mở khóa" : "khóa"}',
            style: const TextStyle(color: MpColors.text3, fontSize: 13),
          ),
        ),
        const SizedBox(height: 32),

        // ── Action log ──
        if (action != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MpColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MpColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, color: MpColors.text3, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Hoạt động gần nhất: $action',
                  style: const TextStyle(color: MpColors.text2, fontSize: 13),
                ),
              ],
            ),
          ),
        ],

        // ── Action buttons ──
        Row(
          children: [
            Expanded(
              child: _LockActionButton(
                icon: Icons.lock_rounded,
                label: 'Khóa',
                color: MpColors.violet,
                active: locked,
                onTap: () => onRpc('setValue', {'lock': 'LOCK'}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LockActionButton(
                icon: Icons.lock_open_rounded,
                label: 'Mở khóa',
                color: MpColors.green,
                active: !locked,
                onTap: () => onRpc('setValue', {'lock': 'UNLOCK'}),
              ),
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

class _LockActionButton extends StatelessWidget {
  const _LockActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? color : MpColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? Colors.white : MpColors.text3, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : MpColors.text3,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
