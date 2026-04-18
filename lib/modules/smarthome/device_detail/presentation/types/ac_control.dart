import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: power (0/1), temp, hum, mode (cool/heat/auto/dry/fan),
//       coolSp, heatSp, runMode, runState, energy
class AcControl extends StatefulWidget {
  const AcControl({required this.telemetry, required this.onRpc, super.key});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  @override
  State<AcControl> createState() => _AcControlState();
}

class _AcControlState extends State<AcControl> {
  static const _modes = [
    ('cool', Icons.ac_unit, 'Lạnh', MpColors.blue),
    ('heat', Icons.whatshot, 'Sưởi', MpColors.red),
    ('auto', Icons.autorenew, 'Tự động', MpColors.green),
    ('dry', Icons.water_drop_outlined, 'Hút ẩm', MpColors.violet),
    ('fan', Icons.air, 'Quạt', MpColors.text2),
  ];

  late double _temp;

  @override
  void initState() {
    super.initState();
    _temp = _clampTemp();
  }

  @override
  void didUpdateWidget(AcControl old) {
    super.didUpdateWidget(old);
    final t = doubleVal(widget.telemetry['temp']);
    if (t != null) setState(() => _temp = t.clamp(16, 30));
  }

  double _clampTemp() =>
      (doubleVal(widget.telemetry['temp']) ?? 25).clamp(16, 30);

  bool get _isOn => isOn(widget.telemetry['power']);
  String get _mode => widget.telemetry['mode'] as String? ?? 'cool';
  String? get _runState => widget.telemetry['runState'] as String?;

  Color _modeColor(String mode) {
    final found = _modes.where((m) => m.$1 == mode).firstOrNull;
    return found?.$4 ?? MpColors.text2;
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _modeColor(_mode);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        // ── Hero card ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MpColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MpColors.border, width: 0.5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _isOn
                          ? activeColor.withValues(alpha: 0.1)
                          : MpColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.ac_unit,
                      color: _isOn ? activeColor : MpColors.text3,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isOn
                        ? (_runState != null ? 'Đang $_runState' : 'Đang hoạt động')
                        : 'Đã tắt',
                    style: TextStyle(
                      color: _isOn ? activeColor : MpColors.text3,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => widget.onRpc('toggle', {}),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _isOn ? MpColors.text : MpColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Align(
                        alignment: _isOn
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isOn ? MpColors.bg : MpColors.text3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Temperature display + +/- buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TempButton(
                    icon: Icons.remove,
                    onTap: _temp > 16
                        ? () {
                            setState(() => _temp--);
                            widget.onRpc('setTemp', {'temp': _temp.round()});
                          }
                        : null,
                  ),
                  const SizedBox(width: 28),
                  Column(
                    children: [
                      Text(
                        '${_temp.round()}',
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w200,
                          color: _isOn ? MpColors.text : MpColors.text3,
                          height: 1,
                        ),
                      ),
                      Text(
                        '°C',
                        style: TextStyle(
                          fontSize: 18,
                          color: _isOn ? MpColors.text2 : MpColors.text3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 28),
                  _TempButton(
                    icon: Icons.add,
                    onTap: _temp < 30
                        ? () {
                            setState(() => _temp++);
                            widget.onRpc('setTemp', {'temp': _temp.round()});
                          }
                        : null,
                  ),
                ],
              ),
              if (widget.telemetry['hum'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.water_drop, size: 14, color: MpColors.blue),
                    const SizedBox(width: 4),
                    Text(
                      'Độ ẩm phòng: ${widget.telemetry['hum']}%',
                      style: const TextStyle(color: MpColors.text3, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Mode selector ──
        const Text('Chế độ hoạt động',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MpColors.text2,
                letterSpacing: 0.4)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _modes.map((m) {
            final selected = _mode == m.$1;
            return GestureDetector(
              onTap: () => widget.onRpc('setMode', {'mode': m.$1}),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: selected
                            ? MpColors.text
                            : MpColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        m.$2,
                        color: selected ? MpColors.bg : MpColors.text3,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      m.$3,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? MpColors.text : MpColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // ── Energy / metrics ──
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            if (widget.telemetry['power'] != null)
              InfoCard(
                  icon: Icons.bolt,
                  label: 'Công suất',
                  value: '${widget.telemetry['power']} W',
                  iconColor: MpColors.amber),
            if (widget.telemetry['energy'] != null)
              InfoCard(
                  icon: Icons.electric_meter,
                  label: 'Điện năng',
                  value: '${widget.telemetry['energy']} kWh',
                  iconColor: MpColors.green),
          ],
        ),
      ],
    );
  }
}

class _TempButton extends StatelessWidget {
  const _TempButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap != null ? MpColors.surfaceAlt : MpColors.bg,
          border: Border.all(color: MpColors.border, width: 0.5),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null ? MpColors.text : MpColors.text3,
        ),
      ),
    );
  }
}
