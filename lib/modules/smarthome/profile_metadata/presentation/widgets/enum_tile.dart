import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/section_card.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/device_state_providers.dart';

/// Tile enum — dropdown selector khi [StateDef.controllable] == true,
/// hoặc read-only chip khi false.
///
/// Dùng cho [StateDef.type] == 'enum' với [StateDef.enumValues] không rỗng.
class EnumTile extends ConsumerWidget {
  const EnumTile({
    required this.deviceId,
    required this.stateKey,
    required this.def,
    super.key,
  });

  final String deviceId;
  final String stateKey;
  final StateDef def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valueAsync = ref.watch(deviceStateProvider((deviceId, stateKey)));
    return valueAsync.when(
      data: (raw) => _buildTile(context, ref, raw?.toString()),
      loading: () => const SkeletonTile(),
      error: (e, _) => ErrorTile(e),
    );
  }

  Widget _buildTile(BuildContext context, WidgetRef ref, String? current) {
    final values = def.enumValues ?? [];
    final label = def.labelDefault ?? stateKey;

    if (!def.controllable) {
      // Read-only — chip display
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        title: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: Chip(
          label: Text(
            current ?? '—',
            style: const TextStyle(fontSize: 13),
          ),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    // Controllable — dropdown
    final currentSafe = values.contains(current) ? current : null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: values.isEmpty
          ? Text(current ?? '—')
          : DropdownButton<String>(
              value: currentSafe,
              underline: const SizedBox.shrink(),
              items: values
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (newVal) {
                if (newVal != null && newVal != current) {
                  ref
                      .read(deviceControlServiceProvider)
                      .setValue(deviceId, stateKey, newVal);
                }
              },
            ),
    );
  }
}
