import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: cpu, mem, uptime, dev_cnt
// RPC: reboot, start_pairing, stop_pairing
class GatewayView extends StatelessWidget {
  const GatewayView({required this.telemetry, required this.onRpc, super.key});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String method, Map<String, dynamic> params) onRpc;

  @override
  Widget build(BuildContext context) {
    final cpu = (telemetry['cpu'] as num?)?.toDouble();
    final mem = (telemetry['mem'] as num?)?.toDouble();
    final uptime = (telemetry['uptime'] as num?)?.toInt();
    final devCnt = (telemetry['dev_cnt'] as num?)?.toInt();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 8),

        // ── Status header ──
        _GatewayStatusCard(
          cpu: cpu,
          mem: mem,
          uptime: uptime,
          devCnt: devCnt,
        ),
        const SizedBox(height: 20),

        // ── Resource meters ──
        if (cpu != null) ...[
          _ResourceMeter(
            icon: Icons.memory,
            label: 'CPU',
            value: cpu,
            color: _cpuColor(cpu),
          ),
          const SizedBox(height: 12),
        ],
        if (mem != null) ...[
          _ResourceMeter(
            icon: Icons.storage,
            label: 'RAM',
            value: mem,
            color: _memColor(mem),
          ),
          const SizedBox(height: 20),
        ],

        // ── Actions ──
        Text(
          'Thao tác',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _GatewayAction(
                icon: Icons.bluetooth_searching,
                label: 'Ghép thiết bị',
                color: Colors.blue,
                onTap: () => onRpc('start_pairing', {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GatewayAction(
                icon: Icons.bluetooth_disabled,
                label: 'Dừng ghép',
                color: Colors.grey,
                onTap: () => onRpc('stop_pairing', {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        _GatewayAction(
          icon: Icons.restart_alt,
          label: 'Khởi động lại Gateway',
          color: Colors.orange,
          onTap: () => _confirmReboot(context),
          fullWidth: true,
        ),
      ],
    );
  }

  Color _cpuColor(double v) {
    if (v < 50) return Colors.green;
    if (v < 80) return Colors.orange;
    return Colors.red;
  }

  Color _memColor(double v) {
    if (v < 60) return Colors.green;
    if (v < 85) return Colors.orange;
    return Colors.red;
  }

  void _confirmReboot(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Khởi động lại?'),
        content: const Text(
          'Gateway sẽ khởi động lại. Trong thời gian này, các thiết bị kết nối qua gateway sẽ bị offline tạm thời.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(ctx);
              onRpc('reboot', {});
            },
            child: const Text('Khởi động lại', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _GatewayStatusCard extends StatelessWidget {
  const _GatewayStatusCard({this.cpu, this.mem, this.uptime, this.devCnt});
  final double? cpu;
  final double? mem;
  final int? uptime;
  final int? devCnt;

  String _formatUptime(int seconds) {
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (d > 0) return '${d}d ${h}h ${m}m';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${seconds % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.router, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text(
                'Gateway',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              const OnlineBadge(isOnline: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (devCnt != null)
                _StatChip(
                  icon: Icons.devices,
                  value: '$devCnt thiết bị',
                ),
              if (devCnt != null && uptime != null)
                const SizedBox(width: 10),
              if (uptime != null)
                _StatChip(
                  icon: Icons.timer_outlined,
                  value: _formatUptime(uptime!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceMeter extends StatelessWidget {
  const _ResourceMeter({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: Colors.grey.shade200,
              color: color,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _GatewayAction extends StatelessWidget {
  const _GatewayAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment:
              fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
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
