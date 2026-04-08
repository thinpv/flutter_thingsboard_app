import 'dart:async';

import 'package:flutter/material.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

class DeviceDetailPage extends StatefulWidget {
  const DeviceDetailPage({required this.device, super.key});

  final SmarthomeDevice device;

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  late Map<String, dynamic> _telemetry;
  TelemetrySubscriber? _subscriber;
  final _control = DeviceControlService();

  @override
  void initState() {
    super.initState();
    _telemetry = Map.from(widget.device.telemetry);
    _subscriber = _control.subscribeToLatestTelemetry(widget.device.id);
    _subscriber!.attributeDataStream.listen((attrs) {
      if (mounted) {
        setState(() {
          for (final a in attrs) {
            _telemetry[a.key] = a.value;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _subscriber?.unsubscribe();
    super.dispose();
  }

  Future<void> _rpc(String method, Map<String, dynamic> params) async {
    await _control.sendOneWayRpc(widget.device.id, method, params);
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device.copyWith(telemetry: _telemetry);
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (_telemetry['stt'] == 1)
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  (_telemetry['stt'] == 1) ? 'Online' : 'Offline',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(device),
    );
  }

  Widget _buildBody(SmarthomeDevice device) {
    return switch (device.type) {
      'light' => _LightControl(
          telemetry: _telemetry,
          onRpc: _rpc,
        ),
      'air_conditioner' => _AcControl(
          telemetry: _telemetry,
          onRpc: _rpc,
        ),
      'smart_plug' => _SmartPlugControl(
          telemetry: _telemetry,
          onRpc: _rpc,
        ),
      'curtain' => _CurtainControl(
          telemetry: _telemetry,
          onRpc: _rpc,
        ),
      'door_sensor' || 'motion_sensor' || 'temp_humidity' => _SensorView(
          telemetry: _telemetry,
          deviceType: device.type,
        ),
      _ => _GenericView(telemetry: _telemetry),
    };
  }
}

// ─── Light Control ────────────────────────────────────────────────────────────

class _LightControl extends StatefulWidget {
  const _LightControl({required this.telemetry, required this.onRpc});

  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  @override
  State<_LightControl> createState() => _LightControlState();
}

class _LightControlState extends State<_LightControl> {
  late double _dim;
  late double _h, _s, _l;

  @override
  void didUpdateWidget(_LightControl old) {
    super.didUpdateWidget(old);
    _syncFromTelemetry();
  }

  @override
  void initState() {
    super.initState();
    _syncFromTelemetry();
  }

  void _syncFromTelemetry() {
    _dim = ((widget.telemetry['dim'] as num?)?.toDouble() ?? 100.0)
        .clamp(0.0, 100.0);
    _h = ((widget.telemetry['h'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 360.0);
    _s = ((widget.telemetry['s'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 100.0);
    _l = ((widget.telemetry['l'] as num?)?.toDouble() ?? 50.0).clamp(0.0, 100.0);
  }

  bool get _isOn => widget.telemetry['onoff0'] == 1;

  @override
  Widget build(BuildContext context) {
    final color = HSLColor.fromAHSL(1, _h, _s / 100, _l / 100).toColor();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Power toggle
        Center(
          child: GestureDetector(
            onTap: () => widget.onRpc('toggle', {}),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: _isOn
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.lightbulb,
                size: 48,
                color: _isOn
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _isOn ? 'Bật' : 'Tắt',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 32),

        // Dimmer
        Text('Độ sáng: ${_dim.round()}%',
            style: Theme.of(context).textTheme.labelLarge),
        Slider(
          value: _dim,
          min: 0,
          max: 100,
          divisions: 20,
          label: '${_dim.round()}%',
          onChanged: (v) => setState(() => _dim = v),
          onChangeEnd: (v) =>
              widget.onRpc('setValue', {'dim': v.round()}),
        ),
        const SizedBox(height: 16),

        // Hue
        Text('Màu sắc (H): ${_h.round()}°',
            style: Theme.of(context).textTheme.labelLarge),
        Slider(
          value: _h,
          min: 0,
          max: 360,
          divisions: 36,
          onChanged: (v) => setState(() => _h = v),
          onChangeEnd: (v) => widget.onRpc(
              'setValue', {'h': v.round(), 's': _s.round(), 'l': _l.round()}),
          activeColor:
              HSLColor.fromAHSL(1, _h, 1, 0.5).toColor(),
        ),

        // Saturation
        Text('Bão hòa (S): ${_s.round()}%',
            style: Theme.of(context).textTheme.labelLarge),
        Slider(
          value: _s,
          min: 0,
          max: 100,
          onChanged: (v) => setState(() => _s = v),
          onChangeEnd: (v) => widget.onRpc(
              'setValue', {'h': _h.round(), 's': v.round(), 'l': _l.round()}),
        ),

        // Lightness
        Text('Độ sáng màu (L): ${_l.round()}%',
            style: Theme.of(context).textTheme.labelLarge),
        Slider(
          value: _l,
          min: 0,
          max: 100,
          onChanged: (v) => setState(() => _l = v),
          onChangeEnd: (v) => widget.onRpc(
              'setValue', {'h': _h.round(), 's': _s.round(), 'l': v.round()}),
        ),

        const SizedBox(height: 16),
        // Power telemetry
        if (widget.telemetry['power'] != null)
          _TelemetryRow(
              label: 'Công suất', value: '${widget.telemetry['power']} W'),
      ],
    );
  }
}

// ─── Air Conditioner Control ──────────────────────────────────────────────────

class _AcControl extends StatefulWidget {
  const _AcControl({required this.telemetry, required this.onRpc});

  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  @override
  State<_AcControl> createState() => _AcControlState();
}

class _AcControlState extends State<_AcControl> {
  static const _modes = ['cool', 'heat', 'auto', 'dry', 'fan'];
  static const _modeLabels = {
    'cool': 'Lạnh',
    'heat': 'Nóng',
    'auto': 'Tự động',
    'dry': 'Hút ẩm',
    'fan': 'Quạt',
  };
  late double _temp;

  @override
  void initState() {
    super.initState();
    _temp = ((widget.telemetry['temp'] as num?)?.toDouble() ?? 25.0)
        .clamp(16.0, 30.0);
  }

  @override
  void didUpdateWidget(_AcControl old) {
    super.didUpdateWidget(old);
    final t = (widget.telemetry['temp'] as num?)?.toDouble();
    if (t != null) _temp = t.clamp(16.0, 30.0);
  }

  bool get _isOn => widget.telemetry['power'] == 1;

  @override
  Widget build(BuildContext context) {
    final mode = widget.telemetry['mode'] as String? ?? 'cool';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Power toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Điều hòa', style: Theme.of(context).textTheme.titleLarge),
            Switch.adaptive(
              value: _isOn,
              onChanged: (_) => widget.onRpc('toggle', {}),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Temperature
        Center(
          child: Text(
            '${_temp.round()}°C',
            style: Theme.of(context)
                .textTheme
                .displayMedium
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        Slider(
          value: _temp,
          min: 16,
          max: 30,
          divisions: 14,
          label: '${_temp.round()}°C',
          onChanged: (v) => setState(() => _temp = v),
          onChangeEnd: (v) =>
              widget.onRpc('setTemp', {'temp': v.round()}),
        ),
        const SizedBox(height: 16),

        // Mode
        Text('Chế độ', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _modes.map((m) {
            return ChoiceChip(
              label: Text(_modeLabels[m] ?? m),
              selected: mode == m,
              onSelected: (_) =>
                  widget.onRpc('setMode', {'mode': m}),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Telemetry
        if (widget.telemetry['hum'] != null)
          _TelemetryRow(
              label: 'Độ ẩm phòng',
              value: '${widget.telemetry['hum']}%'),
        if (widget.telemetry['energy'] != null)
          _TelemetryRow(
              label: 'Điện năng',
              value: '${widget.telemetry['energy']} kWh'),
        if (widget.telemetry['power'] != null)
          _TelemetryRow(
              label: 'Công suất',
              value: '${widget.telemetry['power']} W'),
      ],
    );
  }
}

// ─── Smart Plug Control ───────────────────────────────────────────────────────

class _SmartPlugControl extends StatelessWidget {
  const _SmartPlugControl({required this.telemetry, required this.onRpc});

  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  bool get _isOn => telemetry['onoff0'] == 1;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: GestureDetector(
            onTap: () => onRpc('toggle', {}),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: _isOn
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.electrical_services,
                size: 40,
                color: _isOn
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _isOn ? 'Bật' : 'Tắt',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 32),
        _TelemetryRow(
            label: 'Điện áp',
            value: telemetry['volt'] != null
                ? '${telemetry['volt']} V'
                : '—'),
        _TelemetryRow(
            label: 'Dòng điện',
            value: telemetry['curr'] != null
                ? '${telemetry['curr']} A'
                : '—'),
        _TelemetryRow(
            label: 'Công suất',
            value: telemetry['power'] != null
                ? '${telemetry['power']} W'
                : '—'),
        _TelemetryRow(
            label: 'Điện năng tích lũy',
            value: telemetry['energy'] != null
                ? '${telemetry['energy']} kWh'
                : '—'),
      ],
    );
  }
}

// ─── Curtain Control ──────────────────────────────────────────────────────────

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
    _pos = ((widget.telemetry['pos'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 100.0);
  }

  @override
  void didUpdateWidget(_CurtainControl old) {
    super.didUpdateWidget(old);
    final p = (widget.telemetry['pos'] as num?)?.toDouble();
    if (p != null) setState(() => _pos = p.clamp(0.0, 100.0));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Icon(
            Icons.blinds,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '${_pos.round()}%',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Slider(
          value: _pos,
          min: 0,
          max: 100,
          divisions: 20,
          label: '${_pos.round()}%',
          onChanged: (v) => setState(() => _pos = v),
          onChangeEnd: (v) =>
              widget.onRpc('setPosition', {'pos': v.round()}),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.arrow_upward),
              label: const Text('Mở'),
              onPressed: () => widget.onRpc('open', {}),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Dừng'),
              onPressed: () => widget.onRpc('stop', {}),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.arrow_downward),
              label: const Text('Đóng'),
              onPressed: () => widget.onRpc('close', {}),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Sensor View (read-only) ──────────────────────────────────────────────────

class _SensorView extends StatelessWidget {
  const _SensorView({required this.telemetry, required this.deviceType});

  final Map<String, dynamic> telemetry;
  final String deviceType;

  @override
  Widget build(BuildContext context) {
    final rows = _rowsFor(deviceType);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Icon(
            _iconFor(deviceType),
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        ...rows.map((entry) => _TelemetryRow(
              label: entry.$1,
              value: telemetry[entry.$2] != null
                  ? '${telemetry[entry.$2]}${entry.$3}'
                  : '—',
            )),
      ],
    );
  }

  List<(String, String, String)> _rowsFor(String type) => switch (type) {
        'door_sensor' => [
            ('Cửa', 'door', ''),
            ('Pin', 'pin', '%'),
          ],
        'motion_sensor' => [
            ('Chuyển động', 'pir', ''),
            ('Ánh sáng', 'lux', ' lux'),
            ('Pin', 'pin', '%'),
          ],
        _ => [
            ('Nhiệt độ', 'temp', '°C'),
            ('Độ ẩm', 'hum', '%'),
            ('Pin', 'pin', '%'),
          ],
      };

  IconData _iconFor(String type) => switch (type) {
        'door_sensor' => Icons.sensor_door_outlined,
        'motion_sensor' => Icons.motion_photos_on_outlined,
        _ => Icons.thermostat,
      };
}

// ─── Generic View ────────────────────────────────────────────────────────────

class _GenericView extends StatelessWidget {
  const _GenericView({required this.telemetry});

  final Map<String, dynamic> telemetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: telemetry.entries.map((e) {
        return _TelemetryRow(label: e.key, value: '${e.value}');
      }).toList(),
    );
  }
}

// ─── Shared: Telemetry Row ────────────────────────────────────────────────────

class _TelemetryRow extends StatelessWidget {
  const _TelemetryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}
