import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/add_ir_rf_device_page.dart';

// Keys: cpu, mem, uptime, dev_cnt
// RPC: reboot, startScan, stopScan, irMonitor (two-way)
class GatewayView extends StatelessWidget {
  const GatewayView({
    required this.telemetry,
    required this.onRpc,
    this.onTwoWayRpc,
    this.gatewayId,
    this.meta,
    super.key,
  });
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String method, Map<String, dynamic> params) onRpc;
  /// Two-way RPC — dùng cho các lệnh cần response (irMonitor, ...).
  final Future<dynamic> Function(
    String method,
    Map<String, dynamic> params, {
    int? timeout,
  })? onTwoWayRpc;
  final String? gatewayId;
  final ProfileMetadata? meta;

  List<String> get _capabilities => meta?.uiHints?.capabilities ?? const [];
  bool get _supportsIr => _capabilities.contains('ir');
  bool get _supportsRf => _capabilities.contains('rf');

  @override
  Widget build(BuildContext context) {
    final cpu = doubleVal(telemetry['cpu']);
    final mem = doubleVal(telemetry['mem']);
    final uptime = intVal(telemetry['uptime']);
    final devCnt = intVal(telemetry['devCnt']);

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
                onTap: () => onRpc('startScan', {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GatewayAction(
                icon: Icons.bluetooth_disabled,
                label: 'Dừng ghép',
                color: Colors.grey,
                onTap: () => onRpc('stopScan', {}),
              ),
            ),
          ],
        ),

        // ── IR / RF buttons (chỉ hiện khi gateway profile khai báo capabilities) ──
        if (_supportsIr || _supportsRf) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (_supportsIr)
                Expanded(
                  child: _GatewayAction(
                    icon: Icons.settings_remote,
                    label: 'Thêm thiết bị IR',
                    color: Colors.deepPurple,
                    onTap: () => _openAddIrRf(context, 'ir'),
                  ),
                ),
              if (_supportsIr && _supportsRf) const SizedBox(width: 10),
              if (_supportsRf)
                Expanded(
                  child: _GatewayAction(
                    icon: Icons.sensors,
                    label: 'Thêm thiết bị RF',
                    color: Colors.indigo,
                    onTap: () => _openAddIrRf(context, 'rf'),
                  ),
                ),
            ],
          ),
          // Nút kiểm tra tín hiệu IR (debug: so sánh TX vs remote thật)
          if (_supportsIr) ...[
            const SizedBox(height: 10),
            _GatewayAction(
              icon: Icons.radar,
              label: 'Kiểm tra tín hiệu IR',
              color: Colors.deepOrange,
              onTap: () => _showIrMonitorDialog(context),
              fullWidth: true,
            ),
          ],
        ],

        const SizedBox(height: 10),
        _GatewayAction(
          icon: Icons.sync,
          label: 'Cập nhật Descriptor thiết bị',
          color: Colors.teal,
          onTap: () => _confirmRefreshDescriptor(context),
          fullWidth: true,
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

  void _showIrMonitorDialog(BuildContext context) {
    final rpc = onTwoWayRpc;
    if (rpc == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IrMonitorDialog(onTwoWayRpc: rpc),
    );
  }

  void _openAddIrRf(BuildContext context, String protocol) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddIrRfDevicePage(
          initialGatewayId: gatewayId,
          initialProtocol: protocol,
        ),
      ),
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

  void _confirmRefreshDescriptor(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cập nhật Descriptor?'),
        content: const Text(
          'Gateway sẽ xoá cache descriptor cũ và tải lại từ ThingsBoard. '
          'Các thiết bị đang online sẽ tự động cập nhật mà không bị ngắt kết nối.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              Navigator.pop(ctx);
              onRpc('refreshDescriptor', {'descId': '*'});
            },
            child: const Text('Cập nhật', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

// ─────────────────────────────────────────────────────────────────────────────
// IR Monitor Dialog
// Gọi RPC irMonitor trên gateway — lắng nghe N giây, log từng frame IR nhận.
// Dùng để so sánh tín hiệu gateway TX vs điều khiển thật (xem log serial IrEsp32).
// ─────────────────────────────────────────────────────────────────────────────

enum _MonitorState { idle, running, done, error }

class _IrMonitorDialog extends StatefulWidget {
  const _IrMonitorDialog({required this.onTwoWayRpc});
  final Future<dynamic> Function(
    String method,
    Map<String, dynamic> params, {
    int? timeout,
  }) onTwoWayRpc;

  @override
  State<_IrMonitorDialog> createState() => _IrMonitorDialogState();
}

class _IrMonitorDialogState extends State<_IrMonitorDialog> {
  _MonitorState _state = _MonitorState.idle;
  int _selectedDuration = 10;
  int _frames = 0;
  String _errorMsg = '';

  Future<void> _startMonitor() async {
    setState(() => _state = _MonitorState.running);
    try {
      final timeoutMs = (_selectedDuration + 5) * 1000;
      final raw = await widget.onTwoWayRpc(
        'irMonitor',
        {'duration': _selectedDuration},
        timeout: timeoutMs,
      );
      final resp = raw as Map<String, dynamic>?;
      final code = resp?['code'] as int? ?? -1;
      if (code == 0) {
        setState(() {
          _state = _MonitorState.done;
          _frames = resp?['frames'] as int? ?? 0;
        });
      } else {
        setState(() {
          _state = _MonitorState.error;
          _errorMsg =
              resp?['message'] as String? ?? 'Lỗi không xác định';
        });
      }
    } catch (e) {
      setState(() {
        _state = _MonitorState.error;
        _errorMsg = e.toString();
      });
    }
  }

  void _reset() => setState(() {
        _state = _MonitorState.idle;
        _frames = 0;
        _errorMsg = '';
      });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radar, color: Colors.deepOrange, size: 20),
          SizedBox(width: 8),
          Text('Kiểm tra tín hiệu IR'),
        ],
      ),
      content: _buildContent(),
      actions: _buildActions(context),
    );
  }

  Widget _buildContent() {
    return switch (_state) {
      _MonitorState.idle => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gateway lắng nghe tín hiệu IR và in ra log serial.\n'
              'Bấm nút điều khiển thật trong thời gian này để so sánh '
              'proto/code/raw với lệnh gateway phát.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thời gian lắng nghe:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [10, 15, 30]
                  .map(
                    (d) => ChoiceChip(
                      label: Text('${d}s'),
                      selected: _selectedDuration == d,
                      selectedColor: Colors.deepOrange.withValues(alpha: 0.15),
                      onSelected: (_) =>
                          setState(() => _selectedDuration = d),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      _MonitorState.running => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.deepOrange),
            const SizedBox(height: 16),
            Text(
              'Đang lắng nghe $_selectedDuration giây...\n'
              'Bấm nút điều khiển thật ngay bây giờ.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      _MonitorState.done => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 48),
            const SizedBox(height: 12),
            Text(
              'Nhận được $_frames frame${_frames != 1 ? 's' : ''}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'Xem log serial tag "IrEsp32":\n'
              '"IR TX" = gateway phát\n"IR RX" = remote thật',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      _MonitorState.error => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
    };
  }

  List<Widget> _buildActions(BuildContext context) {
    return switch (_state) {
      _MonitorState.idle => [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: _startMonitor,
            child: const Text(
              'Bắt đầu',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      _MonitorState.running => const [],
      _MonitorState.done || _MonitorState.error => [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: _reset,
            child: const Text(
              'Thử lại',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
    };
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
