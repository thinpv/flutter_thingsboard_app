import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

/// Tuya-style horizontal room tab bar with underline indicator.
class RoomSelector extends ConsumerWidget {
  const RoomSelector({required this.rooms, super.key});

  final List<SmarthomeRoom> rooms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRoomId = ref.watch(selectedRoomIdProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _RoomTab(
                  label: 'Tất cả',
                  selected: selectedRoomId == null,
                  primaryColor: primary,
                  onTap: () =>
                      ref.read(selectedRoomIdProvider.notifier).state = null,
                ),
                ...rooms.map(
                  (room) => _RoomTab(
                    label: room.name,
                    selected: selectedRoomId == room.id,
                    primaryColor: primary,
                    onTap: () => ref
                        .read(selectedRoomIdProvider.notifier)
                        .state = room.id,
                  ),
                ),
              ],
            ),
          ),
          // Room management
          Container(
            width: 1,
            height: 20,
            color: Colors.grey.shade200,
          ),
          IconButton(
            icon: Icon(Icons.tune, size: 18, color: Colors.grey.shade500),
            tooltip: 'Quản lý phòng',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _RoomManagementSheet(rooms: rooms),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomTab extends StatelessWidget {
  const _RoomTab({
    required this.label,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? primaryColor : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? primaryColor : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Room management sheet ─────────────────────────────────────────────────────

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
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Quản lý phòng',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  if (unassigned.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Thiết bị chưa gán phòng (${unassigned.length})',
                      color: Colors.orange.shade700,
                    ),
                    ...unassigned.map(
                      (dev) => _UnassignedDeviceTile(
                        device: dev,
                        rooms: rooms,
                        homeId: homeId,
                      ),
                    ),
                    const Divider(height: 1),
                  ],
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

// ─── Unassigned device tile ────────────────────────────────────────────────────

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
        final name =
            widget.rooms.where((r) => r.id == roomId).firstOrNull?.name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Đã gán "${widget.device.name}" vào "${name ?? 'phòng'}"'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.devices_other,
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
}

// ─── Room row with device count ────────────────────────────────────────────────

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
      trailing: Text('$count', style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}
