import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// IrAcControl — giao diện điều khiển điều hòa IR (LG, Samsung, Daikin...).
//
// Hiển thị:
//   - Trạng thái ON/OFF + nhiệt độ hiện tại (từ telemetry onoff0 / temp ảo)
//   - Thanh điều chỉnh nhiệt độ (16–30°C, nút +/-)
//   - Chọn mode: Cool / Heat / Fan / Dry / Auto
//   - Chọn tốc độ quạt: Auto / Low / Mid / High
//   - Toggle Swing
//   - Nút Turbo, Sleep
//
// Telemetry keys đọc từ VirtualStateStore:
//   onoff0 (int 0/1), ac_temp (int 16-30), ac_mode (string), ac_fan (string), swing (int 0/1)
//
// RPC gửi đi:
//   method: "power"                       → bật/tắt
//   method: "setAcState", params: {key: "${mode}_${temp}_${fan}"}   → cập nhật state
//   method: "swing"                       → toggle swing
//   method: "turbo"                       → turbo
//   method: "sleep"                       → sleep

typedef RpcCallback = Future<void> Function(String method, Map<String, dynamic> params);

class IrAcControl extends StatefulWidget {
  const IrAcControl({
    super.key,
    required this.deviceName,
    required this.telemetry,
    required this.onRpc,
    this.minTemp = 16,
    this.maxTemp = 30,
    this.supportedModes = const ['cool', 'heat', 'fan', 'dry', 'auto'],
    this.supportedFanSpeeds = const ['auto', 'low', 'mid', 'high'],
  });

  final String deviceName;
  final Map<String, dynamic> telemetry;
  final RpcCallback onRpc;
  final int minTemp;
  final int maxTemp;
  final List<String> supportedModes;
  final List<String> supportedFanSpeeds;

  @override
  State<IrAcControl> createState() => _IrAcControlState();
}

class _IrAcControlState extends State<IrAcControl> {
  late int _temp;
  late String _mode;
  late String _fanSpeed;
  bool _swing = false;
  bool _isOn = false;
  bool _sending = false;

  // Mode display metadata
  static const _modeInfo = <String, ({String label, IconData icon, Color color})>{
    'cool': (label: 'Mát',   icon: Icons.ac_unit,        color: Color(0xFF0288D1)),
    'heat': (label: 'Sưởi',  icon: Icons.local_fire_department, color: Color(0xFFE64A19)),
    'fan':  (label: 'Quạt',  icon: Icons.air,       color: Color(0xFF00838F)),
    'dry':  (label: 'Khô',   icon: Icons.water_drop,     color: Color(0xFF6A1B9A)),
    'auto': (label: 'Tự động',icon: Icons.autorenew,     color: Color(0xFF2E7D32)),
  };

  static const _fanInfo = <String, ({String label, IconData icon})>{
    'auto': (label: 'Tự động', icon: Icons.autorenew),
    'low':  (label: 'Thấp',    icon: Icons.air),
    'mid':  (label: 'Vừa',     icon: Icons.air),
    'high': (label: 'Cao',     icon: Icons.air),
  };

  @override
  void initState() {
    super.initState();
    _syncFromTelemetry();
  }

  @override
  void didUpdateWidget(IrAcControl old) {
    super.didUpdateWidget(old);
    if (old.telemetry != widget.telemetry) _syncFromTelemetry();
  }

  void _syncFromTelemetry() {
    final t = widget.telemetry;
    _isOn     = isOn(t['onoff0']);
    _temp     = intVal(t['acTemp']) ??
                intVal(t['coolSp']) ??
                25;
    _temp     = _temp.clamp(widget.minTemp, widget.maxTemp);
    _mode     = t['acMode']?.toString() ?? 'cool';
    _fanSpeed = t['acFan']?.toString() ?? 'auto';
    _swing    = isOn(t['swing']);

    if (!widget.supportedModes.contains(_mode)) _mode = widget.supportedModes.first;
    if (!widget.supportedFanSpeeds.contains(_fanSpeed)) _fanSpeed = widget.supportedFanSpeeds.first;
  }

  Future<void> _sendAcState() async {
    if (_sending) return;
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    try {
      final key = '${_mode}_${_temp}_$_fanSpeed';
      await widget.onRpc('setAcState', {'key': key});
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _togglePower() async {
    HapticFeedback.mediumImpact();
    await widget.onRpc('power', {});
    if (mounted) setState(() => _isOn = !_isOn);
  }

  Future<void> _toggleSwing() async {
    HapticFeedback.selectionClick();
    await widget.onRpc('swing', {});
    if (mounted) setState(() => _swing = !_swing);
  }

  Future<void> _sendTurbo() async {
    HapticFeedback.heavyImpact();
    await widget.onRpc('turbo', {});
    _showSnack('Turbo bật');
  }

  Future<void> _sendSleep() async {
    HapticFeedback.selectionClick();
    await widget.onRpc('sleep', {});
    _showSnack('Chế độ ngủ');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  Color get _acColor {
    if (!_isOn) return const Color(0xFF424242);
    return _modeInfo[_mode]?.color ?? const Color(0xFF0288D1);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildTempCard(),
          const SizedBox(height: 16),
          _buildModeCard(),
          const SizedBox(height: 16),
          _buildFanCard(),
          const SizedBox(height: 16),
          _buildExtrasRow(),
        ],
      ),
    );
  }

  // ── Status card: power button + current state display ────────────────────────
  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isOn
                ? [_acColor.withValues(alpha: 0.9), _acColor.withValues(alpha: 0.6)]
                : [const Color(0xFF424242), const Color(0xFF212121)],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOn ? 'Đang bật' : 'Đã tắt',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$_temp',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w200,
                          height: 1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          '°C',
                          style: TextStyle(color: Colors.white70, fontSize: 22),
                        ),
                      ),
                    ],
                  ),
                  if (_isOn) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _modeInfo[_mode]?.icon ?? Icons.ac_unit,
                          color: Colors.white70, size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_modeInfo[_mode]?.label ?? _mode}  •  '
                          '${_fanInfo[_fanSpeed]?.label ?? _fanSpeed}'
                          '${_swing ? "  •  Swing" : ""}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Power button
            GestureDetector(
              onTap: _togglePower,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isOn
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFF616161),
                  border: Border.all(
                    color: _isOn ? Colors.white60 : Colors.white24,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.power_settings_new,
                  color: _isOn ? Colors.white : Colors.white38,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Temperature card ─────────────────────────────────────────────────────────
  Widget _buildTempCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhiệt độ',
                style: TextStyle(fontSize: 13, color: MpColors.text3)),
            const SizedBox(height: 12),
            Row(
              children: [
                // Decrease
                _TempButton(
                  icon: Icons.remove,
                  onTap: _isOn && _temp > widget.minTemp
                      ? () { setState(() => _temp--); _sendAcState(); }
                      : null,
                ),
                // Slider
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 10),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 18),
                      activeTrackColor: _isOn ? _acColor : MpColors.text3,
                      thumbColor: _isOn ? _acColor : MpColors.text3,
                      inactiveTrackColor:
                          (_isOn ? _acColor : MpColors.text3).withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _temp.toDouble(),
                      min: widget.minTemp.toDouble(),
                      max: widget.maxTemp.toDouble(),
                      divisions: widget.maxTemp - widget.minTemp,
                      onChanged: _isOn
                          ? (v) => setState(() => _temp = v.round())
                          : null,
                      onChangeEnd: _isOn ? (_) => _sendAcState() : null,
                    ),
                  ),
                ),
                // Increase
                _TempButton(
                  icon: Icons.add,
                  onTap: _isOn && _temp < widget.maxTemp
                      ? () { setState(() => _temp++); _sendAcState(); }
                      : null,
                ),
              ],
            ),
            // Min/Max labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${widget.minTemp}°',
                      style:
                          const TextStyle(fontSize: 11, color: MpColors.text3)),
                  Text('${widget.maxTemp}°',
                      style:
                          const TextStyle(fontSize: 11, color: MpColors.text3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mode card ────────────────────────────────────────────────────────────────
  Widget _buildModeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chế độ',
                style: TextStyle(fontSize: 13, color: MpColors.text3)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: widget.supportedModes.map((mode) {
                final info = _modeInfo[mode];
                final selected = _mode == mode;
                return GestureDetector(
                  onTap: _isOn
                      ? () {
                          setState(() => _mode = mode);
                          _sendAcState();
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: selected && _isOn
                          ? (info?.color ?? _acColor).withValues(alpha: 0.15)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected && _isOn
                            ? (info?.color ?? _acColor)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          info?.icon ?? Icons.device_unknown,
                          color: selected && _isOn
                              ? (info?.color ?? _acColor)
                              : MpColors.text3,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          info?.label ?? mode,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected && _isOn
                                ? (info?.color ?? _acColor)
                                : MpColors.text3,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Fan speed card ───────────────────────────────────────────────────────────
  Widget _buildFanCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tốc độ quạt',
                style: TextStyle(fontSize: 13, color: MpColors.text3)),
            const SizedBox(height: 12),
            Row(
              children: widget.supportedFanSpeeds.map((spd) {
                final selected = _fanSpeed == spd;
                return Expanded(
                  child: GestureDetector(
                    onTap: _isOn
                        ? () {
                            setState(() => _fanSpeed = spd);
                            _sendAcState();
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: selected && _isOn
                            ? _acColor.withValues(alpha: 0.15)
                            : MpColors.surfaceAlt,
                        border: Border.all(
                          color: selected && _isOn
                              ? _acColor
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.air,
                            size: spd == 'auto'
                                ? 16
                                : spd == 'low'
                                    ? 18
                                    : spd == 'mid'
                                        ? 21
                                        : 24,
                            color: selected && _isOn ? _acColor : MpColors.text3,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _fanInfo[spd]?.label ?? spd,
                            style: TextStyle(
                              fontSize: 11,
                              color: selected && _isOn ? _acColor : MpColors.text3,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Extras row: swing, turbo, sleep ─────────────────────────────────────────
  Widget _buildExtrasRow() {
    return Row(
      children: [
        Expanded(
          child: _ExtraButton(
            icon: Icons.swipe_vertical,
            label: 'Swing',
            active: _swing && _isOn,
            onTap: _isOn ? _toggleSwing : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ExtraButton(
            icon: Icons.flash_on,
            label: 'Turbo',
            active: false,
            onTap: _isOn ? _sendTurbo : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ExtraButton(
            icon: Icons.bedtime,
            label: 'Sleep',
            active: false,
            onTap: _isOn ? _sendSleep : null,
          ),
        ),
      ],
    );
  }
}

// ─── Helper widgets ──────────────────────────────────────────────────────────

class _TempButton extends StatelessWidget {
  const _TempButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? MpColors.blue.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: enabled
                ? MpColors.blue.withValues(alpha: 0.4)
                : MpColors.text3.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? MpColors.blue : MpColors.text3,
        ),
      ),
    );
  }
}

class _ExtraButton extends StatelessWidget {
  const _ExtraButton({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active
              ? MpColors.blue.withValues(alpha: 0.15)
              : MpColors.surfaceAlt,
          border: Border.all(
            color: active
                ? MpColors.blue
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: active
                  ? MpColors.blue
                  : enabled
                      ? MpColors.text3
                      : MpColors.text3.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active
                    ? MpColors.blue
                    : enabled
                        ? MpColors.text3
                        : MpColors.text3.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
