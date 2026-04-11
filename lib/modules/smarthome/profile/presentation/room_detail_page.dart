import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

class RoomDetailPage extends ConsumerStatefulWidget {
  const RoomDetailPage({required this.room, required this.homeId, super.key});

  final SmarthomeRoom room;
  final String homeId;

  @override
  ConsumerState<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends ConsumerState<RoomDetailPage> {
  late SmarthomeRoom _room;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesInRoomProvider(_room.id));

    return Scaffold(
      appBar: AppBar(title: Text(_room.name), elevation: 0),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // ── Tên phòng ─────────────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Tên phòng'),
                  subtitle: Text(_room.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _renameRoom(context),
                ),
                const Divider(height: 1),

                // ── Nhóm ─────────────────────────────────────────────────
                const _SectionHeader(title: 'NHÓM'),
                const ListTile(
                  leading: Icon(Icons.group_outlined),
                  title: Text('Chưa có nhóm nào'),
                  subtitle: Text('Tính năng đang phát triển'),
                ),
                const Divider(height: 1),

                // ── Thiết bị ─────────────────────────────────────────────
                const _SectionHeader(title: 'THIẾT BỊ'),
                devicesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => ListTile(
                    title: Text('Lỗi: $e'),
                  ),
                  data: (devices) {
                    if (devices.isEmpty) {
                      return const ListTile(
                        leading: Icon(Icons.devices_outlined),
                        title: Text('Chưa có thiết bị nào'),
                      );
                    }
                    return Column(
                      children: devices
                          .map((d) => _DeviceTile(device: d))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Xóa phòng ────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _deleteRoom(context),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Xóa phòng',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renameRoom(BuildContext context) async {
    final controller = TextEditingController(text: _room.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên phòng'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == _room.name) return;
    try {
      await HomeService().updateRoom(
        _room.id,
        name: name,
        icon: _room.icon ?? 'living_room',
        order: _room.order,
      );
      setState(() {
        _room = SmarthomeRoom(
          id: _room.id,
          homeId: _room.homeId,
          name: name,
          icon: _room.icon,
          order: _room.order,
        );
      });
      ref.invalidate(roomsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đổi tên: $e')),
        );
      }
    }
  }

  Future<void> _deleteRoom(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa phòng'),
        content: Text('Xóa "${_room.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await HomeService().deleteRoom(_room.id);
      ref.invalidate(roomsProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xóa phòng: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});
  final SmarthomeDevice device;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.devices_outlined,
        color: device.isOnline ? Colors.green : Colors.grey,
      ),
      title: Text(device.displayName),
      subtitle: Text(
        device.isOnline ? 'Trực tuyến' : 'Ngoại tuyến',
        style: TextStyle(
          color: device.isOnline ? Colors.green : Colors.grey,
          fontSize: 12,
        ),
      ),
    );
  }
}
