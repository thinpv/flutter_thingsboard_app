import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/scene_edit_page.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/add_device_page.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/claim_device_page.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homes = ref.watch(homesProvider);
    final selectedHome = ref.watch(selectedHomeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 8,
        bottom: 4,
      ),
      child: Row(
        children: [
          // Home name / dropdown
          Expanded(
            child: homes.when(
              loading: () => Text(
                'SmartHome',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              error: (_, _) => const Text('SmartHome'),
              data: (list) {
                final current = selectedHome.valueOrNull;
                final name = current?.name ?? 'SmartHome';

                if (list.length <= 1) {
                  return Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    overflow: TextOverflow.ellipsis,
                  );
                }

                return GestureDetector(
                  onTap: () => _showHomePicker(context, ref, list,
                      current?.id ?? list.first.id),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: colorScheme.onSurface,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Add button
          _HeaderIconButton(
            icon: Icons.add,
            onTap: () => _showAddMenu(context),
          ),
        ],
      ),
    );
  }

  void _showHomePicker(
    BuildContext context,
    WidgetRef ref,
    List<SmarthomeHome> homes,
    String currentId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chọn nhà',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...homes.map((h) => ListTile(
                  title: Text(h.name),
                  trailing: h.id == currentId
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    ref.read(selectedHomeIdProvider.notifier).state = h.id;
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.devices_other, color: Colors.blue.shade700),
              ),
              title: const Text('Thêm thiết bị'),
              subtitle: const Text('Ghép nối thiết bị mới'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddDevicePage()));
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.qr_code_scanner,
                    color: Colors.green.shade700),
              ),
              title: const Text('Quét mã thiết bị'),
              subtitle: const Text('Thêm bằng mã QR'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ClaimDevicePage()));
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome,
                    color: Colors.orange.shade700),
              ),
              title: const Text('Tạo kịch bản'),
              subtitle: const Text('Thêm scene mới'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SceneEditPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade100,
        ),
        child: Icon(icon, size: 20, color: Colors.grey.shade700),
      ),
    );
  }
}
