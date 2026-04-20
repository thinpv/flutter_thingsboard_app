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

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  late final PageController _pageCtrl;
  bool _pageChanging = false; // tránh vòng lặp sync

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  int _indexFor(String? roomId, List<SmarthomeRoom> rooms) {
    if (roomId == null) return 0;
    final i = rooms.indexWhere((r) => r.id == roomId);
    return i < 0 ? 0 : i + 1;
  }

  void _onPageChanged(int index, List<SmarthomeRoom> rooms) {
    _pageChanging = true;
    final newRoomId = index == 0 ? null : rooms[index - 1].id;
    ref.read(selectedRoomIdProvider.notifier).state = newRoomId;
    Future.microtask(() => _pageChanging = false);
  }

  void _animateToIndex(int index) {
    if (_pageChanging) return;
    if (!_pageCtrl.hasClients) return;
    if (_pageCtrl.page?.round() == index) return;
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _refresh(String homeId, List<SmarthomeRoom> rooms) async {
    ref.invalidate(roomsProvider);
    ref.invalidate(devicesInHomeProvider(homeId));
    for (final r in rooms) {
      ref.invalidate(devicesInRoomProvider(r.id));
    }
    await ref.read(profileMetadataServiceProvider).invalidateAll();
    ref.invalidate(profileMetadataProvider);
    ref.invalidate(deviceProfileMetadataProvider);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final selectedHome = ref.watch(selectedHomeProvider);
    final roomsAsync = ref.watch(roomsProvider);
    final selectedRoomId = ref.watch(selectedRoomIdProvider);
    final roomList = roomsAsync.valueOrNull ?? [];

    // Sync PageController khi tab được nhấn
    final targetIndex = _indexFor(selectedRoomId, roomList);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateToIndex(targetIndex);
    });

    return Scaffold(
      backgroundColor: MpColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const HomeHeader(),
            const SystemAnnouncementBanner(),

            // ── Room tab bar ──────────────────────────────────────────────
            selectedHome.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (home) {
                if (home == null) return const SizedBox.shrink();
                return roomsAsync.when(
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

            const Divider(height: 1, color: MpColors.border),

            // ── PageView content ──────────────────────────────────────────
            Expanded(
              child: selectedHome.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: MpColors.text3),
                ),
                error: (e, _) => Center(child: Text('Lỗi: $e')),
                data: (home) {
                  if (home == null) return const _NoHomeView();
                  return PageView(
                    controller: _pageCtrl,
                    onPageChanged: (i) => _onPageChanged(i, roomList),
                    children: [
                      _AllDevicesView(
                        homeId: home.id,
                        rooms: roomList,
                        onRefresh: () => _refresh(home.id, roomList),
                      ),
                      ...roomList.map(
                        (r) => _SingleRoomView(
                          roomId: r.id,
                          roomName: r.name,
                          onRefresh: () => _refresh(home.id, roomList),
                        ),
                      ),
                    ],
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
            child: const Icon(Icons.home_outlined, size: 36, color: MpColors.text3),
          ),
          const SizedBox(height: 20),
          const Text(
            'Chưa có nhà nào',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: MpColors.text),
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
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: MpColors.bg),
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
        title: const Text('Thêm nhà mới', style: TextStyle(color: MpColors.text)),
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
            child: const Text('Hủy', style: TextStyle(color: MpColors.text2)),
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
          MaterialPageRoute(builder: (_) => LocationPage(homeId: home.id, isSetup: true)),
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

// ─── "Tất cả" page ────────────────────────────────────────────────────────────

class _AllDevicesView extends ConsumerWidget {
  const _AllDevicesView({
    required this.homeId,
    required this.rooms,
    required this.onRefresh,
  });

  final String homeId;
  final List<SmarthomeRoom> rooms;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider);
    final homeDevices = ref.watch(devicesInHomeProvider(homeId));
    final loading = roomsAsync.isLoading || homeDevices.isLoading;
    final homeList = homeDevices.valueOrNull ?? [];
    final empty = !loading && rooms.isEmpty && homeList.isEmpty;

    if (empty) return _EmptyDevicesView(onRefresh: onRefresh);

    return RefreshIndicator(
      color: MpColors.text,
      backgroundColor: MpColors.surface,
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 16),
              child: QuickScenesStrip(),
            ),
          ),
          if (loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(color: MpColors.text3)),
              ),
            ),
          if (homeList.isNotEmpty) ...[
            const _SectionHeader(title: 'THIẾT BỊ'),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: HomeDeviceGrid(homeId: homeId),
            ),
          ],
          ...rooms.map((room) => _RoomSliver(room: room)),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDevicesView extends StatelessWidget {
  const _EmptyDevicesView({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: MpColors.text,
      backgroundColor: MpColors.surface,
      onRefresh: onRefresh,
      child: CustomScrollView(
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
                    child: const Icon(Icons.devices_outlined, size: 28, color: MpColors.text3),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Chưa có thiết bị nào',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: MpColors.text),
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
      ),
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

// ─── Room sliver (dùng trong "Tất cả") ───────────────────────────────────────

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
          child: Text('${room.name}: lỗi tải thiết bị',
              style: const TextStyle(color: MpColors.red, fontSize: 12)),
        ),
      ),
      data: (list) {
        if (list.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
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

// ─── Single room page ─────────────────────────────────────────────────────────

class _SingleRoomView extends ConsumerWidget {
  const _SingleRoomView({
    required this.roomId,
    required this.roomName,
    required this.onRefresh,
  });

  final String roomId;
  final String roomName;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesInRoomProvider(roomId));
    return devices.when(
      loading: () => const Center(child: CircularProgressIndicator(color: MpColors.text3)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (list) {
        if (list.isEmpty) {
          return RefreshIndicator(
            color: MpColors.text,
            backgroundColor: MpColors.surface,
            onRefresh: onRefresh,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.devices_outlined, size: 48, color: MpColors.text3),
                        const SizedBox(height: 12),
                        Text('$roomName chưa có thiết bị',
                            style: const TextStyle(color: MpColors.text2)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: MpColors.text,
          backgroundColor: MpColors.surface,
          onRefresh: onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16, 16, 16, MediaQuery.of(context).padding.bottom + 24,
                ),
                sliver: RoomDeviceGrid(
                  roomId: roomId,
                  roomName: roomName,
                  deviceIds: list.map((d) => d.id).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
