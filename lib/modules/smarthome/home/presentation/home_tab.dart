import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/device_card.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/home_header.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/quick_scene_card.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/room_selector.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';

// Light gray page background — makes white cards pop (Tuya-style).
const _kBgColor = Color(0xFFF2F3F7);

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedHome = ref.watch(selectedHomeProvider);
    final rooms = ref.watch(roomsProvider);
    final selectedRoomId = ref.watch(selectedRoomIdProvider);

    return Scaffold(
      backgroundColor: _kBgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Slim header (home name + add button) ──────────────────────────
            const HomeHeader(),

            // ── Room tab bar ──────────────────────────────────────────────────
            selectedHome.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (home) {
                if (home == null) return const SizedBox.shrink();
                return rooms.when(
                  loading: () => const SizedBox(
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (list) => RoomSelector(rooms: list),
                );
              },
            ),

            // ── Thin separator ────────────────────────────────────────────────
            Container(height: 1, color: Colors.grey.shade200),

            // ── Main content ──────────────────────────────────────────────────
            Expanded(
              child: selectedHome.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Lỗi: $e')),
                data: (home) {
                  if (home == null) return const _NoHomeView();
                  final roomList = rooms.valueOrNull ?? [];
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(roomsProvider);
                      ref.invalidate(devicesInHomeProvider(home.id));
                      for (final r in roomList) {
                        ref.invalidate(devicesInRoomProvider(r.id));
                      }
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: selectedRoomId == null
                        ? _AllDevicesView(homeId: home.id)
                        : _SingleRoomView(
                            roomId: selectedRoomId,
                            roomName: roomList
                                    .where((r) => r.id == selectedRoomId)
                                    .firstOrNull
                                    ?.name ??
                                '',
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── No home placeholder ──────────────────────────────────────────────────────

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
          Text('Chưa có nhà nào',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Vào tab Tôi để thêm nhà mới',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─── "Tất cả" — scene strip + all room device sections ───────────────────────

class _AllDevicesView extends ConsumerWidget {
  const _AllDevicesView({required this.homeId});

  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch both providers directly — avoids prop-timing race condition.
    final roomsAsync = ref.watch(roomsProvider);
    final homeDevices = ref.watch(devicesInHomeProvider(homeId));

    final rooms = roomsAsync.valueOrNull ?? [];
    final homeList = homeDevices.valueOrNull ?? [];

    final loading = roomsAsync.isLoading || homeDevices.isLoading;
    final empty = !loading && rooms.isEmpty && homeList.isEmpty;

    if (empty) return const _EmptyDevicesView();

    return CustomScrollView(
      slivers: [
        // Scene strip — scrolls with content
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 12),
            child: QuickScenesStrip(),
          ),
        ),

        // Loading spinner while providers fetch
        if (loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),

        // Home-direct devices (gateways + unassigned)
        if (homeList.isNotEmpty) ...[
          _SectionHeader(title: 'THIẾT BỊ'),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: HomeDeviceGrid(homeId: homeId),
          ),
        ],

        // Per-room sections
        ...rooms.map((room) => _RoomSliver(room: room)),

        SliverPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
        ),
      ],
    );
  }
}

class _EmptyDevicesView extends StatelessWidget {
  const _EmptyDevicesView();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 12),
            child: QuickScenesStrip(),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.devices_outlined,
                    size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('Chưa có thiết bị nào trong nhà'),
                const SizedBox(height: 4),
                Text(
                  'Nhấn + để thêm thiết bị',
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade500,
            letterSpacing: 0.6,
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
      error: (err, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '${room.name}: lỗi tải thiết bị — $err',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverMainAxisGroup(
          slivers: [
            _SectionHeader(title: room.name.toUpperCase()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
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

// ─── Single room view ──────────────────────────────────────────────────────────

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
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                MediaQuery.of(context).padding.bottom + 24,
              ),
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
