import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/device_card.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/home_header.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/quick_scene_card.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/room_selector.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedHome = ref.watch(selectedHomeProvider);
    final rooms = ref.watch(roomsProvider);
    final selectedRoomId = ref.watch(selectedRoomIdProvider);

    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 8),
        child: HomeHeader(),
      ),
      body: selectedHome.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Lỗi: $e')),
        data: (home) {
          if (home == null) return const _NoHomeView();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick scenes strip
              const QuickScenesStrip(),
              const Divider(height: 1),
              // Room selector chips
              rooms.when(
                loading: () => const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, s) => const SizedBox.shrink(),
                data: (roomList) => RoomSelector(rooms: roomList),
              ),
              // Device area
              Expanded(
                child: selectedRoomId != null
                    ? _RoomDeviceView(roomId: selectedRoomId)
                    : rooms.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Center(child: Text('Lỗi: $e')),
                        data: (roomList) => _AllRoomsView(
                          roomIds: roomList
                              .map<String>((r) => r.id)
                              .toList(),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── No home placeholder ─────────────────────────────────────────────────────

class _NoHomeView extends StatelessWidget {
  const _NoHomeView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.home_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Chưa có nhà nào',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('Vào tab Tôi để thêm nhà mới'),
        ],
      ),
    );
  }
}

// ─── Device views ────────────────────────────────────────────────────────────

/// Shows devices from ALL rooms.
class _AllRoomsView extends ConsumerWidget {
  const _AllRoomsView({required this.roomIds});

  final List<String> roomIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (roomIds.isEmpty) {
      return const Center(child: Text('Chưa có phòng nào'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: roomIds.length,
      itemBuilder: (context, index) =>
          _RoomDeviceSection(roomId: roomIds[index]),
    );
  }
}

class _RoomDeviceSection extends ConsumerWidget {
  const _RoomDeviceSection({required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesInRoomProvider(roomId));
    return devices.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final ids = list.map<String>((d) => d.id).toList();
        return DeviceGrid(roomId: roomId, deviceIds: ids);
      },
    );
  }
}

/// Shows devices from a single selected room.
class _RoomDeviceView extends ConsumerWidget {
  const _RoomDeviceView({required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesInRoomProvider(roomId));
    return devices.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Lỗi: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('Phòng chưa có thiết bị'));
        }
        final ids = list.map<String>((d) => d.id).toList();
        return DeviceGrid(roomId: roomId, deviceIds: ids);
      },
    );
  }
}
