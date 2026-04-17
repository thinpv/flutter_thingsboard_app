import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';

class LightControl extends StatefulWidget {
  const LightControl({
    required this.telemetry,
    required this.onRpc,
    this.meta = const ProfileMetadata(),
    super.key,
  });
  final Map<String, dynamic> telemetry;
  final ProfileMetadata meta;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  @override
  State<LightControl> createState() => _LightControlState();
}

class _LightControlState extends State<LightControl> {
  late double _dim;
  late double _h;
  late double _s;
  late double _l;
  late double _cct;
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
    final cctRange = _cctDef?.range;
    final cctMin = cctRange?.min ?? 0;
    final cctMax = cctRange?.max ?? 100;
    final cctRaw = widget.telemetry['cct'] ?? cctMin;
    _cct = (doubleVal(cctRaw) ?? cctMin).clamp(cctMin, cctMax);
    _colorMode = widget.telemetry['colorMode'] as String? ?? 'hs';
  }

  double _num(String k, double fallback) =>
      doubleVal(widget.telemetry[k]) ?? fallback;

  // ─── Profile-driven helpers ──────────────────────────────────────────────

  /// First controllable bool key in meta.states (e.g. 'onoff0').
  /// Fallback: detect from telemetry.
  String get _onoffKey {
    for (final e in widget.meta.states.entries) {
      if (e.value.type == 'bool' && e.value.controllable) return e.key;
    }
    return widget.telemetry.containsKey('onoff0') ? 'onoff0' : 'onoff';
  }

  bool get _isOn =>
      isOn(widget.telemetry[_onoffKey] ?? widget.telemetry['onoff']);

  /// StateDef for color temperature (key: 'cct').
  StateDef? get _cctDef => widget.meta.states['cct'];

  /// True if device has color temperature control.
  bool get _hasCct {
    if (widget.meta.states.containsKey('cct')) return true;
    return widget.telemetry.containsKey('cct');
  }

  bool get _hasDim =>
      widget.meta.states.containsKey('dim') ||
      widget.telemetry.containsKey('dim');

  bool get _hasColor =>
      widget.meta.states.containsKey('h') ||
      widget.telemetry.containsKey('h') ||
      widget.telemetry.containsKey('s');

  // ─── CCT display helpers ─────────────────────────────────────────────────

  /// Normalized warm fraction in [0,1]: 0=cool, 1=warm.
  double get _cctWarmFrac {
    final range = _cctDef?.range;
    if (range != null && range.max <= 100) {
      // BLE Mesh convention: 0=warm, 100=cool
      return (1 - _cct / 100).clamp(0.0, 1.0);
    }
    // Mired convention: low=cool (153), high=warm (500)
    final min = range?.min ?? 153;
    final max = range?.max ?? 500;
    return ((_cct - min) / (max - min)).clamp(0.0, 1.0);
  }

  Color get _cctColor =>
      Color.lerp(const Color(0xFFCCE4FF), const Color(0xFFFFD080), _cctWarmFrac)!;

  String get _cctLabel {
    final coolFrac = 1 - _cctWarmFrac;
    if (coolFrac >= 0.66) return 'Lạnh';
    if (coolFrac >= 0.33) return 'Trung tính';
    return 'Ấm';
  }

  Color get _hslColor =>
      HSLColor.fromAHSL(1, _h, _s / 100, _l / 100).toColor();

  Color _previewColor(ColorScheme cs) {
    if (_hasColor) return _hslColor;
    if (_hasCct) return _cctColor;
    return cs.primary;
  }

  // ─── Actions (all via setValue) ──────────────────────────────────────────

  void _toggle() =>
      widget.onRpc('setValue', {_onoffKey: _isOn ? 0 : 1});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final previewColor = _previewColor(cs);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 16),

        // ── Power button ──
        Center(
          child: PowerButton(
            isOn: _isOn,
            icon: Icons.lightbulb_rounded,
            onTap: _toggle,
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
            onChangeEnd: (v) =>
                widget.onRpc('setValue', {'dim': v.round()}),
          ),
          const SizedBox(height: 8),
        ],

        // ── Color temp (CCT) ──
        if (_hasCct && _colorMode != 'hs') ...[
          SliderSection(
            icon: Icons.wb_incandescent_outlined,
            label: 'Màu trắng',
            valueLabel: _cctLabel,
            value: _cct,
            min: _cctDef?.range?.min ?? 0,
            max: _cctDef?.range?.max ?? 100,
            activeColor: _cctColor,
            onChanged: (v) => setState(() => _cct = v),
            onChangeEnd: (v) =>
                widget.onRpc('setValue', {'cct': v.round()}),
          ),
          const SizedBox(height: 8),
        ],

        // ── Hue / Saturation / Lightness ──
        if (_hasColor) ...[
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
