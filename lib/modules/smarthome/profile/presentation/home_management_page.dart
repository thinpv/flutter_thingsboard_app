import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/profile/presentation/home_detail_page.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

class HomeManagementPage extends ConsumerWidget {
  const HomeManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homesAsync = ref.watch(homesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý nhà'), elevation: 0),
      body: Column(
        children: [
          Expanded(
            child: homesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (homes) {
                if (homes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('Chưa có nhà nào'),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: homes.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (context, i) => _HomeTile(home: homes[i]),
                );
              },
            ),
          ),
          // ── Add home button ─────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _addHome(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm nhà mới'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addHome(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm nhà mới'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'VD: Nhà tôi',
            border: OutlineInputBorder(),
          ),
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
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await HomeService().createHome(name);
      ref.invalidate(homesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tạo nhà: $e')),
        );
      }
    }
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({required this.home});

  final SmarthomeHome home;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.home_outlined),
      title: Text(home.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HomeDetailPage(home: home)),
      ),
    );
  }
}
