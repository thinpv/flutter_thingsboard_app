import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';

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

          // Dropdown when multiple homes
          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: current?.id ?? list.first.id,
              icon: const Icon(Icons.keyboard_arrow_down),
              style: Theme.of(context).textTheme.titleLarge,
              items: list
                  .map(
                    (h) => DropdownMenuItem(
                      value: h.id,
                      child: Text(h.name),
                    ),
                  )
                  .toList(),
              onChanged: (id) =>
                  ref.read(selectedHomeIdProvider.notifier).state = id,
            ),
          );
        },
      ),
      centerTitle: false,
      elevation: 0,
    );
  }
}
