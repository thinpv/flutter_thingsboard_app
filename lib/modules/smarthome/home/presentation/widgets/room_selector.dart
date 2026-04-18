import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

/// mPipe-style horizontal room tab bar with underline indicator.
class RoomSelector extends ConsumerWidget {
  const RoomSelector({required this.rooms, super.key});

  final List<SmarthomeRoom> rooms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRoomId = ref.watch(selectedRoomIdProvider);

    return Container(
      color: MpColors.bg,
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _RoomTab(
                  label: 'Tất cả',
                  selected: selectedRoomId == null,
                  onTap: () =>
                      ref.read(selectedRoomIdProvider.notifier).state = null,
                ),
                ...rooms.map(
                  (room) => _RoomTab(
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
          Container(width: 0.5, height: 20, color: MpColors.border),
          IconButton(
            icon: const Icon(Icons.tune, size: 16, color: MpColors.text3),
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
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? MpColors.text : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? MpColors.text : MpColors.text3,
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
        decoration: const BoxDecoration(
          color: MpColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Text(
                    'Quản lý phòng',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: MpColors.text),
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
                      color: MpColors.amber,
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
                  const _SectionHeader(
                    title: 'Phòng',
                    color: MpColors.text2,
                  ),
                  ...rooms.map((room) => _RoomRow(room: room)),
                  if (rooms.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20, color: MpColors.text3),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Chưa có phòng nào', style: TextStyle(fontSize: 14, color: MpColors.text)),
                              SizedBox(height: 2),
                              Text('Vào tab Tôi để tạo phòng', style: TextStyle(fontSize: 12, color: MpColors.text3)),
                            ],
                          ),
                        ],
                      ),
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
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: MpColors.border,
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.4,
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: MpColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MpColors.border, width: 0.5),
            ),
            child: Icon(Icons.devices_other, size: 18,
                color: widget.device.isOnline ? MpColors.green : MpColors.text3),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.device.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: MpColors.text)),
                Text(widget.device.type, style: const TextStyle(fontSize: 12, color: MpColors.text3)),
              ],
            ),
          ),
          _busy
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
                  color: MpColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Gán phòng',
                  style: TextStyle(
                    fontSize: 13,
                    color: MpColors.text2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.meeting_room_outlined, size: 20, color: MpColors.text3),
          const SizedBox(width: 12),
          Expanded(
            child: Text(room.name, style: const TextStyle(fontSize: 14, color: MpColors.text)),
          ),
          Text(
            '$count thiết bị',
            style: const TextStyle(fontSize: 13, color: MpColors.text3),
          ),
        ],
      ),
    );
  }
}
