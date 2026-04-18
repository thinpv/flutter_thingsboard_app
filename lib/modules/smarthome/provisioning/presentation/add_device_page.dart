import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/constants/app_constants.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/claim_device_page.dart';
import 'package:thingsboard_app/utils/services/provisioning/eps_ble/wifi_provisioning_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_profile_ui_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/provisioning_service.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class AddDevicePage extends ConsumerStatefulWidget {
  const AddDevicePage({super.key});

  @override
  ConsumerState<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends ConsumerState<AddDevicePage> {
  final _svc = ProvisioningService();
  final _bleSvc = BleProvisioningService();

  bool _scanning = false;

  // ── Gateway pairing state ──
  List<SmarthomeDevice> _gateways = [];
  final Map<String, Set<String>> _initialIds = {};
  List<SmarthomeDevice> _gwFound = []; // newly discovered during scan
  List<SmarthomeDevice> _unassigned = []; // existing sub-devices not in home
  final Set<String> _assigned = {};
  Timer? _pollTimer;

  // ── BLE scan state ──
  List<String> _bleDevices = [];
  bool _bleScanning = false;
  String? _bleError;

  // ── Display name cache: device id → resolved name ──
  final Map<String, String> _nameCache = {};
  // ── Profile image cache: device id → image URL (null = no image) ──
  final Map<String, String?> _profileImageCache = {};

  String _displayName(SmarthomeDevice dev) {
    return _nameCache[dev.id] ?? dev.displayName;
  }

  String? _profileImage(SmarthomeDevice dev) => _profileImageCache[dev.id];

  Future<void> _resolveProfileImages(List<SmarthomeDevice> devices) async {
    final uiSvc = DeviceProfileUiService();
    for (final dev in devices) {
      if (_profileImageCache.containsKey(dev.id)) continue;
      final meta = await uiSvc.getUiMeta(dev.id, dev.deviceProfileId);
      if (mounted) {
        setState(() {
          _profileImageCache[dev.id] = meta.profileImage;
          // profileName (i18n.vi.name from TB device profile) is the human-readable
          // device type name — always preferred over the model string that gateway
          // pushes as CLIENT_SCOPE 'name' (e.g. "211.030602").
          // Only skip if the device has a user-set label (dev.label takes priority).
          if (dev.label == null || dev.label!.isEmpty) {
            final n = meta.profileName?.isNotEmpty == true
                ? meta.profileName
                : meta.defaultLabel;
            if (n != null && n.isNotEmpty) _nameCache[dev.id] = n;
          }
        });
      }
    }
  }


  @override
  void initState() {
    super.initState();
    _startAll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _stopScanAll();
    super.dispose();
  }

  Future<void> _startAll() async {
    setState(() => _scanning = true);

    // Start BLE scan and gateway pairing in parallel
    await Future.wait([
      _startBleScan(),
      _startGatewayPairing(),
    ]);

    if (mounted) {
      setState(() => _scanning = _bleScanning || _pollTimer != null);
    }
  }

  // ─── BLE scan ──────────────────────────────────────────────────────────────

  Future<void> _startBleScan() async {
    setState(() {
      _bleScanning = true;
      _bleError = null;
    });

    // Check if Bluetooth is enabled before scanning
    // (flutter_esp_ble_prov crashes at native level if BT is off)
    final btEnabled = await Permission.bluetooth.serviceStatus.isEnabled;
    if (!btEnabled) {
      if (mounted) {
        setState(() {
          _bleScanning = false;
          _bleError = 'Vui lòng bật Bluetooth để quét thiết bị';
        });
      }
      return;
    }

    // Request BLE permissions
    final granted = await _requestBlePermissions();
    if (!granted) {
      if (mounted) {
        setState(() {
          _bleScanning = false;
          _bleError = 'Chưa cấp quyền Bluetooth';
        });
      }
      return;
    }

    try {
      // Scan for ESP BLE devices (prefix empty = all ESP devices)
      final devices = await _bleSvc
          .scanBleDevices('')
          .timeout(const Duration(seconds: 15), onTimeout: () => <String>[]);
      if (mounted) {
        setState(() {
          _bleDevices = devices;
          _bleScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bleScanning = false;
          _bleError = 'Lỗi quét BLE: $e';
        });
      }
    }
  }

  Future<bool> _requestBlePermissions() async {
    if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted;
    } else if (Platform.isAndroid) {
      // Android 12+ needs bluetoothScan + bluetoothConnect
      final scan = await Permission.bluetoothScan.request();
      final connect = await Permission.bluetoothConnect.request();
      if (scan.isGranted && connect.isGranted) return true;
      // Fallback for older Android: location
      final location = await Permission.location.request();
      return location.isGranted;
    }
    return true;
  }

  // ─── Gateway pairing ────────────────────────────────────────────────────────

  Future<void> _startGatewayPairing() async {
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return;

    _gateways = await _svc.fetchGatewayDevices(home.id);
    if (_gateways.isEmpty) return;

    // Find which devices are already assigned to home or its rooms
    final homeDeviceIds = await _svc.fetchHomeDeviceIds(home.id);
    final roomDeviceIds = await _svc.fetchRoomDeviceIds(home.id);
    final assignedIds = {...homeDeviceIds, ...roomDeviceIds};

    // Collect all existing sub-devices and find unassigned ones
    final allExisting = <SmarthomeDevice>[];
    for (final gw in _gateways) {
      final existing = await _svc.fetchSubDevices(gw.id);
      _initialIds[gw.id] = existing.map((d) => d.id).toSet();
      allExisting.addAll(existing);
    }
    _unassigned = allExisting
        .where((d) => !assignedIds.contains(d.id))
        .toList();

    // Auto-assign unassigned sub-devices to home, then resolve profile
    // metadata so they display with correct names immediately.
    await _autoAssignAll(_unassigned);
    await _resolveProfileImages(_unassigned);

    if (mounted) setState(() {});

    // Send startScan to all gateways
    for (final gw in _gateways) {
      _svc.startScan(gw.id).catchError((_) {});
    }

    // Poll every 3s
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    final newFound = <SmarthomeDevice>[];
    for (final gw in _gateways) {
      final current = await _svc.fetchSubDevices(gw.id);
      final initial = _initialIds[gw.id] ?? {};
      newFound.addAll(current.where((d) => !initial.contains(d.id)));
    }
    // Auto-assign newly discovered devices
    // (also resolves names + profile images before invalidating home provider)
    final toAssign = newFound.where((d) => !_assigned.contains(d.id)).toList();
    if (toAssign.isNotEmpty) await _autoAssignAll(toAssign);
    // Resolve profile metadata (name + image) BEFORE showing devices so names
    // are correct from the first render — no intermediate wrong-name flash.
    await _resolveProfileImages(newFound);
    if (mounted) {
      setState(() => _gwFound = newFound);
    }
  }

  Future<void> _autoAssignAll(List<SmarthomeDevice> devices) async {
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return;
    bool anyAssigned = false;
    for (final dev in devices) {
      if (_assigned.contains(dev.id)) continue;
      try {
        await _svc.assignToHome(dev.id, home.id);
        _assigned.add(dev.id);
        anyAssigned = true;
      } catch (_) {}
    }
    if (anyAssigned) {
      ref.invalidate(devicesInHomeProvider(home.id));
    }
  }

  void _stopScanAll() {
    for (final gw in _gateways) {
      _svc.stopScan(gw.id).catchError((_) {});
    }
  }

  Future<void> _stopScan() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _stopScanAll();
    setState(() {
      _scanning = false;
      _bleScanning = false;
    });
  }

  // ─── BLE WiFi provisioning flow ─────────────────────────────────────────────

  Future<void> _onBleTap(String deviceName) async {
    // Ask for proof-of-possession (PIN on device)
    final pop = await showDialog<String>(
      context: context,
      builder: (_) => _PopDialog(deviceName: deviceName),
    );
    if (pop == null || !mounted) return;

    // Show loading while scanning WiFi networks
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Đang kết nối và quét WiFi…')),
          ],
        ),
      ),
    );

    try {
      // Connect to device and scan WiFi
      await _bleSvc.scanBleDevices(''); // workaround for library init
      final networks = await _bleSvc
          .scanWifiNetworks(
            deviceName: deviceName,
            proofOfPossession: pop,
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      if (networks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy WiFi nào')),
        );
        return;
      }

      // Let user pick WiFi network and enter password
      final result = await showDialog<_WifiCredentials>(
        context: context,
        builder: (_) => _WifiPickerDialog(networks: networks),
      );
      if (result == null || !mounted) return;

      // Provision WiFi
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Đang cấu hình WiFi cho thiết bị…')),
            ],
          ),
        ),
      );

      final success = await _bleSvc
          .provisionWifi(
            deviceName: deviceName,
            proofOfPossession: pop,
            ssid: result.ssid,
            passphrase: result.password,
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Đã cấu hình WiFi cho "$deviceName". Thiết bị sẽ tự kết nối.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cấu hình WiFi thất bại')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasBle = _bleDevices.isNotEmpty;
    final hasGw = _gwFound.isNotEmpty;
    final hasContent = hasBle || hasGw || _unassigned.isNotEmpty;
    final isScanning = _scanning || _bleScanning;

    return Scaffold(
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MpColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thêm thiết bị',
          style: TextStyle(
            color: MpColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (isScanning)
            TextButton(
              onPressed: _stopScan,
              child: const Text('Dừng', style: TextStyle(color: MpColors.red)),
            ),
          if (!isScanning)
            IconButton(
              icon: const Icon(Icons.refresh, color: MpColors.text2),
              onPressed: _startAll,
              tooltip: 'Quét lại',
            ),
        ],
      ),
      body: Column(
        children: [
          // Scan status banner
          _ScanBanner(
            scanning: isScanning,
            gatewayCount: _gateways.length,
            gwFoundCount: _gwFound.length,
            bleCount: _bleDevices.length,
          ),

          // Content
          Expanded(
            child: !hasContent
                ? _buildEmptyState(isScanning)
                : ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      // ── Auto-assigned sub-devices ──
                      if (_unassigned.isNotEmpty) ...[
                        _SectionHeader(
                          icon: Icons.check_circle_outline,
                          iconColor: MpColors.green,
                          title: 'Đã thêm vào nhà (${_unassigned.length})',
                          subtitle: 'Thiết bị đã tự động gán vào nhà',
                        ),
                        ..._unassigned.map((dev) => _DeviceTile(
                              name: _displayName(dev),
                              type: dev.type,
                              protocol: 'Zigbee/BLE',
                              profileImage: _profileImage(dev),
                            )),
                        const Divider(height: 1, color: MpColors.border),
                      ],

                      // ── BLE devices ──
                      if (hasBle) ...[
                        _SectionHeader(
                          icon: Icons.bluetooth,
                          iconColor: MpColors.violet,
                          title: 'Thiết bị BLE/WiFi (${_bleDevices.length})',
                          subtitle: 'Cấu hình WiFi qua BLE',
                        ),
                        ..._bleDevices.map((name) => _DeviceTile(
                              name: name,
                              type: 'ESP BLE',
                              protocol: 'BLE',
                              onTap: () => _onBleTap(name),
                            )),
                        const Divider(height: 1, color: MpColors.border),
                      ],

                      // ── Gateway new devices ──
                      if (hasGw) ...[
                        _SectionHeader(
                          icon: Icons.router_outlined,
                          iconColor: MpColors.amber,
                          title: 'Mới phát hiện (${_gwFound.length})',
                          subtitle:
                              '${_gateways.length} gateway đang quét — tự động thêm vào nhà',
                        ),
                        ..._gwFound.map((dev) => _DeviceTile(
                              name: _displayName(dev),
                              type: dev.type,
                              protocol: 'Gateway',
                              profileImage: _profileImage(dev),
                            )),
                      ],
                    ],
                  ),
          ),

          // Bottom CTA
          Container(
            decoration: const BoxDecoration(
              color: MpColors.bg,
              border: Border(top: BorderSide(color: MpColors.border, width: 0.5)),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClaimDevicePage()),
              ),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: MpColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MpColors.border),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 18, color: MpColors.text2),
                    SizedBox(width: 8),
                    Text(
                      'Thêm thủ công (QR / Claiming)',
                      style: TextStyle(
                        fontSize: 14,
                        color: MpColors.text2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isScanning) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isScanning) ...[
            const _ScanRings(),
            const SizedBox(height: 20),
            const Text(
              'Đang tìm thiết bị…',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: MpColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _gateways.isEmpty
                  ? 'Đang quét BLE…\nBật nguồn thiết bị và đưa lại gần.'
                  : 'Đang quét qua ${_gateways.length} gateway + BLE…\nBật nguồn thiết bị và đưa lại gần.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: MpColors.text3, fontSize: 13),
            ),
          ] else ...[
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: MpColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off, size: 30, color: MpColors.text3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không tìm thấy thiết bị mới',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: MpColors.text,
              ),
            ),
            if (_bleError != null) ...[
              const SizedBox(height: 8),
              Text(
                _bleError!,
                style: const TextStyle(color: MpColors.amber, fontSize: 13),
              ),
            ],
            if (_gateways.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Không có gateway trong nhà.\nBạn vẫn có thể thêm thiết bị WiFi qua BLE\nhoặc sử dụng QR/Claiming bên dưới.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MpColors.text3, fontSize: 13),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── Scan rings animation ─────────────────────────────────────────────────────

class _ScanRings extends StatefulWidget {
  const _ScanRings();

  @override
  State<_ScanRings> createState() => _ScanRingsState();
}

class _ScanRingsState extends State<_ScanRings> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _Ring(progress: _ctrl.value, delay: 0),
            _Ring(progress: _ctrl.value, delay: 0.33),
            _Ring(progress: _ctrl.value, delay: 0.66),
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: MpColors.text,
              ),
              child: const Icon(Icons.wifi_tethering, size: 14, color: MpColors.bg),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.progress, required this.delay});
  final double progress;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final t = ((progress - delay) % 1.0).clamp(0.0, 1.0);
    final size = 20 + t * 56;
    final opacity = (1.0 - t) * 0.3;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: MpColors.text.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }
}

// ─── Scan status banner ───────────────────────────────────────────────────────

class _ScanBanner extends StatelessWidget {
  const _ScanBanner({
    required this.scanning,
    required this.gatewayCount,
    required this.gwFoundCount,
    required this.bleCount,
  });

  final bool scanning;
  final int gatewayCount;
  final int gwFoundCount;
  final int bleCount;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (gatewayCount > 0) parts.add('$gatewayCount gateway');
    parts.add('BLE');

    return Container(
      width: double.infinity,
      color: scanning ? MpColors.blueSoft : MpColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (scanning) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: MpColors.blue,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              scanning
                  ? 'Đang quét ${parts.join(' + ')}…  GW: $gwFoundCount  BLE: $bleCount'
                  : 'Đã dừng  •  GW: $gwFoundCount  BLE: $bleCount thiết bị',
              style: TextStyle(
                fontSize: 12,
                color: scanning ? MpColors.blue : MpColors.text3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MpColors.text,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: MpColors.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Device tile ──────────────────────────────────────────────────────────────

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.name,
    required this.type,
    required this.protocol,
    this.profileImage,
    this.onTap,
  });

  final String name;
  final String type;
  final String protocol;
  final String? profileImage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _DeviceIconBadge(type: type, profileImage: profileImage),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MpColors.text,
                    ),
                  ),
                  _ProtocolBadge(protocol: protocol),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 16, color: MpColors.text3),
          ],
        ),
      ),
    );
  }
}

class _ProtocolBadge extends StatelessWidget {
  const _ProtocolBadge({required this.protocol});
  final String protocol;

  Color get _color => switch (protocol) {
        'BLE' => MpColors.violet,
        'Gateway' || 'Zigbee/BLE' => MpColors.amber,
        _ => MpColors.blue,
      };

  Color get _tint => switch (protocol) {
        'BLE' => MpColors.violetSoft,
        'Gateway' || 'Zigbee/BLE' => MpColors.amberSoft,
        _ => MpColors.blueSoft,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: _tint,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        protocol,
        style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─── PoP (proof-of-possession) dialog ─────────────────────────────────────

class _PopDialog extends StatefulWidget {
  const _PopDialog({required this.deviceName});
  final String deviceName;

  @override
  State<_PopDialog> createState() => _PopDialogState();
}

class _PopDialogState extends State<_PopDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Kết nối "${widget.deviceName}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Nhập mã PIN hiển thị trên thiết bị (Proof of Possession):'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: 'PIN',
              hintText: 'abcd1234',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () {
            final pin = _ctrl.text.trim();
            if (pin.isNotEmpty) Navigator.pop(context, pin);
          },
          child: const Text('Kết nối'),
        ),
      ],
    );
  }
}

// ─── WiFi picker dialog ───────────────────────────────────────────────────

class _WifiCredentials {
  _WifiCredentials(this.ssid, this.password);
  final String ssid;
  final String password;
}

class _WifiPickerDialog extends StatefulWidget {
  const _WifiPickerDialog({required this.networks});
  final List<String> networks;

  @override
  State<_WifiPickerDialog> createState() => _WifiPickerDialogState();
}

class _WifiPickerDialogState extends State<_WifiPickerDialog> {
  String? _selected;
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chọn mạng WiFi'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 200,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.networks.length,
                itemBuilder: (context, i) {
                  final ssid = widget.networks[i];
                  return RadioListTile<String>(
                    value: ssid,
                    groupValue: _selected,
                    title: Text(ssid),
                    onChanged: (v) => setState(() => _selected = v),
                  );
                },
              ),
            ),
            if (_selected != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu WiFi "$_selected"',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(
                    context,
                    _WifiCredentials(_selected!, _passCtrl.text),
                  ),
          child: const Text('Kết nối'),
        ),
      ],
    );
  }
}

// ─── Device icon badge ────────────────────────────────────────────────────────

class _DeviceIconBadge extends StatelessWidget {
  const _DeviceIconBadge({required this.type, this.profileImage});
  final String type;
  final String? profileImage;

  IconData get _icon => switch (type) {
        'light' => Icons.lightbulb_outline,
        'airConditioner' => Icons.ac_unit,
        'smartPlug' => Icons.electrical_services,
        'curtain' => Icons.blinds,
        'doorSensor' => Icons.sensor_door_outlined,
        'motionSensor' => Icons.motion_photos_on_outlined,
        'tempHumidity' => Icons.thermostat,
        'camera' => Icons.videocam_outlined,
        'gateway' => Icons.router_outlined,
        'switch' => Icons.toggle_on_outlined,
        'remote' || 'button' || 'scene_switch' => Icons.settings_remote_outlined,
        'lock' => Icons.lock_outline,
        'smokeSensor' => Icons.local_fire_department_outlined,
        'leakSensor' => Icons.water_drop_outlined,
        'airQuality' => Icons.air,
        'soil_sensor' => Icons.grass,
        'electrical_switch' => Icons.power_settings_new,
        _ => Icons.devices_other,
      };

  @override
  Widget build(BuildContext context) {
    if (profileImage != null && profileImage!.isNotEmpty) {
      final url =
          '${ThingsboardAppConstants.thingsBoardApiEndpoint}$profileImage';
      final token = getIt<ITbClientService>().client.getJwtToken();
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 36,
          height: 36,
          fit: BoxFit.contain,
          httpHeaders: {
            if (token != null) 'X-Authorization': 'Bearer $token',
          },
          placeholder: (_, _) => Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: MpColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(_defaultIcon, size: 18, color: MpColors.text3),
          ),
          errorWidget: (_, _, _) => _badge(),
        ),
      );
    }
    return _badge();
  }

  Widget _badge() => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: MpColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_icon, size: 18, color: MpColors.text2),
      );

  static const IconData _defaultIcon = Icons.devices_other;
}
