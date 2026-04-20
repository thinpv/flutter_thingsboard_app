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
                const SizedBox(height: 8),
                _ColorTile(
                  currentHex: _home.accentColor,
                  onPick: (hex) => _saveAccentColor(hex),
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

  Future<void> _saveAccentColor(String? hex) async {
    try {
      await HomeService().saveHomeAccentColor(_home.id, hex);
      setState(() => _home = _home.copyWith(accentColor: hex ?? ''));
      ref.invalidate(homesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không thể lưu màu: $e')));
      }
    }
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

// ─── Preset accent colors ─────────────────────────────────────────────────────

const _kPresets = [
  null,      // mặc định (reset)
  '#E53935', // đỏ
  '#F4511E', // cam đỏ
  '#D81B60', // hồng đậm
  '#8E24AA', // tím
  '#3949AB', // chàm
  '#1E88E5', // xanh dương
  '#00897B', // xanh ngọc
  '#43A047', // xanh lá
  '#FB8C00', // cam
  '#6D4C41', // nâu
  '#546E7A', // xám xanh
];

class _ColorTile extends StatelessWidget {
  const _ColorTile({required this.currentHex, required this.onPick});
  final String? currentHex;
  final void Function(String? hex) onPick;

  Color? get _current {
    if (currentHex == null || currentHex!.isEmpty) return null;
    try {
      return Color(int.parse(currentHex!.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _current;
    return InkWell(
      onTap: () => _showPicker(context),
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
                color: MpColors.surfaceAlt,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.palette_outlined,
                  size: 18, color: MpColors.violet),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tông màu',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MpColors.text),
              ),
            ),
            // Dot hiển thị màu hiện tại
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color ?? MpColors.border,
                border: Border.all(color: MpColors.border, width: 1.5),
              ),
              child: color == null
                  ? const Icon(Icons.close, size: 12, color: MpColors.text3)
                  : null,
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: MpColors.text3),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ColorPickerSheet(
        currentHex: currentHex,
        onPick: (hex) {
          Navigator.pop(context);
          onPick(hex);
        },
      ),
    );
  }
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.currentHex, required this.onPick});
  final String? currentHex;
  final void Function(String? hex) onPick;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentHex;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MpColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: MpColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Chọn tông màu',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MpColors.text),
          ),
          const SizedBox(height: 4),
          const Text(
            'Áp dụng cho header, thanh tiến trình và trạng thái bật',
            style: TextStyle(fontSize: 12, color: MpColors.text3),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _kPresets.map((hex) {
              final isSelected = hex == _selected ||
                  (hex == null &&
                      (_selected == null || _selected!.isEmpty));
              Color dotColor;
              if (hex == null) {
                dotColor = MpColors.surfaceAlt;
              } else {
                try {
                  dotColor = Color(
                      int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
                } catch (_) {
                  dotColor = MpColors.border;
                }
              }
              return GestureDetector(
                onTap: () => setState(() => _selected = hex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: Border.all(
                      color: isSelected ? MpColors.text : MpColors.border,
                      width: isSelected ? 3 : 1.5,
                    ),
                  ),
                  child: hex == null
                      ? const Icon(Icons.block,
                          size: 20, color: MpColors.text3)
                      : isSelected
                          ? const Icon(Icons.check,
                              size: 20, color: Colors.white)
                          : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => widget.onPick(_selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: MpColors.text,
                foregroundColor: MpColors.bg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Áp dụng',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail tile ──────────────────────────────────────────────────────────────

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
