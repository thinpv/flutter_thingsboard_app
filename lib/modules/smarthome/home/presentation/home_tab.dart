import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/device_card.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/home_header.dart';
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
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (home) {
          if (home == null) return const _NoHomeView();
          final roomList = rooms.valueOrNull ?? [];
          return Column(
            children: [
              // Room selector chips
              rooms.when(
                loading: () => const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (list) => RoomSelector(rooms: list),
              ),
              const Divider(height: 1),
              // Device area
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(roomsProvider);
                    ref.invalidate(devicesInHomeProvider(home.id));
                    for (final r in roomList) {
                      ref.invalidate(devicesInRoomProvider(r.id));
                    }
                    // Wait a moment for providers to reload
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: selectedRoomId == null
                      ? _AllDevicesView(
                          homeId: home.id,
                          rooms: roomList,
                        )
                      : _SingleRoomView(
                          roomId: selectedRoomId,
                          roomName: roomList
                                  .where((r) => r.id == selectedRoomId)
                                  .firstOrNull
                                  ?.name ??
                              '',
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

// ─── "Tất cả" — home-direct devices + all room sections ──────────────────────

class _AllDevicesView extends ConsumerWidget {
  const _AllDevicesView({required this.homeId, required this.rooms});

  final String homeId;
  final List<SmarthomeRoom> rooms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeDevices = ref.watch(devicesInHomeProvider(homeId));
    final homeList = homeDevices.valueOrNull ?? [];

    if (rooms.isEmpty && homeList.isEmpty) {
      // Still loading or truly empty
      if (homeDevices.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('Chưa có thiết bị nào trong nhà'),
            SizedBox(height: 4),
            Text(
              'Nhấn + để thêm thiết bị',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Home-direct devices (gateways + unassigned)
        if (homeList.isNotEmpty) ...[
          const _SliverHeader(title: 'Thiết bị'),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: HomeDeviceGrid(homeId: homeId),
          ),
        ],

        // Per-room device sections
        ...rooms.map((room) => _RoomSliver(room: room)),

        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

class _SliverHeader extends StatelessWidget {
  const _SliverHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      ),
    );
  }
}

class _RoomSliver extends ConsumerWidget {
  const _RoomSliver({required this.room});
  final SmarthomeRoom room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesInRoomProvider(room.id));
    return devices.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (list) {
        if (list.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverMainAxisGroup(
          slivers: [
            _SliverHeader(title: room.name),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: RoomDeviceGrid(
                roomId: room.id,
                roomName: room.name,
                deviceIds: list.map((d) => d.id).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Single room view ─────────────────────────────────────────────────────────

class _SingleRoomView extends ConsumerWidget {
  const _SingleRoomView({required this.roomId, required this.roomName});
  final String roomId;
  final String roomName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesInRoomProvider(roomId));
    return devices.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.devices_outlined,
                    size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('$roomName chưa có thiết bị'),
              ],
            ),
          );
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: RoomDeviceGrid(
                roomId: roomId,
                roomName: roomName,
                deviceIds: list.map((d) => d.id).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
