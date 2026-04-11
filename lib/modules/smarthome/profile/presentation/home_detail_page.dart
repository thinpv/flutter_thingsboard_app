import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
      appBar: AppBar(title: Text(_home.name), elevation: 0),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // ── Tên nhà ────────────────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Tên nhà'),
                  subtitle: Text(_home.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _renamHome(context),
                ),
                const Divider(height: 1, indent: 16),

                // ── Quản lý phòng ──────────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.meeting_room_outlined),
                  title: const Text('Quản lý phòng'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RoomManagementPage(home: _home),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 16),

                // ── Vị trí ────────────────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Vị trí'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LocationPage(homeId: _home.id),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Xóa nhà ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _deleteHome(context),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Xóa nhà',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
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
        title: const Text('Đổi tên nhà'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Lưu'),
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
        title: const Text('Xóa nhà'),
        content: Text(
            'Xóa "${_home.name}"? Tất cả phòng và thiết bị sẽ bị gỡ. Hành động không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
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
