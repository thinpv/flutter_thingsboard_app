import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';

class RoomSelector extends ConsumerWidget {
  const RoomSelector({required this.rooms, super.key});

  final List<SmarthomeRoom> rooms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRoomId = ref.watch(selectedRoomIdProvider);

    return SizedBox(
      height: 48,
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
                  ref.read(selectedRoomIdProvider.notifier).state = room.id,
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
