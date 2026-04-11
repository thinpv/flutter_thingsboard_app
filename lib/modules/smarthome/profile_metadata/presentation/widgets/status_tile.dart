import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/section_card.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/device_state_providers.dart';

/// Tile trạng thái read-only cho bool, enum, hoặc string.
///
/// - bool → Icon (check / close) + text Có/Không
/// - enum → Chip với text giá trị hiện tại
/// - string → Text hiển thị
///
/// Không có điều khiển — dùng [ToggleTile] cho bool controllable,
/// [EnumTile] cho enum controllable.
class StatusTile extends ConsumerWidget {
  const StatusTile({
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
      data: (raw) => _buildTile(context, raw),
      loading: () => const SkeletonTile(),
      error: (e, _) => ErrorTile(e),
    );
  }

  Widget _buildTile(BuildContext context, dynamic raw) {
    final label = def.labelDefault ?? stateKey;

    Widget trailing;
    switch (def.type) {
      case 'bool':
        final isTrue = _toBool(raw);
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTrue ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 18,
              color: isTrue ? Colors.green.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(width: 6),
            Text(
              isTrue ? 'Có' : 'Không',
              style: TextStyle(
                fontSize: 13,
                color: isTrue ? Colors.green.shade700 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

      case 'enum':
        trailing = Chip(
          label: Text(
            raw?.toString() ?? '—',
            style: const TextStyle(fontSize: 13),
          ),
          visualDensity: VisualDensity.compact,
        );

      default:
        // string / fallback
        trailing = Text(
          raw?.toString() ?? '—',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: trailing,
    );
  }

  static bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 'on';
  }
}
