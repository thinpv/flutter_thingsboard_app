import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

class DeviceDetailPage extends StatefulWidget {
  const DeviceDetailPage({required this.device, super.key});

  final SmarthomeDevice device;

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  late Map<String, dynamic> _telemetry;
  bool _isOnline = false;
  late String _displayName;
  TelemetrySubscriber? _telemetrySub;
  TelemetrySubscriber? _attrSub;
  final _control = DeviceControlService();

  @override
  void initState() {
    super.initState();
    _telemetry = Map.from(widget.device.telemetry);
    _isOnline = widget.device.isOnline;
    _displayName = widget.device.displayName;

    _telemetrySub = _control.subscribeToLatestTelemetry(widget.device.id);
    _telemetrySub!.attributeDataStream.listen((attrs) {
      if (mounted) {
        setState(() {
          for (final a in attrs) {
            _telemetry[a.key] = a.value;
          }
          _isOnline = _resolveOnline();
        });
      }
    });

    _attrSub = _control.subscribeToServerAttributes(
      widget.device.id,
      keys: ['active'],
    );
    _attrSub!.attributeDataStream.listen((attrs) {
      if (mounted) {
        setState(() {
          for (final a in attrs) {
            _telemetry[a.key] = a.value;
          }
          _isOnline = _resolveOnline();
        });
      }
    });
  }

  bool _resolveOnline() {
    final active = _telemetry['active'];
    if (active != null) {
      return active == true || active == 1 || active == 'true';
    }
    final stt = _telemetry['stt'];
    if (stt != null) return stt == 1 || stt == true || stt == 'true';
    return false;
  }

  @override
  void dispose() {
    _telemetrySub?.unsubscribe();
    _attrSub?.unsubscribe();
    super.dispose();
  }

  Future<void> _rpc(String method, Map<String, dynamic> params) async {
    await _control.sendOneWayRpc(widget.device.id, method, params);
  }

  Future<void> _editLabel() async {
    final controller = TextEditingController(text: _displayName);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên thiết bị'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nhập tên mới…'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (newLabel == null || newLabel.isEmpty || newLabel == _displayName) return;
    try {
      final client = getIt<ITbClientService>().client;
      final device = await client.getDeviceService().getDevice(widget.device.id);
      if (device == null) throw Exception('Không tìm thấy thiết bị');
      device.label = newLabel;
      await client.getDeviceService().saveDevice(device);
      if (mounted) setState(() => _displayName = newLabel);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _editLabel,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit_outlined, size: 16),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          _OnlineBadge(isOnline: _isOnline),
          const SizedBox(width: 12),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return switch (widget.device.effectiveUiType) {
      'light' => _LightControl(telemetry: _telemetry, onRpc: _rpc),
      'air_conditioner' => _AcControl(telemetry: _telemetry, onRpc: _rpc),
      'smart_plug' => _SmartPlugControl(telemetry: _telemetry, onRpc: _rpc),
      'curtain' => _CurtainControl(telemetry: _telemetry, onRpc: _rpc),
      'door_sensor' => _DoorSensorView(telemetry: _telemetry),
      'motion_sensor' => _MotionSensorView(telemetry: _telemetry),
      'temp_humidity' => _TempHumView(telemetry: _telemetry),
      'gateway' => _GatewayView(telemetry: _telemetry),
      'switch' => _SwitchControl(telemetry: _telemetry, onRpc: _rpc),
      _ => _GenericView(telemetry: _telemetry),
    };
  }
}

// ─── Shared widgets ──────────────────────────────────────────────────────────

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isOnline ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Large circular power button used by light, plug, etc.
class _PowerButton extends StatelessWidget {
  const _PowerButton({
    required this.isOn,
    required this.onTap,
    required this.icon,
    this.size = 100,
    this.activeColor,
    this.glowColor,
  });
  final bool isOn;
  final VoidCallback onTap;
  final IconData icon;
  final double size;
  final Color? activeColor;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOn
              ? color.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isOn ? color : Colors.grey.shade300,
            width: 3,
          ),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: (glowColor ?? color).withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: size * 0.4,
          color: isOn ? color : Colors.grey.shade400,
        ),
      ),
    );
  }
}

/// Card with icon, label, and value — used in sensor/info grids.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.iconColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primaryContainer;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: iconColor ?? Theme.of(context).colorScheme.primary),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal info row for detail sections.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIGHT
// ═══════════════════════════════════════════════════════════════════════════════

class _LightControl extends StatefulWidget {
  const _LightControl({required this.telemetry, required this.onRpc});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;
  @override
  State<_LightControl> createState() => _LightControlState();
}

class _LightControlState extends State<_LightControl> {
  late double _dim, _h, _s, _l;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_LightControl old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    _dim = _num('dim', 100).clamp(0, 100);
    _h = _num('h', 30).clamp(0, 360);
    _s = _num('s', 80).clamp(0, 100);
    _l = _num('l', 50).clamp(0, 100);
  }

  double _num(String k, double fallback) =>
      (widget.telemetry[k] as num?)?.toDouble() ?? fallback;

  bool get _isOn => widget.telemetry['onoff0'] == 1;

  Color get _currentColor =>
      HSLColor.fromAHSL(1, _h, _s / 100, _l / 100).toColor();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 16),
        // ── Power button ──
        Center(
          child: _PowerButton(
            isOn: _isOn,
            icon: Icons.lightbulb_rounded,
            onTap: () => widget.onRpc('toggle', {}),
            activeColor: _currentColor,
            glowColor: _currentColor,
            size: 120,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _isOn ? 'Bật  ${_dim.round()}%' : 'Tắt',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _isOn ? null : Colors.grey,
                ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Brightness ──
        _SliderSection(
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

        // ── Hue ──
        _SliderSection(
          icon: Icons.palette,
          label: 'Màu sắc',
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

        // ── Saturation ──
        _SliderSection(
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

        // ── Lightness ──
        _SliderSection(
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

        // ── Color preview ──
        const SizedBox(height: 20),
        Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _currentColor,
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),

        // ── Power info ──
        if (widget.telemetry['power'] != null) ...[
          const SizedBox(height: 20),
          _DetailRow(
            icon: Icons.bolt,
            label: 'Công suất',
            value: '${widget.telemetry['power']} W',
          ),
        ],
      ],
    );
  }
}

class _SliderSection extends StatelessWidget {
  const _SliderSection({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.divisions,
    this.activeColor,
  });
  final IconData icon;
  final String label;
  final String valueLabel;
  final double value, min, max;
  final int? divisions;
  final Color? activeColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: activeColor,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AIR CONDITIONER
// ═══════════════════════════════════════════════════════════════════════════════

class _AcControl extends StatefulWidget {
  const _AcControl({required this.telemetry, required this.onRpc});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;
  @override
  State<_AcControl> createState() => _AcControlState();
}

class _AcControlState extends State<_AcControl> {
  static const _modes = [
    ('cool', Icons.ac_unit, 'Lạnh'),
    ('heat', Icons.whatshot, 'Nóng'),
    ('auto', Icons.autorenew, 'Tự động'),
    ('dry', Icons.water_drop_outlined, 'Hút ẩm'),
    ('fan', Icons.air, 'Quạt'),
  ];

  late double _temp;

  @override
  void initState() {
    super.initState();
    _temp = ((widget.telemetry['temp'] as num?)?.toDouble() ?? 25).clamp(16, 30);
  }

  @override
  void didUpdateWidget(_AcControl old) {
    super.didUpdateWidget(old);
    final t = (widget.telemetry['temp'] as num?)?.toDouble();
    if (t != null) _temp = t.clamp(16, 30);
  }

  bool get _isOn => widget.telemetry['power'] == 1;
  String get _mode => widget.telemetry['mode'] as String? ?? 'cool';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        // ── Power + temp display ──
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isOn
                  ? [cs.primaryContainer, cs.primary.withValues(alpha: 0.1)]
                  : [Colors.grey.shade100, Colors.grey.shade50],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isOn ? 'Đang hoạt động' : 'Đã tắt',
                    style: TextStyle(
                      color: _isOn ? cs.primary : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Switch.adaptive(
                    value: _isOn,
                    onChanged: (_) => widget.onRpc('toggle', {}),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Temperature with +/- buttons
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
                  const SizedBox(width: 24),
                  Text(
                    '${_temp.round()}',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w300,
                          color: _isOn ? cs.primary : Colors.grey,
                        ),
                  ),
                  Text(
                    '°C',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: _isOn ? cs.primary : Colors.grey,
                        ),
                  ),
                  const SizedBox(width: 24),
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
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Mode selector ──
        Text('Chế độ', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _modes.map((m) {
            final selected = _mode == m.$1;
            return GestureDetector(
              onTap: () => widget.onRpc('setMode', {'mode': m.$1}),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? cs.primary.withValues(alpha: 0.15)
                          : Colors.grey.shade100,
                      border: Border.all(
                        color: selected ? cs.primary : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      m.$2,
                      color: selected ? cs.primary : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.$3,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? cs.primary : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // ── Info cards ──
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            if (widget.telemetry['hum'] != null)
              _InfoCard(
                icon: Icons.water_drop,
                label: 'Độ ẩm',
                value: '${widget.telemetry['hum']}%',
                iconColor: Colors.blue,
                color: Colors.blue.shade50,
              ),
            if (widget.telemetry['power'] != null)
              _InfoCard(
                icon: Icons.bolt,
                label: 'Công suất',
                value: '${widget.telemetry['power']} W',
                iconColor: Colors.orange,
                color: Colors.orange.shade50,
              ),
            if (widget.telemetry['energy'] != null)
              _InfoCard(
                icon: Icons.electric_meter,
                label: 'Điện năng',
                value: '${widget.telemetry['energy']} kWh',
                iconColor: Colors.green,
                color: Colors.green.shade50,
              ),
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
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: onTap != null ? Colors.black87 : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SMART PLUG
// ═══════════════════════════════════════════════════════════════════════════════

class _SmartPlugControl extends StatelessWidget {
  const _SmartPlugControl({required this.telemetry, required this.onRpc});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  bool get _isOn => telemetry['onoff0'] == 1;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 24),
        Center(
          child: _PowerButton(
            isOn: _isOn,
            icon: Icons.power_settings_new,
            onTap: () => onRpc('toggle', {}),
            size: 120,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _isOn ? 'Bật' : 'Tắt',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _isOn ? null : Colors.grey,
                ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Power monitoring grid ──
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _InfoCard(
              icon: Icons.bolt,
              label: 'Công suất',
              value: telemetry['power'] != null ? '${telemetry['power']} W' : '--',
              iconColor: Colors.orange,
              color: Colors.orange.shade50,
            ),
            _InfoCard(
              icon: Icons.electric_meter,
              label: 'Điện năng',
              value: telemetry['energy'] != null
                  ? '${telemetry['energy']} kWh'
                  : '--',
              iconColor: Colors.green,
              color: Colors.green.shade50,
            ),
            _InfoCard(
              icon: Icons.electrical_services,
              label: 'Điện áp',
              value: telemetry['volt'] != null ? '${telemetry['volt']} V' : '--',
              iconColor: Colors.blue,
              color: Colors.blue.shade50,
            ),
            _InfoCard(
              icon: Icons.speed,
              label: 'Dòng điện',
              value: telemetry['curr'] != null ? '${telemetry['curr']} A' : '--',
              iconColor: Colors.purple,
              color: Colors.purple.shade50,
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CURTAIN
// ═══════════════════════════════════════════════════════════════════════════════

class _CurtainControl extends StatefulWidget {
  const _CurtainControl({required this.telemetry, required this.onRpc});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;
  @override
  State<_CurtainControl> createState() => _CurtainControlState();
}

class _CurtainControlState extends State<_CurtainControl> {
  late double _pos;

  @override
  void initState() {
    super.initState();
    _pos = ((widget.telemetry['pos'] as num?)?.toDouble() ?? 0).clamp(0, 100);
  }

  @override
  void didUpdateWidget(_CurtainControl old) {
    super.didUpdateWidget(old);
    final p = (widget.telemetry['pos'] as num?)?.toDouble();
    if (p != null) setState(() => _pos = p.clamp(0, 100));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 16),

        // ── Visual curtain ──
        Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: _CurtainPainter(
                position: _pos / 100,
                color: cs.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '${_pos.round()}%',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
          ),
        ),
        Center(
          child: Text(
            _pos == 100
                ? 'Mở hoàn toàn'
                : _pos == 0
                    ? 'Đóng hoàn toàn'
                    : 'Đang mở ${_pos.round()}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Slider ──
        SliderTheme(
          data: const SliderThemeData(trackHeight: 8),
          child: Slider(
            value: _pos,
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: (v) => setState(() => _pos = v),
            onChangeEnd: (v) =>
                widget.onRpc('setPosition', {'pos': v.round()}),
          ),
        ),
        const SizedBox(height: 24),

        // ── Control buttons ──
        Row(
          children: [
            Expanded(
              child: _CurtainButton(
                icon: Icons.keyboard_double_arrow_up,
                label: 'Mở',
                color: cs.primary,
                onTap: () => widget.onRpc('open', {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CurtainButton(
                icon: Icons.stop_rounded,
                label: 'Dừng',
                color: Colors.orange,
                onTap: () => widget.onRpc('stop', {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CurtainButton(
                icon: Icons.keyboard_double_arrow_down,
                label: 'Đóng',
                color: Colors.grey.shade700,
                onTap: () => widget.onRpc('close', {}),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CurtainButton extends StatelessWidget {
  const _CurtainButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurtainPainter extends CustomPainter {
  _CurtainPainter({required this.position, required this.color});
  final double position; // 0 = closed, 1 = open
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rod = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Rod
    canvas.drawLine(
      Offset(10, 8),
      Offset(size.width - 10, 8),
      rod,
    );

    // Curtain panels
    final curtainPaint = Paint()..color = color.withValues(alpha: 0.25);
    final curtainBorder = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final openW = size.width * 0.5 * position;
    final leftRect =
        Rect.fromLTWH(0, 12, size.width * 0.5 - openW, size.height - 12);
    final rightRect = Rect.fromLTWH(
        size.width * 0.5 + openW, 12, size.width * 0.5 - openW, size.height - 12);

    final radius = const Radius.circular(4);
    if (leftRect.width > 0) {
      canvas.drawRRect(RRect.fromRectAndRadius(leftRect, radius), curtainPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(leftRect, radius), curtainBorder);
    }
    if (rightRect.width > 0) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(rightRect, radius), curtainPaint);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rightRect, radius), curtainBorder);
    }

    // Window light (background)
    if (position > 0.05) {
      final lightPaint = Paint()
        ..color = Colors.amber.withValues(alpha: 0.15 * position);
      canvas.drawRect(
        Rect.fromLTWH(
            size.width * 0.5 - openW, 12, openW * 2, size.height - 12),
        lightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CurtainPainter old) => old.position != position;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOOR SENSOR
// ═══════════════════════════════════════════════════════════════════════════════

class _DoorSensorView extends StatelessWidget {
  const _DoorSensorView({required this.telemetry});
  final Map<String, dynamic> telemetry;

  bool get _isClosed {
    final v = telemetry['door'];
    return v == true || v == 1 || v == 'true';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 32),
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isClosed
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              border: Border.all(
                color: _isClosed ? Colors.green : Colors.red,
                width: 3,
              ),
            ),
            child: Icon(
              _isClosed ? Icons.lock_outline : Icons.lock_open,
              size: 56,
              color: _isClosed ? Colors.green : Colors.red,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _isClosed ? 'Cửa đóng' : 'Cửa mở',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _isClosed ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 32),
        if (telemetry['pin'] != null)
          _BatteryIndicator(level: (telemetry['pin'] as num).toDouble()),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOTION SENSOR
// ═══════════════════════════════════════════════════════════════════════════════

class _MotionSensorView extends StatelessWidget {
  const _MotionSensorView({required this.telemetry});
  final Map<String, dynamic> telemetry;

  bool get _detected => telemetry['pir'] == 1 || telemetry['pir'] == true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 32),
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _detected
                  ? Colors.orange.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.08),
            ),
            child: Icon(
              _detected
                  ? Icons.directions_walk
                  : Icons.motion_photos_off_outlined,
              size: 56,
              color: _detected ? Colors.orange : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _detected ? 'Phát hiện chuyển động' : 'Không có chuyển động',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _detected ? Colors.orange.shade800 : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Sensor data ──
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            if (telemetry['lux'] != null)
              _InfoCard(
                icon: Icons.light_mode,
                label: 'Ánh sáng',
                value: '${telemetry['lux']} lux',
                iconColor: Colors.amber,
                color: Colors.amber.shade50,
              ),
            if (telemetry['pin'] != null)
              _InfoCard(
                icon: Icons.battery_std,
                label: 'Pin',
                value: '${telemetry['pin']}%',
                iconColor: Colors.green,
                color: Colors.green.shade50,
              ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEMP & HUMIDITY
// ═══════════════════════════════════════════════════════════════════════════════

class _TempHumView extends StatelessWidget {
  const _TempHumView({required this.telemetry});
  final Map<String, dynamic> telemetry;

  @override
  Widget build(BuildContext context) {
    final temp = (telemetry['temp'] as num?)?.toDouble();
    final hum = (telemetry['hum'] as num?)?.toDouble();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 16),
        // ── Temperature gauge ──
        if (temp != null) ...[
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: CustomPaint(
                painter: _GaugePainter(
                  value: temp,
                  min: -10,
                  max: 50,
                  color: _tempColor(temp),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${temp.toStringAsFixed(1)}',
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _tempColor(temp),
                            ),
                      ),
                      Text(
                        '°C',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _tempLabel(temp),
              style: TextStyle(color: _tempColor(temp), fontWeight: FontWeight.w500),
            ),
          ),
        ],
        const SizedBox(height: 24),

        // ── Humidity + battery ──
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            if (hum != null)
              _InfoCard(
                icon: Icons.water_drop,
                label: 'Độ ẩm',
                value: '${hum.toStringAsFixed(0)}%',
                iconColor: Colors.blue,
                color: Colors.blue.shade50,
              ),
            if (telemetry['pin'] != null)
              _InfoCard(
                icon: Icons.battery_std,
                label: 'Pin',
                value: '${telemetry['pin']}%',
                iconColor: Colors.green,
                color: Colors.green.shade50,
              ),
          ],
        ),
      ],
    );
  }

  Color _tempColor(double t) {
    if (t < 10) return Colors.blue;
    if (t < 20) return Colors.cyan;
    if (t < 28) return Colors.green;
    if (t < 35) return Colors.orange;
    return Colors.red;
  }

  String _tempLabel(double t) {
    if (t < 10) return 'Rất lạnh';
    if (t < 20) return 'Mát';
    if (t < 28) return 'Thoải mái';
    if (t < 35) return 'Nóng';
    return 'Rất nóng';
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.color,
  });
  final double value, min, max;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const startAngle = 2.4; // ~137°
    const sweepTotal = 4.0; // ~230° arc

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    // Value arc
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal * fraction,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GATEWAY
// ═══════════════════════════════════════════════════════════════════════════════

class _GatewayView extends StatelessWidget {
  const _GatewayView({required this.telemetry});
  final Map<String, dynamic> telemetry;

  @override
  Widget build(BuildContext context) {
    final cpu = (telemetry['cpu'] as num?)?.toDouble();
    final mem = (telemetry['mem'] as num?)?.toDouble();
    final uptime = telemetry['uptime'] as num?;
    final devCnt = telemetry['dev_cnt'];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Icon(
            Icons.router_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _InfoCard(
              icon: Icons.memory,
              label: 'CPU',
              value: cpu != null ? '${cpu.toStringAsFixed(0)}%' : '--',
              iconColor: Colors.blue,
              color: Colors.blue.shade50,
            ),
            _InfoCard(
              icon: Icons.storage,
              label: 'RAM',
              value: mem != null ? '${mem.toStringAsFixed(0)}%' : '--',
              iconColor: Colors.purple,
              color: Colors.purple.shade50,
            ),
            _InfoCard(
              icon: Icons.timer_outlined,
              label: 'Uptime',
              value: uptime != null ? _fmtUptime(uptime.toInt()) : '--',
              iconColor: Colors.green,
              color: Colors.green.shade50,
            ),
            _InfoCard(
              icon: Icons.devices,
              label: 'Thiết bị',
              value: devCnt?.toString() ?? '--',
              iconColor: Colors.orange,
              color: Colors.orange.shade50,
            ),
          ],
        ),
      ],
    );
  }

  String _fmtUptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
    return '${seconds ~/ 86400}d ${(seconds % 86400) ~/ 3600}h';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATTERY INDICATOR
// ═══════════════════════════════════════════════════════════════════════════════

class _BatteryIndicator extends StatelessWidget {
  const _BatteryIndicator({required this.level});
  final double level;

  @override
  Widget build(BuildContext context) {
    final color = level > 50
        ? Colors.green
        : level > 20
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            level > 80
                ? Icons.battery_full
                : level > 50
                    ? Icons.battery_5_bar
                    : level > 20
                        ? Icons.battery_3_bar
                        : Icons.battery_1_bar,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text('Pin', style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            '${level.round()}%',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GENERIC
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// SWITCH (multi-gang, e.g. TS0601 4-button)
// ═══════════════════════════════════════════════════════════════════════════════

class _SwitchControl extends StatelessWidget {
  const _SwitchControl({required this.telemetry, required this.onRpc});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  static const _defaultNames = ['Công tắc 1', 'Công tắc 2', 'Công tắc 3', 'Công tắc 4'];
  static const _icons = [
    Icons.lightbulb_outline,
    Icons.lightbulb_outline,
    Icons.lightbulb_outline,
    Icons.lightbulb_outline,
  ];

  /// Resolves the list of telemetry keys for each gang.
  /// Pattern: bt, bt2, bt3, bt4, ...
  List<String> get _gangKeys {
    final keys = <String>[];
    if (telemetry.containsKey('bt')) {
      keys.add('bt');
      for (int i = 2; telemetry.containsKey('bt$i'); i++) {
        keys.add('bt$i');
      }
    }
    return keys.isNotEmpty ? keys : ['bt', 'bt2', 'bt3', 'bt4'];
  }

  int get _gangCount => _gangKeys.length;

  bool _isOn(int index) {
    final v = telemetry[_gangKeys[index]];
    return v == 1 || v == '1' || v == true;
  }

  bool get _allOn {
    for (int i = 0; i < _gangCount; i++) {
      if (!_isOn(i)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final gangs = _gangCount;
    final cs = Theme.of(context).colorScheme;
    final anyOn = List.generate(gangs, _isOn).any((v) => v);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── Master power button ──
        const SizedBox(height: 16),
        Center(
          child: _PowerButton(
            isOn: anyOn,
            icon: Icons.power_settings_new,
            size: 90,
            activeColor: cs.primary,
            onTap: () {
              final target = _allOn ? 0 : 1;
              final keys = _gangKeys;
              final data = <String, dynamic>{};
              for (final key in keys) {
                data[key] = target;
              }
              onRpc('setValue', data);
            },
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            _allOn
                ? 'Tất cả bật'
                : anyOn
                    ? 'Một số đang bật'
                    : 'Tất cả tắt',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: anyOn ? cs.primary : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        const SizedBox(height: 28),

        // ── Individual gang switches ──
        ...List.generate(gangs, (i) {
          final on = _isOn(i);
          final name = i < _defaultNames.length ? _defaultNames[i] : 'Công tắc ${i + 1}';
          final icon = i < _icons.length ? _icons[i] : Icons.lightbulb_outline;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: on
                  ? cs.primaryContainer.withValues(alpha: 0.5)
                  : Colors.grey.shade100,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onRpc('setValue', {_gangKeys[i]: on ? 0 : 1}),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      // Icon circle
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: on
                              ? cs.primary.withValues(alpha: 0.15)
                              : Colors.grey.shade200,
                        ),
                        child: Icon(
                          icon,
                          color: on ? cs.primary : Colors.grey,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Name + status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              on ? 'Đang bật' : 'Đã tắt',
                              style: TextStyle(
                                fontSize: 13,
                                color: on ? cs.primary : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Toggle switch
                      Switch(
                        value: on,
                        activeColor: cs.primary,
                        onChanged: (_) =>
                            onRpc('setValue', {_gangKeys[i]: on ? 0 : 1}),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 12),

        // ── Power info if available ──
        if (telemetry['power'] != null || telemetry['energy'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                if (telemetry['power'] != null)
                  _InfoCard(
                    icon: Icons.bolt,
                    label: 'Công suất',
                    value: '${telemetry['power']} W',
                    iconColor: Colors.orange,
                    color: Colors.orange.shade50,
                  ),
                if (telemetry['energy'] != null)
                  _InfoCard(
                    icon: Icons.electric_meter,
                    label: 'Điện năng',
                    value: '${telemetry['energy']} kWh',
                    iconColor: Colors.green,
                    color: Colors.green.shade50,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GenericView extends StatelessWidget {
  const _GenericView({required this.telemetry});
  final Map<String, dynamic> telemetry;

  @override
  Widget build(BuildContext context) {
    final entries = telemetry.entries
        .where((e) => e.key != 'active' && e.key != 'stt')
        .toList();
    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices_other, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('Chưa có dữ liệu telemetry'),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: entries
          .map((e) => _DetailRow(
                icon: Icons.data_usage,
                label: e.key,
                value: '${e.value}',
              ))
          .toList(),
    );
  }
}
