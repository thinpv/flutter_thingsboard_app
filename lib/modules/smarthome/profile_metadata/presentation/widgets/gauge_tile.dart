import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/section_card.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/device_state_providers.dart';

/// Tile số read-only với thanh progress — dùng khi [StateDef.type] == 'number',
/// [StateDef.controllable] == false và [StateDef.range] != null.
class GaugeTile extends ConsumerWidget {
  const GaugeTile({
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
      data: (raw) => _buildTile(context, _toDouble(raw)),
      loading: () => const SkeletonTile(),
      error: (e, _) => ErrorTile(e),
    );
  }

  Widget _buildTile(BuildContext context, double value) {
    final range = def.range!;
    final fraction =
        ((value - range.min) / (range.max - range.min)).clamp(0.0, 1.0);
    final precision = def.precision ?? 1;
    final unit = def.unit ?? '';
    final color = _gaugeColor(fraction, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                def.labelDefault ?? stateKey,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value.toStringAsFixed(precision),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: const TextStyle(
                          fontSize: 12,
                          color: MpColors.text3,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: MpColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${range.min.toStringAsFixed(0)}$unit',
                style: const TextStyle(fontSize: 10, color: MpColors.text3),
              ),
              const Spacer(),
              Text(
                '${range.max.toStringAsFixed(0)}$unit',
                style: const TextStyle(fontSize: 10, color: MpColors.text3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Màu gauge theo tỷ lệ: xanh lá → vàng → đỏ (cho cảm biến thông thường).
  Color _gaugeColor(double fraction, BuildContext context) {
    if (fraction < 0.6) return MpColors.green;
    if (fraction < 0.8) return MpColors.amber;
    return MpColors.red;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
