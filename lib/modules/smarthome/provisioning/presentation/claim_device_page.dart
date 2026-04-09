import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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

      // Assign device to current home asset
      final home = ref.read(selectedHomeProvider).valueOrNull;
      if (home != null) {
        await _svc.assignToHome(deviceId, home.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm "$name" vào nhà${home != null ? ' "${home.name}"' : ''}.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('400')
            ? 'Claiming thất bại. Kiểm tra:\n'
              '• Device name đúng chưa (vd: dev_aabbccddeeff)\n'
              '• Thiết bị đã bật chế độ claiming chưa (giữ nút 3-5s)\n'
              '• Device profile trên TB đã bật "Allow claiming" chưa'
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm thiết bị trực tiếp'),
        bottom: TabBar(
          controller: _tabController,
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
            style: TextStyle(color: Colors.grey),
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
          const Text(
            'Nhập tên thiết bị và mã claiming.\n'
            'Mã claiming hiển thị khi thiết bị ở chế độ claiming (3-5s giữ nút).',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Tên thiết bị (Device Name)',
              hintText: 'dev_aabbccddeeff',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: keyCtrl,
            decoration: const InputDecoration(
              labelText: 'Mã claiming (Secret Key)',
              hintText: 'A3F9K2',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.check),
            label: const Text('Xác nhận claiming'),
          ),
        ],
      ),
    );
  }
}
