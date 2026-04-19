import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/device_card.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/home_header.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/quick_scene_card.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/room_selector.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/system_announcement_banner.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/modules/smarthome/profile/presentation/location_page.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/profile_metadata_providers.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedHome = ref.watch(selectedHomeProvider);
    final rooms = ref.watch(roomsProvider);
    final selectedRoomId = ref.watch(selectedRoomIdProvider);

    return Scaffold(
      backgroundColor: MpColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── mPipe header: greeting + home name + avatar ───────────────
            const HomeHeader(),

            // ── System announcement banner (UC3 admin broadcast) ──────────
            const SystemAnnouncementBanner(),

            // ── Room tab bar ──────────────────────────────────────────────
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MpColors.text3,
                        ),
                      ),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (list) => RoomSelector(rooms: list),
                );
              },
            ),

            // ── Thin separator ────────────────────────────────────────────
            const Divider(height: 1, color: MpColors.border),

            // ── Main content ──────────────────────────────────────────────
            Expanded(
              child: selectedHome.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: MpColors.text3),
                ),
                error: (e, _) => Center(child: Text('Lỗi: $e')),
                data: (home) {
                  if (home == null) return const _NoHomeView();
                  final roomList = rooms.valueOrNull ?? [];
                  return RefreshIndicator(
                    color: MpColors.text,
                    backgroundColor: MpColors.surface,
                    onRefresh: () async {
                      ref.invalidate(roomsProvider);
                      ref.invalidate(devicesInHomeProvider(home.id));
                      for (final r in roomList) {
                        ref.invalidate(devicesInRoomProvider(r.id));
                      }
                      await ref
                          .read(profileMetadataServiceProvider)
                          .invalidateAll();
                      ref.invalidate(profileMetadataProvider);
                      ref.invalidate(deviceProfileMetadataProvider);
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

class _NoHomeView extends ConsumerWidget {
  const _NoHomeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: MpColors.surfaceAlt,
            ),
            child: const Icon(
              Icons.home_outlined,
              size: 36,
              color: MpColors.text3,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Chưa có nhà nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: MpColors.text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tạo nhà để bắt đầu quản lý thiết bị',
            style: TextStyle(fontSize: 13, color: MpColors.text3),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => _promptAddHome(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              decoration: BoxDecoration(
                color: MpColors.text,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Thêm nhà mới',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: MpColors.bg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptAddHome(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MpColors.bg,
        title: const Text('Thêm nhà mới',
            style: TextStyle(color: MpColors.text)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tên nhà (VD: Nhà tôi)',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy',
                style: TextStyle(color: MpColors.text2)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MpColors.text),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final home = await HomeService().createHome(name);
      ref.invalidate(homesProvider);
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LocationPage(homeId: home.id, isSetup: true),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tạo nhà: $e')),
        );
      }
    }
  }
}

// ─── "Tất cả" — scene strip + metrics + all room device sections ──────────────

class _AllDevicesView extends ConsumerWidget {
  const _AllDevicesView({required this.homeId});

  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider);
    final homeDevices = ref.watch(devicesInHomeProvider(homeId));

    final rooms = roomsAsync.valueOrNull ?? [];
    final homeList = homeDevices.valueOrNull ?? [];

    final loading = roomsAsync.isLoading || homeDevices.isLoading;
    final empty = !loading && rooms.isEmpty && homeList.isEmpty;

    if (empty) return const _EmptyDevicesView();

    return CustomScrollView(
      slivers: [
        // Scene strip
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 16),
            child: QuickScenesStrip(),
          ),
        ),

        // Loading spinner
        if (loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(color: MpColors.text3),
              ),
            ),
          ),

        // Home-direct devices (gateways + unassigned)
        if (homeList.isNotEmpty) ...[
          const _SectionHeader(title: 'THIẾT BỊ'),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
            padding: EdgeInsets.only(top: 16),
            child: QuickScenesStrip(),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: MpColors.surfaceAlt,
                  ),
                  child: const Icon(
                    Icons.devices_outlined,
                    size: 28,
                    color: MpColors.text3,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Chưa có thiết bị nào',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: MpColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Nhấn + để thêm thiết bị',
                  style: TextStyle(fontSize: 13, color: MpColors.text3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: MpColors.text3,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ─── Room sliver ──────────────────────────────────────────────────────────────

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
            '${room.name}: lỗi tải thiết bị',
            style: const TextStyle(color: MpColors.red, fontSize: 12),
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
      loading: () => const Center(
        child: CircularProgressIndicator(color: MpColors.text3),
      ),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.devices_outlined,
                  size: 48,
                  color: MpColors.text3,
                ),
                const SizedBox(height: 12),
                Text(
                  '$roomName chưa có thiết bị',
                  style: const TextStyle(color: MpColors.text2),
                ),
              ],
            ),
          );
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
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
