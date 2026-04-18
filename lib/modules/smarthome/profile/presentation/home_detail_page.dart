import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/profile/presentation/location_page.dart';
import 'package:thingsboard_app/modules/smarthome/profile/presentation/room_management_page.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

class HomeDetailPage extends ConsumerStatefulWidget {
  const HomeDetailPage({required this.home, super.key});

  final SmarthomeHome home;

  @override
  ConsumerState<HomeDetailPage> createState() => _HomeDetailPageState();
}

class _HomeDetailPageState extends ConsumerState<HomeDetailPage> {
  late SmarthomeHome _home;

  @override
  void initState() {
    super.initState();
    _home = widget.home;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _home.name,
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
                _DetailTile(
                  icon: Icons.edit_outlined,
                  iconColor: MpColors.blue,
                  iconTint: MpColors.blueSoft,
                  title: 'Tên nhà',
                  subtitle: _home.name,
                  onTap: () => _renamHome(context),
                ),
                const SizedBox(height: 8),
                _DetailTile(
                  icon: Icons.meeting_room_outlined,
                  iconColor: MpColors.green,
                  iconTint: MpColors.greenSoft,
                  title: 'Quản lý phòng',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RoomManagementPage(home: _home),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _DetailTile(
                  icon: Icons.location_on_outlined,
                  iconColor: MpColors.violet,
                  iconTint: MpColors.violetSoft,
                  title: 'Vị trí',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LocationPage(homeId: _home.id),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => _deleteHome(context),
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
                          'Xóa nhà',
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
          ),
        ],
      ),
    );
  }

  Future<void> _renamHome(BuildContext context) async {
    final controller = TextEditingController(text: _home.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MpColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đổi tên nhà',
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
    if (name == null || name.isEmpty || name == _home.name) return;
    try {
      await HomeService().updateHome(_home.id, name: name);
      setState(() => _home = SmarthomeHome(id: _home.id, name: name));
      ref.invalidate(homesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đổi tên: $e')),
        );
      }
    }
  }

  Future<void> _deleteHome(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MpColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa nhà',
            style: TextStyle(color: MpColors.text, fontWeight: FontWeight.w600)),
        content: Text(
          'Xóa "${_home.name}"? Tất cả phòng và thiết bị sẽ bị gỡ. Hành động không thể hoàn tác.',
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
      await HomeService().deleteHome(_home.id);
      ref.invalidate(homesProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xóa nhà: $e')),
        );
      }
    }
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.iconColor,
    required this.iconTint,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconTint;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
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
                color: iconTint,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MpColors.text,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                          fontSize: 12, color: MpColors.text3),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: MpColors.text3),
          ],
        ),
      ),
    );
  }
}
