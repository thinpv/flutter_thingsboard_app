import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

class RoomSelector extends ConsumerWidget {
  const RoomSelector({required this.rooms, super.key});

  final List<SmarthomeRoom> rooms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRoomId = ref.watch(selectedRoomIdProvider);

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _RoomChip(
                  label: 'Tất cả',
                  selected: selectedRoomId == null,
                  onTap: () =>
                      ref.read(selectedRoomIdProvider.notifier).state = null,
                ),
                ...rooms.map(
                  (room) => _RoomChip(
                    label: room.name,
                    selected: selectedRoomId == room.id,
                    onTap: () =>
                        ref.read(selectedRoomIdProvider.notifier).state =
                            room.id,
                  ),
                ),
              ],
            ),
          ),
          // Room management menu (Tuya ≡ style)
          IconButton(
            icon: Icon(Icons.tune, size: 20, color: Colors.grey.shade600),
            tooltip: 'Quản lý phòng',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => _RoomManagementSheet(rooms: rooms),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomChip extends StatelessWidget {
  const _RoomChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );
  }
}

// ─── Room management sheet ───────────────────────────────────────────────────

class _RoomManagementSheet extends ConsumerWidget {
  const _RoomManagementSheet({required this.rooms});
  final List<SmarthomeRoom> rooms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(selectedHomeProvider).valueOrNull;
    final homeId = home?.id ?? '';
    final homeDevices = ref.watch(devicesInHomeProvider(homeId));
    final unassigned = homeDevices.valueOrNull ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          _handle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Quản lý phòng',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                // Unassigned devices section
                if (unassigned.isNotEmpty)
                  _SectionHeader(
                    title:
                        'Thiết bị chưa gán phòng (${unassigned.length})',
                    color: Colors.orange.shade700,
                  ),
                ...unassigned.map(
                  (dev) => _UnassignedDeviceTile(
                    device: dev,
                    rooms: rooms,
                    homeId: homeId,
                  ),
                ),
                if (unassigned.isNotEmpty) const Divider(height: 1),
                // Room list with device counts
                _SectionHeader(
                  title: 'Phòng',
                  color: Theme.of(context).colorScheme.primary,
                ),
                ...rooms.map((room) => _RoomRow(room: room)),
                if (rooms.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.info_outline, color: Colors.grey),
                    title: Text('Chưa có phòng nào'),
                    subtitle: Text('Vào tab Tôi để tạo phòng'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _handle() => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Unassigned device tile with room picker ────────────────────────────────

class _UnassignedDeviceTile extends ConsumerStatefulWidget {
  const _UnassignedDeviceTile({
    required this.device,
    required this.rooms,
    required this.homeId,
  });
  final SmarthomeDevice device;
  final List<SmarthomeRoom> rooms;
  final String homeId;

  @override
  ConsumerState<_UnassignedDeviceTile> createState() =>
      _UnassignedDeviceTileState();
}

class _UnassignedDeviceTileState extends ConsumerState<_UnassignedDeviceTile> {
  bool _busy = false;

  Future<void> _assign(String roomId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await HomeService().assignDeviceToRoom(
        widget.device.id,
        roomId,
        widget.homeId,
      );
      ref.invalidate(devicesInHomeProvider(widget.homeId));
      ref.invalidate(devicesInRoomProvider(roomId));
      if (mounted) {
        final name = widget.rooms
            .where((r) => r.id == roomId)
            .firstOrNull
            ?.name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Đã gán "${widget.device.name}" vào "${name ?? 'phòng'}"'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        _iconFor(widget.device.type),
        color: widget.device.isOnline ? Colors.green : Colors.grey,
      ),
      title: Text(widget.device.name),
      subtitle: Text(widget.device.type),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<String>(
              tooltip: 'Gán vào phòng',
              onSelected: _assign,
              itemBuilder: (_) => widget.rooms
                  .map((r) => PopupMenuItem(
                        value: r.id,
                        child: Row(
                          children: [
                            const Icon(Icons.meeting_room_outlined, size: 20),
                            const SizedBox(width: 12),
                            Text(r.name),
                          ],
                        ),
                      ))
                  .toList(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Gán phòng',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'light' => Icons.lightbulb_outline,
      'air_conditioner' => Icons.ac_unit,
      'smart_plug' => Icons.electrical_services,
      'curtain' => Icons.blinds,
      'door_sensor' => Icons.sensor_door_outlined,
      'motion_sensor' => Icons.motion_photos_on_outlined,
      'temp_humidity' => Icons.thermostat,
      'camera' => Icons.videocam_outlined,
      'gateway' => Icons.router_outlined,
      _ => Icons.devices_other,
    };
  }
}

// ─── Room row with device count ──────────────────────────────────────────────

class _RoomRow extends ConsumerWidget {
  const _RoomRow({required this.room});
  final SmarthomeRoom room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesInRoomProvider(room.id));
    final count = devices.valueOrNull?.length ?? 0;

    return ListTile(
      leading: const Icon(Icons.meeting_room_outlined),
      title: Text(room.name),
      trailing: Text(
        '$count',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
