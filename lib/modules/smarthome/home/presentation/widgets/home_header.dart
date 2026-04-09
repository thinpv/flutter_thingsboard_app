import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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

    return AppBar(
      title: homes.when(
        loading: () => const Text('SmartHome'),
        error: (e, s) => const Text('SmartHome'),
        data: (list) {
          if (list.isEmpty) return const Text('SmartHome');
          final current = selectedHome.valueOrNull;
          if (list.length == 1) return Text(current?.name ?? 'SmartHome');
          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: current?.id ?? list.first.id,
              icon: const Icon(Icons.keyboard_arrow_down),
              style: Theme.of(context).textTheme.titleLarge,
              items: list
                  .map((h) => DropdownMenuItem(value: h.id, child: Text(h.name)))
                  .toList(),
              onChanged: (id) =>
                  ref.read(selectedHomeIdProvider.notifier).state = id,
            ),
          );
        },
      ),
      centerTitle: false,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _showAddMenu(context),
        ),
      ],
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.devices_other),
              title: const Text('Thêm thiết bị'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddDevicePage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Quét mã'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ClaimDevicePage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Tạo Scene'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SceneEditPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
