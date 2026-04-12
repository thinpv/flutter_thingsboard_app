import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/scene.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/scene_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/scene_service.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kIconOptions = [
  ('auto_awesome', Icons.auto_awesome, 'Tuỳ chọn'),
  ('home', Icons.home_outlined, 'Về nhà'),
  ('nights_stay', Icons.nights_stay, 'Ngủ'),
  ('wb_sunny', Icons.wb_sunny, 'Thức dậy'),
  ('local_movies', Icons.local_movies, 'Xem phim'),
  ('restaurant', Icons.restaurant, 'Ăn uống'),
  ('bedtime', Icons.bedtime, 'Nghỉ ngơi'),
  ('fitness_center', Icons.fitness_center, 'Vận động'),
  ('security', Icons.security, 'An ninh'),
  ('lightbulb', Icons.lightbulb_outline, 'Ánh sáng'),
];

const _kColorOptions = [
  '#2196F3', '#FF9800', '#4CAF50', '#E91E63',
  '#9C27B0', '#FF5722', '#607D8B', '#00BCD4',
];

// ─── Icon data resolver ───────────────────────────────────────────────────────

IconData _iconFromName(String name) => switch (name) {
      'home' => Icons.home_outlined,
      'nights_stay' => Icons.nights_stay,
      'wb_sunny' => Icons.wb_sunny,
      'local_movies' => Icons.local_movies,
      'restaurant' => Icons.restaurant,
      'bedtime' => Icons.bedtime,
      'fitness_center' => Icons.fitness_center,
      'security' => Icons.security,
      'lightbulb' => Icons.lightbulb_outline,
      _ => Icons.auto_awesome,
    };

Color _hexColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
  } catch (_) {
    return Colors.blue;
  }
}

IconData _deviceIconFor(String uiType) => switch (uiType) {
      'light' => Icons.lightbulb_outline,
      'air_conditioner' => Icons.ac_unit,
      'smart_plug' => Icons.electrical_services,
      'curtain' => Icons.blinds,
      'door_sensor' => Icons.sensor_door_outlined,
      'motion_sensor' => Icons.motion_photos_on_outlined,
      'temp_humidity' => Icons.thermostat,
      'camera' => Icons.videocam_outlined,
      'gateway' => Icons.router_outlined,
      'switch' => Icons.toggle_on_outlined,
      'lock' => Icons.lock_outline,
      'smoke_sensor' => Icons.local_fire_department_outlined,
      'electrical_switch' => Icons.power_settings_new,
      _ => Icons.devices_other,
    };

/// Short human-readable summary of device state.
String _stateLabel(Map<String, dynamic> state, String uiType) {
  final isOn = state['onoff0'] != 0 && state['onoff0'] != false;
  final base = isOn ? 'Bật' : 'Tắt';
  if (uiType == 'light') {
    final dim = (state['dim'] as num?)?.toInt();
    if (dim != null) return '$base · $dim%';
    return base;
  }
  if (uiType == 'air_conditioner') {
    final sp = state['cool_sp'];
    final mode = state['mode'];
    final parts = <String>[base];
    if (mode != null) parts.add('$mode');
    if (sp != null) parts.add('$sp°C');
    return parts.join(' · ');
  }
  if (uiType == 'curtain') {
    final pos = (state['pos'] as num?)?.toInt();
    if (pos != null) return 'Vị trí $pos%';
    return base;
  }
  return base;
}

// ─── Main page ────────────────────────────────────────────────────────────────

class SceneEditPage extends ConsumerStatefulWidget {
  const SceneEditPage({this.scene, super.key});

  final SmarthomeScene? scene;

  @override
  ConsumerState<SceneEditPage> createState() => _SceneEditPageState();
}

class _SceneEditPageState extends ConsumerState<SceneEditPage> {
  final _nameCtrl = TextEditingController();
  String _icon = 'auto_awesome';
  String _color = '#2196F3';

  /// deviceId → target state
  late Map<String, Map<String, dynamic>> _devices;

  /// deviceId → full device object (for name + uiType)
  final Map<String, SmarthomeDevice> _deviceInfo = {};

  bool _saving = false;
  bool _loadingDevices = false;

  @override
  void initState() {
    super.initState();
    final s = widget.scene;
    if (s != null) {
      _nameCtrl.text = s.name;
      _icon = s.icon;
      _color = s.color;
      _devices = Map.from(s.devices.map((k, v) => MapEntry(k, Map.from(v))));
      _resolveDeviceInfo();
    } else {
      _devices = {};
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolveDeviceInfo() async {
    if (_devices.isEmpty) return;
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return;
    try {
      final svc = HomeService();
      final rooms = await svc.fetchRooms(home.id);
      for (final room in rooms) {
        final devs = await resolveDeviceProfileMetaFromCache(
            await svc.fetchDevicesInRoom(room.id));
        for (final d in devs) {
          if (_devices.containsKey(d.id)) {
            if (mounted) setState(() => _deviceInfo[d.id] = d);
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.scene != null;
    final accent = _hexColor(_color);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(isEdit ? 'Sửa kịch bản' : 'Tạo kịch bản'),
        centerTitle: true,
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Xóa',
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                minimumSize: const Size(0, 36),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Lưu'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Scene hero card ─────────────────────────────────────────────────
          _SceneHeroCard(
            icon: _icon,
            color: _color,
            nameCtrl: _nameCtrl,
            onIconTap: _pickIcon,
            onColorTap: _pickColor,
          ),
          const SizedBox(height: 20),

          // ── Actions section ─────────────────────────────────────────────────
          _SectionHeader(
            label: 'HÀNH ĐỘNG',
            badge: _devices.isEmpty ? null : '${_devices.length}',
          ),
          const SizedBox(height: 8),

          if (_devices.isEmpty)
            _EmptyActionsPlaceholder(onAdd: _addDevice)
          else ...[
            for (final entry in _devices.entries)
              _DeviceActionCard(
                deviceId: entry.key,
                state: entry.value,
                device: _deviceInfo[entry.key],
                onEdit: () => _editDeviceState(entry.key, entry.value),
                onRemove: () => setState(() => _devices.remove(entry.key)),
              ),
            const SizedBox(height: 4),
            _AddDeviceButton(onTap: _addDevice),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Pickers ──────────────────────────────────────────────────────────────────

  Future<void> _pickIcon() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IconPickerSheet(current: _icon),
    );
    if (picked != null) setState(() => _icon = picked);
  }

  Future<void> _pickColor() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ColorPickerSheet(current: _color),
    );
    if (picked != null) setState(() => _color = picked);
  }

  // ── Device actions ────────────────────────────────────────────────────────────

  Future<void> _addDevice() async {
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return;
    if (_loadingDevices) return;
    setState(() => _loadingDevices = true);

    try {
      final svc = HomeService();
      final rooms = await svc.fetchRooms(home.id);
      final raw = <SmarthomeDevice>[];
      for (final room in rooms) {
        raw.addAll(await svc.fetchDevicesInRoom(room.id));
      }
      final all = await resolveDeviceProfileMetaFromCache(raw);

      if (!mounted) return;
      final device = await showModalBottomSheet<SmarthomeDevice>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DevicePickerSheet(
          devices: all,
          alreadyAdded: _devices.keys.toSet(),
        ),
      );
      if (device == null) return;
      setState(() {
        _deviceInfo[device.id] = device;
        _devices[device.id] = _defaultState(device.effectiveUiType);
      });
    } finally {
      if (mounted) setState(() => _loadingDevices = false);
    }
  }

  Future<void> _editDeviceState(String deviceId, Map<String, dynamic> state) async {
    final device = _deviceInfo[deviceId];
    final uiType = device?.effectiveUiType ?? 'unknown';
    final newState = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StateEditorSheet(
        deviceName: device?.displayName ?? deviceId.substring(0, 8),
        uiType: uiType,
        state: Map.from(state),
      ),
    );
    if (newState != null) {
      setState(() => _devices[deviceId] = newState);
    }
  }

  Map<String, dynamic> _defaultState(String uiType) {
    return switch (uiType) {
      'air_conditioner' => {'onoff0': 1, 'mode': 'cool', 'cool_sp': 26},
      'curtain' => {'onoff0': 0, 'pos': 100},
      'light' => {'onoff0': 1, 'dim': 100},
      _ => {'onoff0': 1},
    };
  }

  // ── Save / Delete ─────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên kịch bản')),
      );
      return;
    }
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return;

    setState(() => _saving = true);
    try {
      final scene = (widget.scene ?? SmarthomeScene.empty()).copyWith(
        name: name,
        icon: _icon,
        color: _color,
        devices: _devices,
      );
      await SceneService().saveScene(home.id, scene);
      ref.invalidate(scenesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa kịch bản?'),
        content: Text('Xóa "${widget.scene!.name}"? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return;
    await SceneService().deleteScene(home.id, widget.scene!.id);
    ref.invalidate(scenesProvider);
    if (mounted) Navigator.of(context).pop(true);
  }
}

// ─── Scene hero card ──────────────────────────────────────────────────────────

class _SceneHeroCard extends StatelessWidget {
  const _SceneHeroCard({
    required this.icon,
    required this.color,
    required this.nameCtrl,
    required this.onIconTap,
    required this.onColorTap,
  });

  final String icon;
  final String color;
  final TextEditingController nameCtrl;
  final VoidCallback onIconTap;
  final VoidCallback onColorTap;

  @override
  Widget build(BuildContext context) {
    final accent = _hexColor(color);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.85), accent.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          // Icon + change color button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon picker button
              GestureDetector(
                onTap: onIconTap,
                child: Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconFromName(icon),
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: accent, width: 1.5),
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 12,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name text field (white, no border)
          TextField(
            controller: nameCtrl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Nhập tên kịch bản…',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              border: InputBorder.none,
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Color palette row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Màu: ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              ..._kColorOptions.map((hex) {
                final c = _hexColor(hex);
                final isSelected = hex == color;
                return GestureDetector(
                  onTap: onColorTap,
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 2.5)
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : null,
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.badge});
  final String label;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Empty actions placeholder ────────────────────────────────────────────────

class _EmptyActionsPlaceholder extends StatelessWidget {
  const _EmptyActionsPlaceholder({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1.5,
            style: BorderStyle.none,
          ),
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        child: Column(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 40,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            Text(
              'Thêm thiết bị',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Chọn thiết bị và trạng thái mong muốn',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Device action card ───────────────────────────────────────────────────────

class _DeviceActionCard extends StatelessWidget {
  const _DeviceActionCard({
    required this.deviceId,
    required this.state,
    required this.device,
    required this.onEdit,
    required this.onRemove,
  });

  final String deviceId;
  final Map<String, dynamic> state;
  final SmarthomeDevice? device;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final uiType = device?.effectiveUiType ?? '';
    final name = device?.displayName ?? '${deviceId.substring(0, 8)}…';
    final icon = _deviceIconFor(uiType);
    final summary = _stateLabel(state, uiType);
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Device icon circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: cs.primary),
              ),
              const SizedBox(width: 12),

              // Name + summary
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Edit chevron
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
              const SizedBox(width: 4),

              // Delete button
              InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add device button ────────────────────────────────────────────────────────

class _AddDeviceButton extends StatelessWidget {
  const _AddDeviceButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Thêm thiết bị'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ─── Icon picker sheet ────────────────────────────────────────────────────────

class _IconPickerSheet extends StatelessWidget {
  const _IconPickerSheet({required this.current});
  final String current;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn biểu tượng',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _kIconOptions.map((opt) {
              final (key, iconData, label) = opt;
              final selected = current == key;
              final primary = Theme.of(context).colorScheme.primary;
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 70,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? primary.withValues(alpha: 0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        iconData,
                        size: 26,
                        color: selected ? primary : Colors.grey.shade700,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? primary : Colors.grey.shade600,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Color picker sheet ───────────────────────────────────────────────────────

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.current});
  final String current;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn màu sắc',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _kColorOptions.map((hex) {
              final c = _hexColor(hex);
              final isSelected = _selected == hex;
              return GestureDetector(
                onTap: () => setState(() => _selected = hex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: _hexColor(_selected),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Xác nhận', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Device picker sheet ──────────────────────────────────────────────────────

class _DevicePickerSheet extends StatefulWidget {
  const _DevicePickerSheet({
    required this.devices,
    required this.alreadyAdded,
  });

  final List<SmarthomeDevice> devices;
  final Set<String> alreadyAdded;

  @override
  State<_DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends State<_DevicePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.devices
        .where((d) =>
            !widget.alreadyAdded.contains(d.id) &&
            d.displayName.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'Chọn thiết bị',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} thiết bị',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm…',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Không tìm thấy thiết bị')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final d = filtered[i];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _deviceIconFor(d.effectiveUiType),
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(d.displayName),
                        subtitle: Text(
                          d.effectiveUiType.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => Navigator.of(context).pop(d),
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ─── State editor sheet ───────────────────────────────────────────────────────

class _StateEditorSheet extends StatefulWidget {
  const _StateEditorSheet({
    required this.deviceName,
    required this.uiType,
    required this.state,
  });

  final String deviceName;
  final String uiType;
  final Map<String, dynamic> state;

  @override
  State<_StateEditorSheet> createState() => _StateEditorSheetState();
}

class _StateEditorSheetState extends State<_StateEditorSheet> {
  late Map<String, dynamic> _state;

  @override
  void initState() {
    super.initState();
    _state = Map.from(widget.state);
  }

  bool get _isOn => _state['onoff0'] == 1 || _state['onoff0'] == true;

  void _setOn(bool v) => setState(() => _state['onoff0'] = v ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                _deviceIconFor(widget.uiType),
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.deviceName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildControls(),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_state),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return switch (widget.uiType) {
      'light' => _LightControls(
          state: _state,
          isOn: _isOn,
          onToggle: _setOn,
          onChanged: (s) => setState(() => _state = s),
        ),
      'air_conditioner' => _AcControls(
          state: _state,
          isOn: _isOn,
          onToggle: _setOn,
          onChanged: (s) => setState(() => _state = s),
        ),
      'curtain' => _CurtainControls(
          state: _state,
          onChanged: (s) => setState(() => _state = s),
        ),
      'smart_plug' ||
      'switch' ||
      'electrical_switch' =>
        _OnOffControl(isOn: _isOn, onToggle: _setOn),
      _ => _OnOffControl(isOn: _isOn, onToggle: _setOn),
    };
  }
}

// ─── State control widgets ────────────────────────────────────────────────────

class _OnOffControl extends StatelessWidget {
  const _OnOffControl({required this.isOn, required this.onToggle});
  final bool isOn;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return _ControlRow(
      label: 'Trạng thái',
      child: Switch.adaptive(value: isOn, onChanged: onToggle),
    );
  }
}

class _LightControls extends StatelessWidget {
  const _LightControls({
    required this.state,
    required this.isOn,
    required this.onToggle,
    required this.onChanged,
  });
  final Map<String, dynamic> state;
  final bool isOn;
  final ValueChanged<bool> onToggle;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final dim = ((state['dim'] as num?)?.toDouble() ?? 100.0).clamp(0.0, 100.0);
    return Column(
      children: [
        _ControlRow(
          label: 'Trạng thái',
          child: Switch.adaptive(value: isOn, onChanged: onToggle),
        ),
        _ControlRow(
          label: 'Độ sáng ${dim.round()}%',
          child: Expanded(
            child: Slider(
              value: dim,
              max: 100,
              divisions: 20,
              onChanged: (v) => onChanged({...state, 'dim': v.round()}),
            ),
          ),
        ),
      ],
    );
  }
}

class _AcControls extends StatelessWidget {
  const _AcControls({
    required this.state,
    required this.isOn,
    required this.onToggle,
    required this.onChanged,
  });
  final Map<String, dynamic> state;
  final bool isOn;
  final ValueChanged<bool> onToggle;
  final ValueChanged<Map<String, dynamic>> onChanged;

  static const _modes = [
    ('cool', '❄️ Lạnh'),
    ('heat', '🔥 Sưởi'),
    ('fan', '💨 Quạt'),
    ('auto', '⚡ Tự động'),
  ];

  @override
  Widget build(BuildContext context) {
    final sp = ((state['cool_sp'] as num?)?.toInt() ?? 26).clamp(16, 32);
    final mode = (state['mode'] as String?) ?? 'cool';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ControlRow(
          label: 'Trạng thái',
          child: Switch.adaptive(value: isOn, onChanged: onToggle),
        ),
        _ControlRow(
          label: 'Nhiệt độ đặt',
          child: Row(
            children: [
              _StepButton(
                icon: Icons.remove,
                onTap: sp > 16
                    ? () => onChanged({...state, 'cool_sp': sp - 1})
                    : null,
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '$sp°C',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                onTap: sp < 32
                    ? () => onChanged({...state, 'cool_sp': sp + 1})
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Chế độ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _modes.map((m) {
            final (key, label) = m;
            final isSelected = mode == key;
            return ChoiceChip(
              label: Text(label, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (_) => onChanged({...state, 'mode': key}),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CurtainControls extends StatelessWidget {
  const _CurtainControls({required this.state, required this.onChanged});
  final Map<String, dynamic> state;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final pos = ((state['pos'] as num?)?.toDouble() ?? 100.0).clamp(0.0, 100.0);
    return _ControlRow(
      label: 'Vị trí ${pos.round()}%',
      child: Expanded(
        child: Slider(
          value: pos,
          max: 100,
          divisions: 10,
          onChanged: (v) => onChanged({...state, 'pos': v.round()}),
        ),
      ),
    );
  }
}

// ─── Control row layout ───────────────────────────────────────────────────────

class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          const Spacer(),
          child,
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: onTap != null
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade400,
        ),
      ),
    );
  }
}
