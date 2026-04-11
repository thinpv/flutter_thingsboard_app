import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/core/auth/login/provider/login_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/add_device_page.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/providers/unknown_devices_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homes = ref.watch(homesProvider);
    final selectedHome = ref.watch(selectedHomeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tôi'), elevation: 0),
      body: ListView(
        children: [
          // ── Home management section ──────────────────────────────────────
          _SectionHeader(
            title: 'Nhà của tôi',
            action: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _addHome(context, ref),
            ),
          ),
          homes.when(
            loading: () => const _LoadingTile(),
            error: (e, s) => ListTile(title: Text('Lỗi: $e')),
            data: (list) {
              if (list.isEmpty) {
                return const ListTile(
                  leading: Icon(Icons.home_outlined),
                  title: Text('Chưa có nhà nào'),
                );
              }
              return Column(
                children: list
                    .map((h) => _HomeTile(
                          home: h,
                          isSelected: selectedHome.valueOrNull?.id == h.id,
                          onSelect: () => ref
                              .read(selectedHomeIdProvider.notifier)
                              .state = h.id,
                          onDelete: () => _deleteHome(context, ref, h),
                        ))
                    .toList(),
              );
            },
          ),

          const Divider(),

          // ── Room management section ──────────────────────────────────────
          _SectionHeader(
            title: 'Phòng',
            action: selectedHome.valueOrNull != null
                ? IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addRoom(
                      context,
                      ref,
                      selectedHome.valueOrNull!,
                    ),
                  )
                : null,
          ),
          ref.watch(roomsProvider).when(
            loading: () => const _LoadingTile(),
            error: (e, s) => ListTile(title: Text('Lỗi: $e')),
            data: (rooms) {
              if (rooms.isEmpty) {
                return const ListTile(
                  leading: Icon(Icons.meeting_room_outlined),
                  title: Text('Chưa có phòng nào'),
                );
              }
              return Column(
                children: rooms
                    .map((r) => _RoomTile(
                          room: r,
                          onDelete: () => _deleteRoom(context, ref, r),
                        ))
                    .toList(),
              );
            },
          ),

          const Divider(),

          // ── Device provisioning section ──────────────────────────────────
          const _SectionHeader(title: 'Thiết bị'),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Thêm thiết bị mới'),
            subtitle: const Text('Quét và ghép nối qua gateway'),
            onTap: () => _addDevice(context, ref),
          ),

          // ── Unknown / pending devices section (C-A-14) ──────────────────
          const _UnknownDevicesSection(),

          const Divider(),

          // ── Account section ──────────────────────────────────────────────
          const _SectionHeader(title: 'Tài khoản'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: () => _logout(context, ref),
          ),
        ],
      ),
    );
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _addHome(BuildContext context, WidgetRef ref) async {
    final name = await _promptText(context, title: 'Tên nhà mới');
    if (name == null || name.isEmpty) return;
    try {
      await HomeService().createHome(name);
      ref.invalidate(homesProvider);
    } catch (e) {
      if (context.mounted) _showError(context, 'Không thể tạo nhà: $e');
    }
  }

  Future<void> _deleteHome(
    BuildContext context,
    WidgetRef ref,
    SmarthomeHome home,
  ) async {
    final confirmed = await _confirm(
      context,
      message: 'Xóa nhà "${home.name}"? Hành động không thể hoàn tác.',
    );
    if (!confirmed) return;
    try {
      await HomeService().deleteHome(home.id);
      ref.invalidate(homesProvider);
    } catch (e) {
      if (context.mounted) _showError(context, 'Không thể xóa nhà: $e');
    }
  }

  Future<void> _addRoom(
    BuildContext context,
    WidgetRef ref,
    SmarthomeHome home,
  ) async {
    final name = await _promptText(context, title: 'Tên phòng mới');
    if (name == null || name.isEmpty) return;
    try {
      await HomeService().createRoom(home.id, name);
      ref.invalidate(roomsProvider);
    } catch (e) {
      if (context.mounted) _showError(context, 'Không thể tạo phòng: $e');
    }
  }

  Future<void> _deleteRoom(
    BuildContext context,
    WidgetRef ref,
    SmarthomeRoom room,
  ) async {
    final confirmed = await _confirm(
      context,
      message: 'Xóa phòng "${room.name}"?',
    );
    if (!confirmed) return;
    try {
      await HomeService().deleteRoom(room.id);
      ref.invalidate(roomsProvider);
    } catch (e) {
      if (context.mounted) _showError(context, 'Không thể xóa phòng: $e');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _addDevice(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddDevicePage()),
    );
    ref.invalidate(roomsProvider);
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      message: 'Bạn có muốn đăng xuất?',
    );
    if (!confirmed) return;
    await ref.read(loginProvider.notifier).logout();
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────

  Future<String?> _promptText(
    BuildContext context, {
    required String title,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nhập tên…'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(BuildContext context, {required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ─── Reusable tiles ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      title: Text('Đang tải…'),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.home,
    required this.isSelected,
    required this.onSelect,
    required this.onDelete,
  });

  final SmarthomeHome home;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.home : Icons.home_outlined,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(home.name),
      subtitle: isSelected ? const Text('Đang chọn') : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isSelected)
            TextButton(onPressed: onSelect, child: const Text('Chọn')),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.onDelete});

  final SmarthomeRoom room;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.meeting_room_outlined),
      title: Text(room.name),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}

// ─── Unknown / pending devices section (C-A-14/15) ───────────────────────────

/// Hiển thị danh sách thiết bị gateway đã phát hiện nhưng chưa có profile.
/// Người dùng có thể copy fingerprint → tạo profile trên TB admin →
/// bấm "Thử lại" để gateway nhận dạng lại.
class _UnknownDevicesSection extends ConsumerWidget {
  const _UnknownDevicesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(unknownDevicesProvider);

    return devicesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (devices) {
        if (devices.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            _SectionHeader(
              title: 'Thiết bị chờ cấu hình',
              action: Chip(
                label: Text('${devices.length}'),
                visualDensity: VisualDensity.compact,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Các thiết bị dưới đây đã được gateway phát hiện nhưng '
                'chưa có device profile. Hãy thêm profile trên TB admin '
                'rồi bấm "Thử lại".',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 4),
            ...devices.map((d) => _UnknownDeviceTile(device: d, ref: ref)),
          ],
        );
      },
    );
  }
}

class _UnknownDeviceTile extends StatelessWidget {
  const _UnknownDeviceTile({
    required this.device,
    required this.ref,
  });

  final UnknownDevice device;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTime(device.detectedAt);
    final proto = device.protocol;

    return ListTile(
      leading: const Icon(Icons.device_unknown_outlined),
      title: Text(
        device.fingerprint,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
      subtitle: Text(
        [
          if (proto != null) proto.toUpperCase(),
          timeLabel,
        ].join(' · '),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Copy fingerprint button
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Sao chép fingerprint',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: device.fingerprint));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép fingerprint'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          // Retry button (C-A-15)
          TextButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Thử lại'),
            onPressed: () => _retry(context),
          ),
        ],
      ),
    );
  }

  Future<void> _retry(BuildContext context) async {
    try {
      await retryPendingDevices(device.gatewayId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi lệnh thử lại đến gateway'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
