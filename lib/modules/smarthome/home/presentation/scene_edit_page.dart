import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/scene.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/scene_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/profile_metadata_providers.dart';
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
    return MpColors.blue;
  }
}

IconData _deviceIconFor(String uiType) => switch (uiType) {
      'light' => Icons.lightbulb_outline,
      'airConditioner' => Icons.ac_unit,
      'smartPlug' => Icons.electrical_services,
      'curtain' => Icons.blinds,
      'doorSensor' => Icons.sensor_door_outlined,
      'motionSensor' => Icons.motion_photos_on_outlined,
      'tempHumidity' => Icons.thermostat,
      'camera' => Icons.videocam_outlined,
      'gateway' => Icons.router_outlined,
      'switch' => Icons.toggle_on_outlined,
      'lock' => Icons.lock_outline,
      'smokeSensor' => Icons.local_fire_department_outlined,
      'electricalSwitch' => Icons.power_settings_new,
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
  if (uiType == 'airConditioner') {
    final sp = state['coolSp'];
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
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: MpColors.text),
        title: Text(
          isEdit ? 'Sửa kịch bản' : 'Tạo kịch bản',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: MpColors.text,
          ),
        ),
        centerTitle: true,
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: MpColors.red),
              tooltip: 'Xóa',
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: _saving ? MpColors.surfaceAlt : accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Lưu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
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
    final newState = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StateEditorSheet(
        device: device,
        state: Map.from(state),
      ),
    );
    if (newState != null) {
      setState(() => _devices[deviceId] = newState);
    }
  }

  Map<String, dynamic> _defaultState(String uiType) {
    return switch (uiType) {
      'airConditioner' => {'onoff0': 1, 'mode': 'cool', 'coolSp': 26},
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
        backgroundColor: MpColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa kịch bản?',
            style: TextStyle(
                color: MpColors.text, fontWeight: FontWeight.w600)),
        content: Text(
          'Xóa "${widget.scene!.name}"? Hành động này không thể hoàn tác.',
          style: const TextStyle(color: MpColors.text2, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ',
                style: TextStyle(color: MpColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa',
                style: TextStyle(
                    color: MpColors.red, fontWeight: FontWeight.w600)),
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
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: MpColors.text3,
            letterSpacing: 0.6,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: MpColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: MpColors.text2,
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
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: MpColors.surfaceAlt,
          border: Border.all(color: MpColors.border, width: 0.5),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 36,
              color: MpColors.text3,
            ),
            SizedBox(height: 8),
            Text(
              'Thêm thiết bị',
              style: TextStyle(
                color: MpColors.text2,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Chọn thiết bị và trạng thái mong muốn',
              style: TextStyle(color: MpColors.text3, fontSize: 12),
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

    return InkWell(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: MpColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MpColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MpColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: MpColors.text2),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: MpColors.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MpColors.text3,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right,
                color: MpColors.text3, size: 18),
            const SizedBox(width: 4),

            InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: MpColors.red,
                ),
              ),
            ),
          ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MpColors.borderStrong),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 16, color: MpColors.text2),
            SizedBox(width: 6),
            Text(
              'Thêm thiết bị',
              style: TextStyle(
                  color: MpColors.text2,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ],
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
      decoration: const BoxDecoration(
        color: MpColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: MpColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chọn biểu tượng',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MpColors.text,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _kIconOptions.map((opt) {
              final (key, iconData, label) = opt;
              final selected = current == key;
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 70,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        selected ? MpColors.text : MpColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        iconData,
                        size: 24,
                        color: selected ? MpColors.bg : MpColors.text2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? MpColors.bg : MpColors.text3,
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
      decoration: const BoxDecoration(
        color: MpColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: MpColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chọn màu sắc',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MpColors.text,
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: MpColors.text,
                            width: 3,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(
                            color: c.withValues(alpha: 0.4),
                            blurRadius: 8)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(_selected),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _hexColor(_selected),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Xác nhận',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
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
      decoration: const BoxDecoration(
        color: MpColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: MpColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Chọn thiết bị',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MpColors.text,
                  ),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} thiết bị',
                  style: const TextStyle(
                    fontSize: 12,
                    color: MpColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              style: const TextStyle(color: MpColors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm…',
                hintStyle: const TextStyle(color: MpColors.text3),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: MpColors.text3),
                filled: true,
                fillColor: MpColors.surfaceAlt,
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
                    child: Center(
                      child: Text(
                        'Không tìm thấy thiết bị',
                        style: TextStyle(color: MpColors.text3),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final d = filtered[i];
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(d),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: MpColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(
                                  _deviceIconFor(d.effectiveUiType),
                                  size: 18,
                                  color: MpColors.text2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.displayName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: MpColors.text,
                                        )),
                                    Text(
                                      d.effectiveUiType.replaceAll('_', ' '),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: MpColors.text3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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

class _StateEditorSheet extends ConsumerStatefulWidget {
  const _StateEditorSheet({
    required this.device,
    required this.state,
  });

  final SmarthomeDevice? device;
  final Map<String, dynamic> state;

  @override
  ConsumerState<_StateEditorSheet> createState() => _StateEditorSheetState();
}

class _StateEditorSheetState extends ConsumerState<_StateEditorSheet> {
  late Map<String, dynamic> _state;
  ProfileMetadata? _meta;
  bool _metaLoading = false;

  String get _uiType => widget.device?.effectiveUiType ?? 'unknown';
  String get _deviceName => widget.device?.displayName ?? '';
  bool get _isOn => _state['onoff0'] == 1 || _state['onoff0'] == true;
  void _setOn(bool v) => setState(() => _state['onoff0'] = v ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _state = Map.from(widget.state);
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final profileId = widget.device?.deviceProfileId ?? '';
    if (profileId.isEmpty) return;
    setState(() => _metaLoading = true);
    try {
      final meta = await ref
          .read(profileMetadataServiceProvider)
          .getForProfile(profileId);
      if (mounted) {
        setState(() {
          _meta = meta;
          _metaLoading = false;
          // Pre-fill defaults for controllable keys not yet in state
          if (!meta.isEmpty) {
            for (final e in meta.states.entries) {
              if (e.value.controllable && !_state.containsKey(e.key)) {
                _state[e.key] = e.value.type == 'bool' ? 1 : 0;
              }
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _metaLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MpColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 32 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: MpColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: MpColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  _deviceIconFor(_uiType),
                  size: 18,
                  color: MpColors.text2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _deviceName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MpColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_metaLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: MpColors.text),
              ),
            )
          else
            _buildControls(),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(_state),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: MpColors.text,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Xác nhận',
                  style: TextStyle(
                    color: MpColors.bg,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    // Use metadata if available and has controllable states
    final meta = _meta;
    if (meta != null && !meta.isEmpty) {
      final controllable =
          meta.states.entries.where((e) => e.value.controllable).toList();
      if (controllable.isNotEmpty) {
        return Column(
          children: controllable
              .map((e) => _SceneKeyEditor(
                    stateKey: e.key,
                    def: e.value,
                    value: _state[e.key],
                    onChanged: (v) => setState(() => _state[e.key] = v),
                  ))
              .toList(),
        );
      }
    }
    // Fallback: hardcoded per uiType
    return switch (_uiType) {
      'light' => _LightControls(
          state: _state,
          isOn: _isOn,
          onToggle: _setOn,
          onChanged: (s) => setState(() => _state = s),
        ),
      'airConditioner' => _AcControls(
          state: _state,
          isOn: _isOn,
          onToggle: _setOn,
          onChanged: (s) => setState(() => _state = s),
        ),
      'curtain' => _CurtainControls(
          state: _state,
          onChanged: (s) => setState(() => _state = s),
        ),
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
    final sp = ((state['coolSp'] as num?)?.toInt() ?? 26).clamp(16, 32);
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
                    ? () => onChanged({...state, 'coolSp': sp - 1})
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
                    ? () => onChanged({...state, 'coolSp': sp + 1})
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Chế độ',
          style: TextStyle(
            fontSize: 13,
            color: MpColors.text2,
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
            color: onTap != null ? MpColors.text : MpColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? MpColors.text : MpColors.text3,
        ),
      ),
    );
  }
}

// ─── Metadata-driven key editor (mirrors _ActionKeyEditor in automation) ──────

class _SceneKeyEditor extends StatefulWidget {
  const _SceneKeyEditor({
    required this.stateKey,
    required this.def,
    required this.value,
    required this.onChanged,
  });

  final String stateKey;
  final StateDef def;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_SceneKeyEditor> createState() => _SceneKeyEditorState();
}

class _SceneKeyEditorState extends State<_SceneKeyEditor> {
  late dynamic _current;

  @override
  void initState() {
    super.initState();
    _current = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.def.labelDefault ?? widget.stateKey;
    final unit = widget.def.unit ?? '';
    final def = widget.def;

    if (def.type == 'bool') {
      final isOn = _current == 1 || _current == true;
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: isOn,
        onChanged: (v) {
          setState(() => _current = v ? 1 : 0);
          widget.onChanged(v ? 1 : 0);
        },
      );
    }
    if (def.type == 'enum' && def.enumValues != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DropdownButtonFormField<String>(
          value: def.enumValues!.contains(_current?.toString())
              ? _current?.toString()
              : null,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          items: def.enumValues!
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _current = v);
              widget.onChanged(v);
            }
          },
        ),
      );
    }
    if (def.type == 'number' && def.range != null) {
      final range = def.range!;
      final numCurrent = (_current is num
              ? (_current as num).toDouble()
              : double.tryParse('$_current') ?? range.min)
          .clamp(range.min, range.max);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${numCurrent.round()}$unit',
              style: const TextStyle(fontSize: 14)),
          Slider(
            value: numCurrent,
            min: range.min,
            max: range.max,
            divisions: (range.max - range.min).clamp(1, 100).round(),
            onChanged: (v) {
              setState(() => _current = v.round());
              widget.onChanged(v.round());
            },
          ),
        ],
      );
    }
    // number without range — stepper or text field
    final ctrl = TextEditingController(text: '$_current');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
            labelText: label,
            suffixText: unit,
            border: const OutlineInputBorder()),
        onChanged: (v) {
          _current = num.tryParse(v) ?? v;
          widget.onChanged(_current);
        },
      ),
    );
  }
}
