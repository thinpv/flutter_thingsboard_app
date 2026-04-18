import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

class RoomDetailPage extends ConsumerStatefulWidget {
  const RoomDetailPage({required this.room, required this.homeId, super.key});

  final SmarthomeRoom room;
  final String homeId;

  @override
  ConsumerState<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends ConsumerState<RoomDetailPage> {
  late SmarthomeRoom _room;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesInRoomProvider(_room.id));

    return Scaffold(
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _room.name,
          style: const TextStyle(
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              children: [
                // ── Tên phòng ─────────────────────────────────────────────
                InkWell(
                  onTap: () => _renameRoom(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
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
                            color: MpColors.blueSoft,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.edit_outlined,
                              size: 18, color: MpColors.blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tên phòng',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: MpColors.text)),
                              Text(_room.name,
                                  style: const TextStyle(
                                      fontSize: 12, color: MpColors.text3)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 18, color: MpColors.text3),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Thiết bị ─────────────────────────────────────────────
                const _SectionHeader(title: 'THIẾT BỊ'),
                const SizedBox(height: 6),
                devicesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) =>
                      Text('Lỗi: $e',
                          style: const TextStyle(color: MpColors.red)),
                  data: (devices) {
                    if (devices.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: MpColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: MpColors.border, width: 0.5),
                        ),
                        child: const Text(
                          'Chưa có thiết bị nào',
                          style: TextStyle(
                              color: MpColors.text3, fontSize: 13),
                        ),
                      );
                    }
                    return Column(
                      children: devices
                          .map((d) => _DeviceTile(device: d))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Xóa phòng ────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GestureDetector(
                onTap: () => _deleteRoom(context),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: MpColors.redSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: MpColors.red.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline,
                          color: MpColors.red, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Xóa phòng',
                        style: TextStyle(
                          color: MpColors.red,
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

  Future<void> _renameRoom(BuildContext context) async {
    final controller = TextEditingController(text: _room.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MpColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đổi tên phòng',
            style: TextStyle(color: MpColors.text, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: MpColors.text),
          decoration: InputDecoration(
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
            child: const Text('Lưu',
                style: TextStyle(color: MpColors.blue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == _room.name) return;
    try {
      await HomeService().updateRoom(
        _room.id,
        name: name,
        icon: _room.icon ?? 'living_room',
        order: _room.order,
      );
      setState(() {
        _room = SmarthomeRoom(
          id: _room.id,
          homeId: _room.homeId,
          name: name,
          icon: _room.icon,
          order: _room.order,
        );
      });
      ref.invalidate(roomsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đổi tên: $e')),
        );
      }
    }
  }

  Future<void> _deleteRoom(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MpColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa phòng',
            style: TextStyle(color: MpColors.text, fontWeight: FontWeight.w600)),
        content: Text(
          'Xóa "${_room.name}"?',
          style: const TextStyle(color: MpColors.text2, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: MpColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa',
                style: TextStyle(color: MpColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await HomeService().deleteRoom(_room.id);
      ref.invalidate(roomsProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xóa phòng: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: MpColors.text3,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});
  final SmarthomeDevice device;

  @override
  Widget build(BuildContext context) {
    final isOn = device.isOnline;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              color: isOn ? MpColors.greenSoft : MpColors.surfaceAlt,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.devices_outlined,
              size: 18,
              color: isOn ? MpColors.green : MpColors.text3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MpColors.text,
                  ),
                ),
                Text(
                  isOn ? 'Trực tuyến' : 'Ngoại tuyến',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOn ? MpColors.green : MpColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOn ? MpColors.green : MpColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}
