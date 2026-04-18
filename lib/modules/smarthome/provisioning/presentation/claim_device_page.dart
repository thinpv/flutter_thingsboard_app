import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/provisioning_service.dart';

/// Page for claiming a direct device (non-sub-device) via:
///  - QR code scan  (smarthome://claim?d={name}&k={key})
///  - Manual entry  (device name + secret key)
class ClaimDevicePage extends ConsumerStatefulWidget {
  const ClaimDevicePage({super.key});

  @override
  ConsumerState<ClaimDevicePage> createState() => _ClaimDevicePageState();
}

class _ClaimDevicePageState extends ConsumerState<ClaimDevicePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _svc = ProvisioningService();
  bool _claiming = false;

  // Manual entry controllers
  final _nameCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _doClaim(String deviceName, String secretKey) async {
    if (_claiming) return;
    final name = deviceName.trim();
    final key = secretKey.trim();
    if (name.isEmpty || key.isEmpty) return;

    setState(() => _claiming = true);
    try {
      final deviceId = await _svc.claimDevice(name, key);
      final home = ref.read(selectedHomeProvider).valueOrNull;
      if (home == null) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      // For gateways: check if already in another home and offer to transfer.
      final isGw = await _svc.checkIsGateway(deviceId);
      if (isGw) {
        final homes = await ref.read(homesProvider.future);
        final currentHome = await _svc.findCurrentHome(deviceId, homes);

        if (currentHome != null && currentHome.id != home.id) {
          if (!mounted) return;
          final transfer = await _showTransferDialog(currentHome, home);
          if (!mounted) return;
          if (transfer == true) {
            await _svc.transferGatewayToHome(deviceId, home.id);
            _invalidateDeviceProviders();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Đã chuyển gateway và thiết bị sang "${home.name}".',
                  ),
                ),
              );
              Navigator.of(context).pop(true);
            }
            return;
          }
          // User cancelled transfer — still assigned to old home, nothing to do.
          if (mounted) Navigator.of(context).pop(false);
          return;
        }
      }

      // Normal case: assign to current home.
      await _svc.assignToHome(deviceId, home.id);
      _invalidateDeviceProviders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm "$name" vào nhà "${home.name}".')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('FAILURE') || e.toString().contains('400')
            ? 'Claiming thất bại. Kiểm tra:\n'
              '• Device name đúng chưa (vd: dev_aabbccddeeff)\n'
              '• Thiết bị đã bật chế độ claiming chưa (giữ nút 3-5s)\n'
              '• Device profile trên TB đã bật "Allow claiming" chưa\n'
              '• Thiết bị có thể đang thuộc nhà của người dùng khác'
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: MpColors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  /// Shows a dialog asking the user whether to transfer the gateway from
  /// [fromHome] to [toHome]. Returns true if confirmed, false/null otherwise.
  Future<bool?> _showTransferDialog(
    SmarthomeHome fromHome,
    SmarthomeHome toHome,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: MpColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Gateway đang ở nhà khác',
          style: TextStyle(color: MpColors.text, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Gateway này đang thuộc nhà "${fromHome.name}".\n\n'
          'Chuyển gateway và toàn bộ thiết bị sang nhà "${toHome.name}" không?\n\n'
          'Các thiết bị sẽ được đặt ở mức nhà, bạn có thể gán phòng sau.',
          style: const TextStyle(color: MpColors.text2, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: MpColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Chuyển',
                style: TextStyle(
                    color: MpColors.blue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _invalidateDeviceProviders() {
    ref.invalidate(homesProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Thêm thiết bị trực tiếp',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: MpColors.text,
          ),
        ),
        iconTheme: const IconThemeData(color: MpColors.text),
        bottom: TabBar(
          controller: _tabController,
          labelColor: MpColors.text,
          unselectedLabelColor: MpColors.text3,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: MpColors.text,
          indicatorWeight: 2,
          dividerColor: MpColors.border,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Quét QR'),
            Tab(icon: Icon(Icons.keyboard), text: 'Nhập mã'),
          ],
        ),
      ),
      body: _claiming
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _QrScanTab(onScanned: _doClaim),
                _ManualEntryTab(
                  nameCtrl: _nameCtrl,
                  keyCtrl: _keyCtrl,
                  onSubmit: () => _doClaim(_nameCtrl.text, _keyCtrl.text),
                ),
              ],
            ),
    );
  }
}

// ─── QR scan tab ──────────────────────────────────────────────────────────────

class _QrScanTab extends StatefulWidget {
  const _QrScanTab({required this.onScanned});

  final void Function(String deviceName, String secretKey) onScanned;

  @override
  State<_QrScanTab> createState() => _QrScanTabState();
}

class _QrScanTabState extends State<_QrScanTab> {
  bool _scanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    // Expected format: smarthome://claim?d={deviceName}&k={secretKey}
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'smarthome' ||
        uri.host != 'claim') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR không hợp lệ')),
      );
      return;
    }
    final deviceName = uri.queryParameters['d'];
    final secretKey = uri.queryParameters['k'];
    if (deviceName == null || secretKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR thiếu thông tin')),
      );
      return;
    }

    _scanned = true;
    widget.onScanned(deviceName, secretKey);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Nhấn giữ nút thiết bị 3-5 giây để bật chế độ claiming,\n'
            'rồi quét mã QR hiển thị trên thiết bị hoặc app cấu hình.',
            textAlign: TextAlign.center,
            style: TextStyle(color: MpColors.text3, fontSize: 13),
          ),
        ),
        Expanded(
          child: MobileScanner(onDetect: _onDetect),
        ),
      ],
    );
  }
}

// ─── Manual entry tab ─────────────────────────────────────────────────────────

class _ManualEntryTab extends StatelessWidget {
  const _ManualEntryTab({
    required this.nameCtrl,
    required this.keyCtrl,
    required this.onSubmit,
  });

  final TextEditingController nameCtrl;
  final TextEditingController keyCtrl;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MpColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Nhập tên thiết bị và mã claiming.\n'
              'Mã claiming hiển thị khi thiết bị ở chế độ claiming (3-5s giữ nút).',
              style: TextStyle(color: MpColors.text2, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          _MpTextField(
            controller: nameCtrl,
            label: 'Tên thiết bị (Device Name)',
            hint: 'dev_aabbccddeeff',
          ),
          const SizedBox(height: 12),
          _MpTextField(
            controller: keyCtrl,
            label: 'Mã claiming (Secret Key)',
            hint: 'A3F9K2',
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onSubmit,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: MpColors.text,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, color: MpColors.bg, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Xác nhận claiming',
                    style: TextStyle(
                      color: MpColors.bg,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MpTextField extends StatelessWidget {
  const _MpTextField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: MpColors.text2,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: MpColors.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: MpColors.text3),
            filled: true,
            fillColor: MpColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: MpColors.border, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: MpColors.border, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: MpColors.blue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
