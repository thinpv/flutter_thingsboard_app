import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class DeviceInfoPage extends ConsumerStatefulWidget {
  const DeviceInfoPage({required this.device, super.key});

  final SmarthomeDevice device;

  @override
  ConsumerState<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends ConsumerState<DeviceInfoPage> {
  late String _displayName;
  String? _macAddress;
  String? _protocol;
  int? _createdTime;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _displayName = widget.device.displayName;
    _loadDeviceDetails();
  }

  Future<void> _loadDeviceDetails() async {
    try {
      final client = getIt<ITbClientService>().client;
      final device = await client.getDeviceService().getDevice(widget.device.id);
      if (device != null && mounted) {
        setState(() {
          _createdTime = device.createdTime;
          _protocol = device.type;
        });
      }

      final entityId = DeviceId(widget.device.id);
      final attrs = await client.getAttributeService().getAttributesByScope(
        entityId,
        'SERVER_SCOPE',
        ['mac', 'protocol', 'macAddress'],
      );
      if (mounted) {
        setState(() {
          for (final a in attrs) {
            final k = a.getKey();
            final v = '${a.getValue()}';
            if (k == 'mac' || k == 'macAddress') _macAddress = v;
            if (k == 'protocol') _protocol = v;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _renameDevice() async {
    final controller = TextEditingController(text: _displayName);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MpColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đổi tên thiết bị',
            style: TextStyle(color: MpColors.text, fontWeight: FontWeight.w500)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: MpColors.text),
          decoration: InputDecoration(
            hintText: 'Nhập tên mới…',
            hintStyle: const TextStyle(color: MpColors.text3),
            filled: true,
            fillColor: MpColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: MpColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Lưu',
                style: TextStyle(color: MpColors.blue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (newLabel == null || newLabel.isEmpty || newLabel == _displayName) return;
    try {
      final client = getIt<ITbClientService>().client;
      final device = await client.getDeviceService().getDevice(widget.device.id);
      if (device == null) throw Exception('Không tìm thấy thiết bị');
      device.label = newLabel;
      await client.getDeviceService().saveDevice(device);
      if (mounted) {
        setState(() => _displayName = newLabel);
        ref.invalidate(devicesInRoomProvider);
        ref.invalidate(devicesInHomeProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _deleteDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MpColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa thiết bị',
            style: TextStyle(color: MpColors.text, fontWeight: FontWeight.w500)),
        content: Text(
          'Xóa vĩnh viễn "${_displayName}" khỏi hệ thống?',
          style: const TextStyle(color: MpColors.text2, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: MpColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa',
                style: TextStyle(color: MpColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final svc = HomeService();
      final gatewayId = await svc.findGatewayForDevice(widget.device.id);
      await svc.deleteDevice(widget.device.id, gatewayId: gatewayId);
      ref.invalidate(devicesInRoomProvider);
      ref.invalidate(devicesInHomeProvider);
      if (mounted) {
        // Pop both DeviceInfoPage và DeviceDetailPage
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa thiết bị: $e')),
        );
      }
    }
  }

  String _formatDate(int? ms) {
    if (ms == null) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = MpColors.deviceColors(widget.device.effectiveUiType, true);

    return Scaffold(
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: MpColors.text),
        centerTitle: true,
        title: const Text(
          'Thông tin thiết bị',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: MpColors.text,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ── Identity card ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: colors.tint,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          _iconForType(widget.device.effectiveUiType),
                          size: 28,
                          color: colors.fg,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: MpColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.device.type,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MpColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Quản lý ───────────────────────────────────────────────
                _SectionLabel('QUẢN LÝ'),
                const SizedBox(height: 6),
                _InfoCard(children: [
                  _InfoRow(
                    label: 'Đổi tên',
                    value: _displayName,
                    onTap: _renameDevice,
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Thông tin kỹ thuật ────────────────────────────────────
                _SectionLabel('THÔNG TIN KỸ THUẬT'),
                const SizedBox(height: 6),
                _InfoCard(children: [
                  _InfoRow(label: 'Giao thức', value: _protocol ?? widget.device.type),
                  _InfoRow(
                    label: 'Device ID',
                    value: _shortId(widget.device.id),
                    mono: true,
                    onTap: () => _copyToClipboard(widget.device.id),
                  ),
                  if (_macAddress != null)
                    _InfoRow(
                      label: 'MAC',
                      value: _macAddress!,
                      mono: true,
                      onTap: () => _copyToClipboard(_macAddress!),
                    ),
                  _InfoRow(
                    label: 'Ngày thêm',
                    value: _formatDate(_createdTime),
                    last: true,
                  ),
                ]),
                const SizedBox(height: 32),

                // ── Danger zone ───────────────────────────────────────────
                _DangerTile(
                  label: 'Xóa thiết bị',
                  subtitle: 'Xóa vĩnh viễn khỏi hệ thống',
                  onTap: _deleteDevice,
                ),
              ],
            ),
    );
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  String _shortId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}…${id.substring(id.length - 4)}';
  }

  IconData _iconForType(String uiType) => switch (uiType) {
        'light' || 'electricalSwitch' || 'switch' => Icons.light_outlined,
        'airConditioner' || 'irAc' => Icons.ac_unit_outlined,
        'smartPlug' => Icons.electrical_services_outlined,
        'curtain' => Icons.view_agenda_outlined,
        'camera' => Icons.videocam_outlined,
        'doorSensor' => Icons.sensor_door_outlined,
        'motionSensor' => Icons.sensors_outlined,
        'tempHumidity' => Icons.thermostat_outlined,
        'gateway' => Icons.router_outlined,
        'lock' => Icons.lock_outline,
        _ => Icons.devices_outlined,
      };
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: MpColors.text3,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.last = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool mono;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  bottom: BorderSide(color: MpColors.border, width: 0.5),
                ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: MpColors.text2),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: mono ? 11 : 13,
                fontFamily: mono ? 'JetBrainsMono' : null,
                color: MpColors.text3,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.copy_outlined, size: 14, color: MpColors.text3),
            ] else ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 16, color: MpColors.text3),
            ],
          ],
        ),
      ),
    );
  }
}

class _DangerTile extends StatelessWidget {
  const _DangerTile({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: MpColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MpColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MpColors.red,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MpColors.text3,
                      )),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: MpColors.text3),
          ],
        ),
      ),
    );
  }
}
