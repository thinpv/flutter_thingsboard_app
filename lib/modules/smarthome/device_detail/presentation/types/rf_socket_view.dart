import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// RF Socket View — ổ cắm RF (PT2262...) và chuông cửa RF (HT6P20).
//
// rf_socket:   onoff0 (bool virtual) — toggle
// rf_doorbell: button_pressed (event) — read-only, chỉ hiện thời điểm cuối

class RfSocketView extends StatelessWidget {
  const RfSocketView({
    required this.telemetry,
    required this.onRpc,
    super.key,
  });

  final Map<String, dynamic> telemetry;
  final Future<void> Function(String method, Map<String, dynamic> params) onRpc;

  bool get _isOn {
    final v = telemetry['onoff0'];
    return v == 1 || v == true || v == '1';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        // ── Main toggle ──
        Center(
          child: _SocketToggle(
            isOn: _isOn,
            onToggle: () {
              HapticFeedback.mediumImpact();
              onRpc('toggle', {});
            },
          ),
        ),
        const SizedBox(height: 32),

        // ── Status label ──
        Center(
          child: Text(
            _isOn ? 'Đang bật' : 'Đang tắt',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _isOn ? Colors.green.shade600 : Colors.grey.shade500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Ổ cắm RF',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ),
        const SizedBox(height: 40),

        // ── Quick preset ──
        _QuickRow(onRpc: onRpc),
        const SizedBox(height: 24),

        // ── RF note ──
        _RfSocketNote(),
      ],
    );
  }
}

class _SocketToggle extends StatelessWidget {
  const _SocketToggle({required this.isOn, required this.onToggle});
  final bool isOn;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOn
              ? Colors.green.shade400.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.08),
          border: Border.all(
            color: isOn ? Colors.green.shade400 : Colors.grey.shade300,
            width: 3,
          ),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 24,
                  )
                ]
              : null,
        ),
        child: Icon(
          Icons.power,
          size: 52,
          color: isOn ? Colors.green.shade500 : Colors.grey.shade400,
        ),
      ),
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.onRpc});
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickBtn(
          label: 'Bật',
          icon: Icons.power,
          color: Colors.green,
          onTap: () => onRpc('setValue', {'onoff0': 1}),
        ),
        const SizedBox(width: 12),
        _QuickBtn(
          label: 'Tắt',
          icon: Icons.power_off,
          color: Colors.red,
          onTap: () => onRpc('setValue', {'onoff0': 0}),
        ),
      ],
    );
  }
}

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final MaterialColor color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color.shade600, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RfSocketNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade300, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Trạng thái ảo — RF không có phản hồi từ thiết bị',
              style: TextStyle(color: Colors.blue.shade400, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RF Doorbell View — chỉ nhận sự kiện, không gửi lệnh

class RfDoorbellView extends StatelessWidget {
  const RfDoorbellView({required this.telemetry, super.key});

  final Map<String, dynamic> telemetry;

  @override
  Widget build(BuildContext context) {
    final pressed = telemetry['buttonPressed'];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 30),
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pressed != null
                  ? Colors.amber.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.08),
              border: Border.all(
                color: pressed != null ? Colors.amber : Colors.grey.shade300,
                width: 2.5,
              ),
            ),
            child: Icon(
              Icons.doorbell,
              size: 46,
              color: pressed != null ? Colors.amber.shade600 : Colors.grey.shade400,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Chuông cửa RF',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            pressed != null
                ? 'Chuông vừa được nhấn'
                : 'Chưa có sự kiện',
            style: TextStyle(
              color: pressed != null ? Colors.amber.shade700 : Colors.grey.shade400,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '(Read-only — thiết bị RF một chiều)',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
