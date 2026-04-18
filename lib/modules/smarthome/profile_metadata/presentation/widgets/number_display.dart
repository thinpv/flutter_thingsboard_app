import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/section_card.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/device_state_providers.dart';

/// Tile số read-only — hiển thị value + unit, không có gauge/slider.
/// Dùng cho [StateDef.type] == 'number', [StateDef.controllable] == false,
/// [StateDef.range] == null (hoặc không cần thanh progress).
class NumberDisplay extends ConsumerWidget {
  const NumberDisplay({
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
    final precision = def.precision ?? _inferPrecision(raw);
    final unit = def.unit ?? '';
    final display = _format(raw, precision);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        def.labelDefault ?? stateKey,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            display,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MpColors.text,
            ),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(
              unit,
              style: const TextStyle(fontSize: 12, color: MpColors.text3),
            ),
          ],
        ],
      ),
    );
  }

  static String _format(dynamic v, int precision) {
    if (v == null) return '—';
    final n = v is num ? v : num.tryParse(v.toString());
    if (n == null) return v.toString();
    return n.toStringAsFixed(precision);
  }

  static int _inferPrecision(dynamic v) {
    if (v == null) return 0;
    final n = v is num ? v : num.tryParse(v.toString());
    if (n == null) return 0;
    // Nếu có phần thập phân → 1 chữ số; nếu là nguyên → 0
    return n == n.truncate() ? 0 : 1;
  }
}
