import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
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
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Quản lý nhà',
          style: TextStyle(
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
            child: homesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (homes) {
                if (homes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.home_outlined,
                            size: 56, color: MpColors.text3),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa có nhà nào',
                          style: TextStyle(color: MpColors.text2, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: homes.length,
                  itemBuilder: (context, i) => _HomeTile(home: homes[i]),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => _addHome(context, ref),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: MpColors.text,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: MpColors.bg, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Thêm nhà mới',
                          style: TextStyle(
                            color: MpColors.bg,
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

  Future<void> _addHome(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MpColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Thêm nhà mới',
            style: TextStyle(color: MpColors.text, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: MpColors.text),
          decoration: InputDecoration(
            hintText: 'VD: Nhà tôi',
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
            child: const Text('Hủy',
                style: TextStyle(color: MpColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Tạo',
                style: TextStyle(color: MpColors.blue, fontWeight: FontWeight.w600)),
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
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HomeDetailPage(home: home)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
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
                color: MpColors.blueSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.home_outlined,
                  size: 18, color: MpColors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                home.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: MpColors.text,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: MpColors.text3),
          ],
        ),
      ),
    );
  }
}
