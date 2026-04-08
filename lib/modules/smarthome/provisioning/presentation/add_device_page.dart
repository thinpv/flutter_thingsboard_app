import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/provisioning_service.dart';

enum _Phase { selectGateway, scanning, done }

class AddDevicePage extends ConsumerStatefulWidget {
  const AddDevicePage({super.key});

  @override
  ConsumerState<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends ConsumerState<AddDevicePage> {
  final _svc = ProvisioningService();

  _Phase _phase = _Phase.selectGateway;
  bool _loadingGateways = true;
  List<SmarthomeDevice> _gateways = [];
  SmarthomeDevice? _selectedGateway;

  // scanning phase
  bool _starting = false;
  List<SmarthomeDevice> _initialDevices = [];
  List<SmarthomeDevice> _foundDevices = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadGateways();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    // Best-effort stop pairing if page is closed mid-scan
    if (_phase == _Phase.scanning && _selectedGateway != null) {
      _svc.stopPairing(_selectedGateway!.id).ignore();
    }
    super.dispose();
  }

  Future<void> _loadGateways() async {
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) {
      setState(() => _loadingGateways = false);
      return;
    }
    try {
      final gws = await _svc.fetchGatewayDevices(home.id);
      setState(() {
        _gateways = gws;
        _loadingGateways = false;
      });
    } catch (_) {
      setState(() => _loadingGateways = false);
    }
  }

  Future<void> _startPairing() async {
    final gw = _selectedGateway;
    if (gw == null) return;
    setState(() => _starting = true);
    try {
      // Snapshot current sub-devices so we can diff later
      _initialDevices = await _svc.fetchSubDevices(gw.id);
      await _svc.startPairing(gw.id);
      setState(() {
        _phase = _Phase.scanning;
        _starting = false;
        _foundDevices = [];
      });
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    } catch (e) {
      setState(() => _starting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể bắt đầu quét: $e')),
        );
      }
    }
  }

  Future<void> _poll() async {
    final gw = _selectedGateway;
    if (gw == null) return;
    try {
      final current = await _svc.fetchSubDevices(gw.id);
      final initialIds = _initialDevices.map((d) => d.id).toSet();
      final newDevices =
          current.where((d) => !initialIds.contains(d.id)).toList();
      if (mounted) setState(() => _foundDevices = newDevices);
    } catch (_) {}
  }

  Future<void> _stopPairing() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_selectedGateway != null) {
      await _svc.stopPairing(_selectedGateway!.id).catchError((_) {});
    }
    setState(() => _phase = _Phase.done);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm thiết bị'),
        actions: [
          if (_phase == _Phase.scanning)
            TextButton(
              onPressed: _stopPairing,
              child: const Text('Dừng quét'),
            ),
        ],
      ),
      body: switch (_phase) {
        _Phase.selectGateway => _buildSelectGateway(),
        _Phase.scanning => _buildScanning(),
        _Phase.done => _buildDone(),
      },
    );
  }

  // ─── Phase 1: Select gateway ──────────────────────────────────────────────

  Widget _buildSelectGateway() {
    if (_loadingGateways) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_gateways.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Không tìm thấy gateway nào.\n'
            'Hãy đảm bảo gateway đã được thêm vào nhà.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Chọn gateway để quét thiết bị mới:',
            style: TextStyle(fontSize: 15),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _gateways.length,
            itemBuilder: (context, index) {
              final gw = _gateways[index];
              final selected = _selectedGateway?.id == gw.id;
              return RadioListTile<String>(
                value: gw.id,
                groupValue: _selectedGateway?.id,
                onChanged: (_) => setState(() => _selectedGateway = gw),
                title: Text(gw.name),
                subtitle: Text(
                  gw.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: gw.isOnline ? Colors.green : Colors.grey,
                  ),
                ),
                secondary: Icon(
                  Icons.router,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed:
                _selectedGateway != null && !_starting ? _startPairing : null,
            icon: _starting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.search),
            label: Text(_starting ? 'Đang kết nối…' : 'Bắt đầu quét'),
          ),
        ),
      ],
    );
  }

  // ─── Phase 2: Scanning ────────────────────────────────────────────────────

  Widget _buildScanning() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Đang quét qua gateway: ${_selectedGateway!.name}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        if (_foundDevices.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa tìm thấy thiết bị nào…'),
                  SizedBox(height: 8),
                  Text(
                    'Hãy bật thiết bị và đưa lại gần gateway.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Thiết bị tìm thấy (${_foundDevices.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _foundDevices.length,
              itemBuilder: (context, index) =>
                  _FoundDeviceTile(device: _foundDevices[index], svc: _svc),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Phase 3: Done ────────────────────────────────────────────────────────

  Widget _buildDone() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 72, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'Quét hoàn tất',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tìm thấy ${_foundDevices.length} thiết bị mới.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  }
}

// ─── Found device tile ────────────────────────────────────────────────────────

class _FoundDeviceTile extends ConsumerWidget {
  const _FoundDeviceTile({required this.device, required this.svc});

  final SmarthomeDevice device;
  final ProvisioningService svc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.devices_other),
      title: Text(device.name),
      subtitle: Text(device.type),
      trailing: OutlinedButton(
        onPressed: () => _assignToRoom(context, ref),
        child: const Text('Thêm vào phòng'),
      ),
    );
  }

  Future<void> _assignToRoom(BuildContext context, WidgetRef ref) async {
    final rooms = ref.read(roomsProvider).valueOrNull ?? [];
    if (rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có phòng nào. Hãy tạo phòng trước.')),
      );
      return;
    }

    final room = await showDialog<SmarthomeRoom>(
      context: context,
      builder: (_) => _RoomPickerDialog(rooms: rooms),
    );
    if (room == null) return;

    try {
      await svc.assignToRoom(device.id, room.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm "${device.name}" vào "${room.name}"')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }
}

// ─── Room picker dialog ───────────────────────────────────────────────────────

class _RoomPickerDialog extends StatelessWidget {
  const _RoomPickerDialog({required this.rooms});

  final List<SmarthomeRoom> rooms;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chọn phòng'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final r = rooms[index];
            return ListTile(
              leading: const Icon(Icons.meeting_room_outlined),
              title: Text(r.name),
              onTap: () => Navigator.of(context).pop(r),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
      ],
    );
  }
}
