import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/section_card.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/device_state_providers.dart';

/// Tile điều khiển số với slider — dùng khi [StateDef.type] == 'number',
/// [StateDef.controllable] == true và [StateDef.range] != null.
class SliderTile extends ConsumerStatefulWidget {
  const SliderTile({
    required this.deviceId,
    required this.stateKey,
    required this.def,
    super.key,
  });

  final String deviceId;
  final String stateKey;
  final StateDef def;

  @override
  ConsumerState<SliderTile> createState() => _SliderTileState();
}

class _SliderTileState extends ConsumerState<SliderTile> {
  double? _localValue; // Giá trị đang kéo (chưa commit lên TB)
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final valueAsync =
        ref.watch(deviceStateProvider((widget.deviceId, widget.stateKey)));
    return valueAsync.when(
      data: (raw) => _buildTile(_toDouble(raw)),
      loading: () => const SkeletonTile(),
      error: (e, _) => ErrorTile(e),
    );
  }

  Widget _buildTile(double serverValue) {
    final range = widget.def.range!;
    final displayValue = _dragging ? (_localValue ?? serverValue) : serverValue;
    final precision = widget.def.precision ?? 0;
    final label = displayValue.toStringAsFixed(precision);
    final unit = widget.def.unit ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.def.labelDefault ?? widget.stateKey,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                '$label$unit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: displayValue.clamp(range.min, range.max),
            min: range.min,
            max: range.max,
            divisions: _divisions(range),
            onChanged: widget.def.controllable
                ? (v) => setState(() {
                      _localValue = v;
                      _dragging = true;
                    })
                : null,
            onChangeEnd: widget.def.controllable
                ? (v) {
                    setState(() {
                      _localValue = v;
                      _dragging = false;
                    });
                    ref
                        .read(deviceControlServiceProvider)
                        .setValue(widget.deviceId, widget.stateKey, v);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int? _divisions(dynamic range) {
    if (range == null) return null;
    final r = range as dynamic;
    final span = (r.max - r.min).toDouble();
    if (span <= 0) return null;
    // Tối đa 100 bậc, tối thiểu 1 bậc / 1 đơn vị
    final d = span.round();
    return d.clamp(1, 100);
  }
}
