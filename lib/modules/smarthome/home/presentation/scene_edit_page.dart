import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/scene.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/scene_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/scene_service.dart';

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
  // deviceId → target state map
  late Map<String, Map<String, dynamic>> _devices;

  bool _saving = false;

  static const _iconOptions = [
    ('auto_awesome', Icons.auto_awesome, 'Tự chọn'),
    ('home', Icons.home, 'Về nhà'),
    ('nights_stay', Icons.nights_stay, 'Ngủ'),
    ('wb_sunny', Icons.wb_sunny, 'Thức dậy'),
    ('local_movies', Icons.local_movies, 'Xem phim'),
    ('restaurant', Icons.restaurant, 'Ăn uống'),
    ('bedtime', Icons.bedtime, 'Nghỉ ngơi'),
    ('fitness_center', Icons.fitness_center, 'Tập thể dục'),
  ];

  static const _colorOptions = [
    '#2196F3',
    '#FF9800',
    '#4CAF50',
    '#9C27B0',
    '#F44336',
    '#00BCD4',
    '#FF5722',
    '#607D8B',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.scene;
    if (s != null) {
      _nameCtrl.text = s.name;
      _icon = s.icon;
      _color = s.color;
      _devices = Map.from(s.devices.map((k, v) => MapEntry(k, Map.from(v))));
    } else {
      _devices = {};
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.scene != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Sửa scene' : 'Tạo scene'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Lưu'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Name ──────────────────────────────────────────────────────────
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Tên scene',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          // ── Icon ──────────────────────────────────────────────────────────
          Text('Biểu tượng', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final (key, iconData, label) in _iconOptions)
                _IconOption(
                  iconData: iconData,
                  label: label,
                  selected: _icon == key,
                  onTap: () => setState(() => _icon = key),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Color ─────────────────────────────────────────────────────────
          Text('Màu sắc', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final hex in _colorOptions)
                _ColorOption(
                  hex: hex,
                  selected: _color == hex,
                  onTap: () => setState(() => _color = hex),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Devices ───────────────────────────────────────────────────────
          Row(
            children: [
              Text('Thiết bị', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: _addDevice,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm'),
              ),
            ],
          ),
          if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Chưa có thiết bị nào. Nhấn Thêm để chọn thiết bị.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          for (final entry in _devices.entries)
            _DeviceStateRow(
              deviceId: entry.key,
              state: entry.value,
              onStateChanged: (newState) => setState(
                () => _devices[entry.key] = newState,
              ),
              onRemove: () => setState(() => _devices.remove(entry.key)),
            ),
        ],
      ),
    );
  }

  Future<void> _addDevice() async {
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return;

    final device = await showDialog<SmarthomeDevice>(
      context: context,
      builder: (_) => _DevicePickerDialog(homeId: home.id),
    );
    if (device == null) return;
    if (_devices.containsKey(device.id)) return;
    setState(() => _devices[device.id] = {'onoff0': 1});
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên scene')),
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
          SnackBar(content: Text('Lỗi: $e')),
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
        title: const Text('Xóa scene?'),
        content: Text('Bạn có chắc muốn xóa "${widget.scene!.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.red))),
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

// ─── Icon option ──────────────────────────────────────────────────────────────

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.iconData,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData iconData;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade600;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 8),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(iconData, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Color option ─────────────────────────────────────────────────────────────

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  Color get _color {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : null,
      ),
    );
  }
}

// ─── Device state row ─────────────────────────────────────────────────────────

class _DeviceStateRow extends StatelessWidget {
  const _DeviceStateRow({
    required this.deviceId,
    required this.state,
    required this.onStateChanged,
    required this.onRemove,
  });

  final String deviceId;
  final Map<String, dynamic> state;
  final ValueChanged<Map<String, dynamic>> onStateChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isOn = state['onoff0'] != 0;
    final dim = (state['dim'] as num?)?.toDouble() ?? 100.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ID: ${deviceId.substring(0, 8)}…',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Switch.adaptive(
                  value: isOn,
                  onChanged: (v) =>
                      onStateChanged({...state, 'onoff0': v ? 1 : 0}),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onRemove,
                ),
              ],
            ),
            if (state.containsKey('dim')) ...[
              Row(
                children: [
                  const Text('Độ sáng: ', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: dim.clamp(0.0, 100.0),
                      min: 0,
                      max: 100,
                      divisions: 10,
                      label: '${dim.round()}%',
                      onChanged: (v) =>
                          onStateChanged({...state, 'dim': v.round()}),
                    ),
                  ),
                  Text('${dim.round()}%', style: const TextStyle(fontSize: 13)),
                ],
              ),
            ],
            if (!state.containsKey('dim'))
              TextButton(
                onPressed: () =>
                    onStateChanged({...state, 'dim': 100}),
                child: const Text('+ Thêm độ sáng'),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Device picker dialog ─────────────────────────────────────────────────────

class _DevicePickerDialog extends StatefulWidget {
  const _DevicePickerDialog({required this.homeId});

  final String homeId;

  @override
  State<_DevicePickerDialog> createState() => _DevicePickerDialogState();
}

class _DevicePickerDialogState extends State<_DevicePickerDialog> {
  late Future<List<SmarthomeDevice>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAllDevices();
  }

  Future<List<SmarthomeDevice>> _loadAllDevices() async {
    final svc = HomeService();
    final rooms = await svc.fetchRooms(widget.homeId);
    final all = <SmarthomeDevice>[];
    for (final room in rooms) {
      all.addAll(await svc.fetchDevicesInRoom(room.id));
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chọn thiết bị'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: FutureBuilder<List<SmarthomeDevice>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Lỗi: ${snap.error}'));
            }
            final devices = snap.data ?? [];
            if (devices.isEmpty) {
              return const Center(child: Text('Không có thiết bị nào'));
            }
            return ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final d = devices[index];
                return ListTile(
                  leading: const Icon(Icons.devices_other),
                  title: Text(d.name),
                  subtitle: Text(d.type),
                  onTap: () => Navigator.of(context).pop(d),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
      ],
    );
  }
}
