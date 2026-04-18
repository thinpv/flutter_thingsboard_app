import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
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
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Quản lý phòng',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: MpColors.text,
          ),
        ),
        iconTheme: const IconThemeData(color: MpColors.text),
      ),
      body: Column(
        children: [
          Expanded(
            child: roomsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (rooms) {
                if (rooms.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.meeting_room_outlined,
                            size: 56, color: MpColors.text3),
                        SizedBox(height: 12),
                        Text(
                          'Chưa có phòng nào',
                          style: TextStyle(color: MpColors.text2, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: rooms.length,
                  itemBuilder: (context, i) => _RoomTile(
                    room: rooms[i],
                    homeId: home.id,
                    onRefresh: () => ref.invalidate(_roomsForHomeProvider(home.id)),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GestureDetector(
                onTap: () => _addRoom(context, ref),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: MpColors.text,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: MpColors.bg, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Thêm phòng',
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
        backgroundColor: MpColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Thêm phòng',
            style: TextStyle(color: MpColors.text, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: MpColors.text),
          decoration: InputDecoration(
            hintText: 'VD: Phòng khách',
            hintStyle: const TextStyle(color: MpColors.text3),
            filled: true,
            fillColor: MpColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: MpColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Tạo',
                style: TextStyle(color: MpColors.blue, fontWeight: FontWeight.w600)),
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
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RoomDetailPage(room: room, homeId: homeId),
          ),
        );
        onRefresh();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: MpColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MpColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: MpColors.greenSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.meeting_room_outlined,
                  size: 18, color: MpColors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                room.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: MpColors.text,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: MpColors.text3),
          ],
        ),
      ),
    );
  }
}
