import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: power (0/1), temp, hum, mode (cool/heat/auto/dry/fan),
//       cool_sp, heat_sp, run_mode, run_state, energy
class AcControl extends StatefulWidget {
  const AcControl({required this.telemetry, required this.onRpc, super.key});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  @override
  State<AcControl> createState() => _AcControlState();
}

class _AcControlState extends State<AcControl> {
  static const _modes = [
    ('cool', Icons.ac_unit, 'Lạnh', Colors.blue),
    ('heat', Icons.whatshot, 'Sưởi', Colors.deepOrange),
    ('auto', Icons.autorenew, 'Tự động', Colors.green),
    ('dry', Icons.water_drop_outlined, 'Hút ẩm', Colors.cyan),
    ('fan', Icons.air, 'Quạt', Colors.blueGrey),
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
    return found?.$4 ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _modeColor(_mode);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        // ── Hero card ──
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isOn
                  ? [activeColor.withValues(alpha: 0.15), activeColor.withValues(alpha: 0.05)]
                  : [Colors.grey.shade100, Colors.grey.shade50],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isOn ? activeColor.withValues(alpha: 0.3) : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.ac_unit,
                    color: _isOn ? activeColor : Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOn
                        ? (_runState != null ? 'Đang $_runState' : 'Đang hoạt động')
                        : 'Đã tắt',
                    style: TextStyle(
                      color: _isOn ? activeColor : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    value: _isOn,
                    activeColor: activeColor,
                    onChanged: (_) => widget.onRpc('toggle', {}),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.w200,
                              color: _isOn ? activeColor : Colors.grey,
                              height: 1,
                            ),
                      ),
                      Text(
                        '°C',
                        style: TextStyle(
                          fontSize: 20,
                          color: _isOn ? activeColor : Colors.grey,
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
                    const Icon(Icons.water_drop, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      'Độ ẩm phòng: ${widget.telemetry['hum']}%',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Mode selector ──
        Text('Chế độ hoạt động', style: Theme.of(context).textTheme.titleSmall),
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
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? (m.$4 as Color).withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                        border: Border.all(
                          color: selected ? (m.$4 as Color) : Colors.grey.shade300,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        m.$2,
                        color: selected ? (m.$4 as Color) : Colors.grey,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.$3,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? (m.$4 as Color) : Colors.grey.shade600,
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
              InfoCard(icon: Icons.bolt, label: 'Công suất', value: '${widget.telemetry['power']} W', iconColor: Colors.orange, color: Colors.orange.shade50),
            if (widget.telemetry['energy'] != null)
              InfoCard(icon: Icons.electric_meter, label: 'Điện năng', value: '${widget.telemetry['energy']} kWh', iconColor: Colors.green, color: Colors.green.shade50),
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
    return Material(
      color: onTap != null ? Colors.grey.shade100 : Colors.grey.shade50,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(
            icon,
            size: 22,
            color: onTap != null ? Colors.black87 : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}
