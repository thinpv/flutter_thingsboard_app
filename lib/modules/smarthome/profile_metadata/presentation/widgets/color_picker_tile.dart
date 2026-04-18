import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/section_card.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/device_state_providers.dart';

/// Color picker tile cho thiết bị ánh sáng.
///
/// Hỗ trợ hai mode:
/// - **HSL mode** (`stateKey = 'h'`): hiện slider Hue + badge màu. Gửi RPC
///   `setValue` cho từng key `h`, `s`, `l` khi thay đổi.
/// - **CT mode** (`stateKey = 'ct'`): hiện slider color temperature (mired).
///
/// Tile tự chọn mode dựa vào [stateKey]:
/// - `h` → HSL (dùng kết hợp với s/l keys riêng)
/// - `ct` → Color temperature
/// - Không khớp → fallback [NumberDisplay] style (show + edit raw value)
class ColorPickerTile extends ConsumerStatefulWidget {
  const ColorPickerTile({
    required this.deviceId,
    required this.stateKey,
    required this.def,
    super.key,
  });

  final String deviceId;
  final String stateKey;
  final StateDef def;

  @override
  ConsumerState<ColorPickerTile> createState() => _ColorPickerTileState();
}

class _ColorPickerTileState extends ConsumerState<ColorPickerTile> {
  double? _draggingValue; // local value while dragging

  @override
  Widget build(BuildContext context) {
    final valueAsync =
        ref.watch(deviceStateProvider((widget.deviceId, widget.stateKey)));
    return valueAsync.when(
      data: (raw) => _buildTile(context, _toDouble(raw)),
      loading: () => const SkeletonTile(),
      error: (e, _) => ErrorTile(e),
    );
  }

  Widget _buildTile(BuildContext context, double serverValue) {
    final key = widget.stateKey;
    final label = widget.def.labelDefault ?? key;
    final currentValue = _draggingValue ?? serverValue;

    if (key == 'ct') {
      return _buildCtSlider(context, label, currentValue);
    } else if (key == 'h') {
      return _buildHueSlider(context, label, currentValue);
    }

    // Generic number fallback
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: Text(
        currentValue.toStringAsFixed(widget.def.precision ?? 0),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: MpColors.text,
        ),
      ),
    );
  }

  // ─── CT slider ────────────────────────────────────────────────────────────

  Widget _buildCtSlider(BuildContext context, String label, double value) {
    // Typical CT range: 153 (cool 6500K) – 500 (warm 2000K)
    const ctMin = 153.0;
    const ctMax = 500.0;
    final kelvin = _miredToKelvin(value).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _ctColor(value),
                  border: Border.all(color: MpColors.border),
                ),
              ),
              const SizedBox(width: 6),
              Text('$kelvin K',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackShape: _GradientTrackShape(
                startColor: _ctColor(ctMin),
                endColor: _ctColor(ctMax),
              ),
              thumbColor: _ctColor(value),
            ),
            child: Slider(
              value: value.clamp(ctMin, ctMax),
              min: ctMin,
              max: ctMax,
              onChanged: widget.def.controllable
                  ? (v) => setState(() => _draggingValue = v)
                  : null,
              onChangeEnd: widget.def.controllable
                  ? (v) {
                      setState(() => _draggingValue = null);
                      ref
                          .read(deviceControlServiceProvider)
                          .setValue(widget.deviceId, 'ct', v.round());
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hue slider ───────────────────────────────────────────────────────────

  Widget _buildHueSlider(BuildContext context, String label, double value) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HSLColor.fromAHSL(1.0, value, 1.0, 0.5).toColor(),
                  border: Border.all(color: MpColors.border),
                ),
              ),
              const SizedBox(width: 6),
              Text('${value.round()}°',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackShape: _HueTrackShape(),
              thumbColor:
                  HSLColor.fromAHSL(1.0, value, 1.0, 0.5).toColor(),
            ),
            child: Slider(
              value: value.clamp(0.0, 360.0),
              min: 0,
              max: 360,
              onChanged: widget.def.controllable
                  ? (v) => setState(() => _draggingValue = v)
                  : null,
              onChangeEnd: widget.def.controllable
                  ? (v) {
                      setState(() => _draggingValue = null);
                      ref
                          .read(deviceControlServiceProvider)
                          .setValue(widget.deviceId, 'h', v.round());
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static double _miredToKelvin(double mired) =>
      mired > 0 ? 1000000 / mired : 6500;

  /// Approximate warm-white to cool-white color for CT.
  static Color _ctColor(double mired) {
    // 153 mired = cool blue-white, 500 mired = warm orange-white
    final t = ((mired - 153) / (500 - 153)).clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFFE8F4FD), const Color(0xFFFFF0D9), t)!;
  }
}

// ─── Custom track shapes ──────────────────────────────────────────────────────

class _GradientTrackShape extends RoundedRectSliderTrackShape {
  const _GradientTrackShape({
    required this.startColor,
    required this.endColor,
  });

  final Color startColor;
  final Color endColor;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    final paint = Paint()
      ..shader = LinearGradient(colors: [startColor, endColor])
          .createShader(trackRect)
      ..style = PaintingStyle.fill;
    final radius = Radius.circular(trackRect.height / 2);
    context.canvas
        .drawRRect(RRect.fromRectAndRadius(trackRect, radius), paint);
  }
}

class _HueTrackShape extends RoundedRectSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    // Rainbow gradient — sample 7 hue stops
    final stops = List.generate(
        8, (i) => HSLColor.fromAHSL(1, i * 360 / 7, 1.0, 0.5).toColor());
    final paint = Paint()
      ..shader =
          LinearGradient(colors: stops).createShader(trackRect)
      ..style = PaintingStyle.fill;
    final radius = Radius.circular(trackRect.height / 2);
    context.canvas
        .drawRRect(RRect.fromRectAndRadius(trackRect, radius), paint);
  }
}

