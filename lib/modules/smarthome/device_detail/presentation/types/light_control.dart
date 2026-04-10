import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: onoff0 (Zigbee) | onoff (BLE), dim, h, s, l, cct, color_mode, power
class LightControl extends StatefulWidget {
  const LightControl({required this.telemetry, required this.onRpc, super.key});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  @override
  State<LightControl> createState() => _LightControlState();
}

class _LightControlState extends State<LightControl> {
  late double _dim, _h, _s, _l, _cct;
  late String _colorMode;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LightControl old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    _dim = _num('dim', 100).clamp(0, 100);
    _h = _num('h', 30).clamp(0, 360);
    _s = _num('s', 80).clamp(0, 100);
    _l = _num('l', 50).clamp(0, 100);
    _cct = _num('cct', 370).clamp(153, 500); // mired range
    _colorMode = widget.telemetry['color_mode'] as String? ?? 'hs';
  }

  double _num(String k, double fallback) =>
      doubleVal(widget.telemetry[k]) ?? fallback;

  bool get _isOn =>
      isOn(widget.telemetry['onoff0'] ?? widget.telemetry['onoff']);

  Color get _hslColor =>
      HSLColor.fromAHSL(1, _h, _s / 100, _l / 100).toColor();

  Color get _cctColor {
    // Approximate color from color temp (mired → warm/cool)
    final frac = ((_cct - 153) / (500 - 153)).clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFFCCE4FF), const Color(0xFFFFD080), frac)!;
  }

  bool get _hasDim => widget.telemetry.containsKey('dim');
  bool get _hasColor =>
      widget.telemetry.containsKey('h') || widget.telemetry.containsKey('s');
  bool get _hasCct => widget.telemetry.containsKey('cct');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final previewColor = _hasColor ? _hslColor : (_hasCct ? _cctColor : cs.primary);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 16),

        // ── Power button ──
        Center(
          child: PowerButton(
            isOn: _isOn,
            icon: Icons.lightbulb_rounded,
            onTap: () => widget.onRpc('toggle', {}),
            activeColor: previewColor,
            glowColor: previewColor,
            size: 120,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _isOn ? 'Bật  ${_hasDim ? "${_dim.round()}%" : ""}' : 'Tắt',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _isOn ? null : Colors.grey,
                ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Brightness ──
        if (_hasDim) ...[
          SliderSection(
            icon: Icons.brightness_6,
            label: 'Độ sáng',
            valueLabel: '${_dim.round()}%',
            value: _dim,
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: (v) => setState(() => _dim = v),
            onChangeEnd: (v) => widget.onRpc('setValue', {'dim': v.round()}),
          ),
          const SizedBox(height: 8),
        ],

        // ── Color temp (CCT) ──
        if (_hasCct && _colorMode != 'hs') ...[
          SliderSection(
            icon: Icons.wb_incandescent_outlined,
            label: 'Màu trắng',
            valueLabel: _cct <= 300 ? 'Lạnh' : _cct <= 380 ? 'Trung tính' : 'Ấm',
            value: _cct,
            min: 153,
            max: 500,
            activeColor: _cctColor,
            onChanged: (v) => setState(() => _cct = v),
            onChangeEnd: (v) =>
                widget.onRpc('setValue', {'cct': v.round()}),
          ),
          const SizedBox(height: 8),
        ],

        // ── Hue / Saturation / Lightness ──
        if (_hasColor) ...[
          // Color mode toggle
          if (_hasCct)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ModeChip(
                  label: 'Màu sắc',
                  icon: Icons.palette_outlined,
                  selected: _colorMode == 'hs',
                  onTap: () => setState(() => _colorMode = 'hs'),
                ),
                const SizedBox(width: 12),
                _ModeChip(
                  label: 'Trắng',
                  icon: Icons.wb_incandescent_outlined,
                  selected: _colorMode == 'ct',
                  onTap: () => setState(() => _colorMode = 'ct'),
                ),
              ],
            ),
          if (_colorMode == 'hs') ...[
            const SizedBox(height: 12),
            // Color wheel preview strip
            Container(
              height: 32,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
                    Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ],
                ),
              ),
            ),
            SliderSection(
              icon: Icons.palette,
              label: 'Màu sắc (Hue)',
              valueLabel: '${_h.round()}°',
              value: _h,
              min: 0,
              max: 360,
              divisions: 36,
              activeColor: HSLColor.fromAHSL(1, _h, 1, 0.5).toColor(),
              onChanged: (v) => setState(() => _h = v),
              onChangeEnd: (v) => widget.onRpc(
                  'setValue', {'h': v.round(), 's': _s.round(), 'l': _l.round()}),
            ),
            const SizedBox(height: 8),
            SliderSection(
              icon: Icons.invert_colors,
              label: 'Bão hoà',
              valueLabel: '${_s.round()}%',
              value: _s,
              min: 0,
              max: 100,
              onChanged: (v) => setState(() => _s = v),
              onChangeEnd: (v) => widget.onRpc(
                  'setValue', {'h': _h.round(), 's': v.round(), 'l': _l.round()}),
            ),
            const SizedBox(height: 8),
            SliderSection(
              icon: Icons.wb_sunny_outlined,
              label: 'Sáng/tối',
              valueLabel: '${_l.round()}%',
              value: _l,
              min: 0,
              max: 100,
              onChanged: (v) => setState(() => _l = v),
              onChangeEnd: (v) => widget.onRpc(
                  'setValue', {'h': _h.round(), 's': _s.round(), 'l': v.round()}),
            ),
          ],
          // Color preview bar
          const SizedBox(height: 20),
          Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _colorMode == 'hs' ? _hslColor : _cctColor,
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
        ],

        // ── Power info ──
        if (widget.telemetry['power'] != null) ...[
          const SizedBox(height: 20),
          DetailRow(
            icon: Icons.bolt,
            label: 'Công suất',
            value: '${widget.telemetry['power']} W',
          ),
        ],
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? cs.onPrimary : cs.onSurface),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? cs.onPrimary : cs.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
