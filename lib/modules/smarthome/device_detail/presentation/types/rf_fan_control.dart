import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';

// RF Fan Control — điều khiển quạt trần / quạt đứng RF (EV1527, PT2262...).
// Keys: onoff0 (bool virtual), speed (1/2/3 virtual), timer_minutes (int virtual)
//
// Vì RF là one-way, trạng thái hiển thị là virtual state từ VirtualStateStore
// (gateway tự duy trì dựa trên lệnh gửi cuối cùng).

class RfFanControl extends StatelessWidget {
  const RfFanControl({
    required this.telemetry,
    required this.onRpc,
    super.key,
  });

  final Map<String, dynamic> telemetry;
  final Future<void> Function(String method, Map<String, dynamic> params) onRpc;

  bool get _isOn {
    final v = telemetry['onoff0'];
    return v == 1 || v == true || v == '1';
  }

  int get _speed {
    final v = telemetry['speed'];
    if (v is int) return v.clamp(1, 3);
    if (v is String) return int.tryParse(v)?.clamp(1, 3) ?? 1;
    return 1;
  }

  int? get _timer => telemetry['timerMinutes'] as int?;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Power button ──
        _PowerButton(
          isOn: _isOn,
          onTap: () {
            HapticFeedback.mediumImpact();
            onRpc('toggle', {});
          },
        ),
        const SizedBox(height: 28),

        // ── Speed selector ──
        if (_isOn) ...[
          _SectionLabel(label: 'Tốc độ quạt'),
          const SizedBox(height: 12),
          _SpeedSelector(
            speed: _speed,
            onSelect: (s) {
              HapticFeedback.lightImpact();
              onRpc('setValue', {'speed': s});
            },
          ),
          const SizedBox(height: 28),

          // ── Timer ──
          _SectionLabel(label: 'Hẹn tắt'),
          const SizedBox(height: 12),
          _TimerRow(
            currentMinutes: _timer,
            onSelect: (min) => onRpc('setValue', {'timerMinutes': min}),
          ),
        ] else ...[
          Center(
            child: const Text(
              'Nhấn nút để bật quạt',
              style: TextStyle(color: MpColors.text3, fontSize: 14),
            ),
          ),
        ],

        const SizedBox(height: 12),
        // ── RF virtual state note ──
        _RfVirtualNote(),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.isOn, required this.onTap});
  final bool isOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOn
                ? MpColors.green.withValues(alpha: 0.15)
                : MpColors.text3.withValues(alpha: 0.08),
            border: Border.all(
              color: isOn ? MpColors.green : MpColors.border,
              width: 2.5,
            ),
            boxShadow: isOn
                ? [
                    BoxShadow(
                      color: MpColors.green.withValues(alpha: 0.3),
                      blurRadius: 20,
                    )
                  ]
                : null,
          ),
          child: Icon(
            Icons.air,
            size: 42,
            color: isOn ? MpColors.green : MpColors.text3,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: MpColors.text),
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.speed, required this.onSelect});
  final int speed;
  final void Function(int) onSelect;

  static const _labels = ['Thấp', 'Vừa', 'Cao'];
  static const _icons = [Icons.speed, Icons.speed, Icons.speed];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final level = i + 1;
        final selected = speed == level;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
            child: GestureDetector(
              onTap: () => onSelect(level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? MpColors.green.withValues(alpha: 0.12)
                      : MpColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? MpColors.green
                        : MpColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _icons[i],
                      color: selected ? MpColors.green : MpColors.text3,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _labels[i],
                      style: TextStyle(
                        color: selected ? MpColors.green : MpColors.text2,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '$level',
                      style: TextStyle(
                        color: selected ? MpColors.green : MpColors.text3,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TimerRow extends StatelessWidget {
  const _TimerRow({this.currentMinutes, required this.onSelect});
  final int? currentMinutes;
  final void Function(int) onSelect;

  static const _presets = [15, 30, 60, 120];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final min in _presets) ...[
          if (min != _presets.first) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(min),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: currentMinutes == min
                      ? MpColors.amber.withValues(alpha: 0.1)
                      : MpColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: currentMinutes == min
                        ? MpColors.amber
                        : MpColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.timer,
                        size: 18,
                        color: currentMinutes == min
                            ? MpColors.amber
                            : MpColors.text3),
                    const SizedBox(height: 4),
                    Text(
                      min >= 60 ? '${min ~/ 60}h' : '${min}ph',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: currentMinutes == min
                            ? MpColors.amber
                            : MpColors.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RfVirtualNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MpColors.blueSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MpColors.blue.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: MpColors.blue, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Trạng thái ảo — hiển thị lệnh đã gửi, không phải phản hồi thực từ thiết bị',
              style: TextStyle(color: MpColors.blue, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
