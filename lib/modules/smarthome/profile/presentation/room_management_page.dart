import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/modules/smarthome/profile/presentation/room_detail_page.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

class RoomManagementPage extends ConsumerWidget {
  const RoomManagementPage({required this.home, super.key});

  final SmarthomeHome home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use a local provider keyed by homeId to avoid coupling with selectedHome
    final roomsAsync = ref.watch(_roomsForHomeProvider(home.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý phòng'), elevation: 0),
      body: Column(
        children: [
          Expanded(
            child: roomsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (rooms) {
                if (rooms.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.meeting_room_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('Chưa có phòng nào'),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: rooms.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (context, i) => _RoomTile(
                    room: rooms[i],
                    homeId: home.id,
                    onRefresh: () => ref.invalidate(_roomsForHomeProvider(home.id)),
                  ),
                );
              },
            ),
          ),
          // ── Add room button ─────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _addRoom(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm phòng'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addRoom(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm phòng'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'VD: Phòng khách',
            border: OutlineInputBorder(),
          ),
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
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await HomeService().createRoom(home.id, name);
      ref
        ..invalidate(_roomsForHomeProvider(home.id))
        ..invalidate(roomsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tạo phòng: $e')),
        );
      }
    }
  }
}

// Local provider keyed by homeId (independent from selectedHome)
final _roomsForHomeProvider =
    FutureProvider.family<List<SmarthomeRoom>, String>((ref, homeId) {
  return HomeService().fetchRooms(homeId);
});

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.homeId,
    required this.onRefresh,
  });

  final SmarthomeRoom room;
  final String homeId;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.meeting_room_outlined),
      title: Text(room.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RoomDetailPage(room: room, homeId: homeId),
          ),
        );
        onRefresh();
      },
    );
  }
}
