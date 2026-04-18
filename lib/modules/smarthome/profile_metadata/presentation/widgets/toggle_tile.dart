import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/section_card.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/device_state_providers.dart';

/// Tile boolean: Switch bật/tắt cho [StateDef.type] == 'bool'.
///
/// Nếu [def.controllable] == true → Switch có thể tương tác, gửi setValue RPC.
/// Nếu [def.controllable] == false → hiển thị trạng thái read-only.
class ToggleTile extends ConsumerWidget {
  const ToggleTile({
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
      data: (raw) => _buildTile(context, ref, _toBool(raw)),
      loading: () => const SkeletonTile(),
      error: (e, _) => ErrorTile(e),
    );
  }

  Widget _buildTile(BuildContext context, WidgetRef ref, bool value) {
    final iconColor = value ? MpColors.text : MpColors.text3;
    return InkWell(
      onTap: def.controllable
          ? () => ref
              .read(deviceControlServiceProvider)
              .setValue(deviceId, stateKey, value ? 0 : 1)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (def.icon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: value ? MpColors.surfaceAlt : MpColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MpColors.border, width: 0.5),
                ),
                child: Icon(_resolveIcon(def.icon!), size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                def.labelDefault ?? stateKey,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: MpColors.text),
              ),
            ),
            GestureDetector(
              onTap: def.controllable
                  ? () => ref
                      .read(deviceControlServiceProvider)
                      .setValue(deviceId, stateKey, value ? 0 : 1)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 26,
                decoration: BoxDecoration(
                  color: value
                      ? (def.controllable ? MpColors.text : MpColors.text3)
                      : MpColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: MpColors.border, width: 0.5),
                ),
                child: Align(
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value ? MpColors.bg : MpColors.text3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chuyển đổi giá trị telemetry raw sang bool.
  /// Gateway gửi 0/1 (int) hoặc true/false hoặc string '0'/'1'/'true'/'false'.
  static bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is double) return v != 0;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 'on';
  }

  static IconData _resolveIcon(String name) {
    const map = <String, IconData>{
      'toggle_on': Icons.toggle_on,
      'power': Icons.power,
      'lightbulb': Icons.lightbulb,
      'lightbulb_outline': Icons.lightbulb_outline,
      'lock': Icons.lock,
      'lock_open': Icons.lock_open,
    };
    return map[name] ?? Icons.radio_button_checked;
  }
}
