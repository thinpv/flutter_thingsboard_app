import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/profile_metadata_providers.dart';
import 'package:thingsboard_app/modules/smarthome/smart/domain/entities/automation_rule.dart';
import 'package:thingsboard_app/modules/smarthome/smart/providers/automation_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/automation_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/execution_target_resolver.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';
import 'package:uuid/uuid.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kIcons = [
  ('auto_awesome', Icons.auto_awesome),
  ('wb_sunny', Icons.wb_sunny),
  ('nights_stay', Icons.nights_stay),
  ('thermostat', Icons.thermostat),
  ('schedule', Icons.schedule),
  ('lightbulb', Icons.lightbulb_outline),
  ('security', Icons.security),
  ('home', Icons.home_outlined),
];

const _kColors = [
  '#2196F3', '#FF9800', '#4CAF50', '#E91E63',
  '#9C27B0', '#FF5722', '#607D8B', '#00BCD4',
];

const _kKeyLabel = <String, String>{
  'onoff0': 'Bật/Tắt', 'onoff1': 'Kênh 2', 'onoff2': 'Kênh 3',
  'temp': 'Nhiệt độ', 'hum': 'Độ ẩm', 'co2': 'CO₂',
  'pir': 'Chuyển động', 'lux': 'Ánh sáng', 'door': 'Cửa',
  'leak': 'Rò nước', 'smoke': 'Khói', 'gas': 'Gas',
  'dim': 'Độ sáng', 'pos': 'Vị trí rèm', 'power': 'Công suất',
  'energy': 'Điện năng', 'cool_sp': 'Nhiệt đặt lạnh',
  'mode': 'Chế độ', 'lock': 'Khóa', 'bat': 'Pin',
};

const _kKeyUnit = <String, String>{
  'temp': '°C', 'hum': '%', 'co2': ' ppm',
  'lux': ' lux', 'dim': '%', 'pos': '%',
  'power': ' W', 'energy': ' kWh', 'cool_sp': '°C',
};

const _kDayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

// ─── Human-readable helpers ───────────────────────────────────────────────────

String _keyLabel(String key) => _kKeyLabel[key] ?? key;
String _keyUnit(String key) => _kKeyUnit[key] ?? '';

String _conditionTitle(RuleCondition c) {
  if (c.type == 'timer') return 'Hẹn giờ';
  if (c.type == 'device') return _keyLabel(c.raw['key'] as String? ?? '');
  return c.type;
}

String _conditionSubtitle(RuleCondition c) {
  if (c.type == 'timer') {
    final time = c.raw['time'] as String? ?? '';
    final days = _daysLabel(c.raw['days'] as int? ?? 127);
    return '$time · $days';
  }
  if (c.type == 'device') {
    final key = c.raw['key'] as String? ?? '';
    final op = c.raw['op'] as String? ?? '';
    final value = c.raw['value'];
    final unit = _keyUnit(key);
    if (key == 'onoff0' || key == 'onoff1' || key == 'onoff2') {
      return '$op ${value == 1 ? "BẬT" : "TẮT"}';
    }
    return '$op $value$unit';
  }
  return '';
}

String _actionTitle(RuleAction a) {
  if (a.type == 'delay') return 'Chờ';
  if (a.type == 'device') {
    final data = a.raw['data'] as Map?;
    if (data == null || data.isEmpty) return 'Điều khiển thiết bị';
    return data.entries.map((e) => _formatKV(e.key as String, e.value)).join(' · ');
  }
  if (a.type == 'notify') return 'Thông báo';
  return a.type;
}

String _actionSubtitle(RuleAction a) {
  if (a.type == 'delay') {
    final s = (a.raw['seconds'] as num?)?.toInt() ?? 0;
    if (s >= 3600) return '${(s / 3600).toStringAsFixed(1)} giờ';
    if (s >= 60) return '${s ~/ 60} phút ${s % 60 > 0 ? "${s % 60} giây" : ""}';
    return '$s giây';
  }
  return '';
}

String _formatKV(String key, dynamic value) {
  if (key == 'onoff0' || key == 'onoff1' || key == 'onoff2') {
    return value == 1 || value == '1' ? 'BẬT' : 'TẮT';
  }
  final unit = _keyUnit(key);
  return '${_keyLabel(key)}: $value$unit';
}

String _daysLabel(int bitmask) {
  if (bitmask == 127) return 'Hàng ngày';
  if (bitmask == 65) return 'Cuối tuần';
  if (bitmask == 62) return 'T2–T6';
  final days = <String>[];
  for (int i = 0; i < 7; i++) {
    if (bitmask & (1 << i) != 0) days.add(_kDayNames[i]);
  }
  return days.join(' ');
}

Color _hexColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
  } catch (_) {
    return Colors.blue;
  }
}

// ─── Main widget ──────────────────────────────────────────────────────────────

class AutomationEditPage extends ConsumerStatefulWidget {
  const AutomationEditPage({
    this.rule,
    this.prefillName,
    this.prefillConditions,
    this.prefillActions,
    super.key,
  });

  final AutomationRule? rule;
  final String? prefillName;
  final List<RuleCondition>? prefillConditions;
  final List<RuleAction>? prefillActions;

  @override
  ConsumerState<AutomationEditPage> createState() => _AutomationEditPageState();
}

class _AutomationEditPageState extends ConsumerState<AutomationEditPage> {
  late final TextEditingController _nameCtrl;
  late String _icon;
  late String _color;
  late List<RuleCondition> _conditions;
  late ConditionMatch _conditionMatch;
  late List<RuleAction> _actions;
  RuleSchedule? _schedule;
  bool _scheduleEnabled = false;
  bool _saving = false;

  // device_id → display name (populated when user picks device; lazy for edit)
  final _deviceNames = <String, String>{};

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _nameCtrl = TextEditingController(
        text: r?.name ?? widget.prefillName ?? '');
    _icon = r?.icon ?? 'auto_awesome';
    _color = r?.color ?? '#2196F3';
    _conditions = r?.conditions.toList() ??
        widget.prefillConditions?.toList() ?? [];
    _conditionMatch = r?.conditionMatch ?? ConditionMatch.all;
    _actions = r?.actions.toList() ??
        widget.prefillActions?.toList() ?? [];
    _schedule = r?.schedule;
    _scheduleEnabled = r?.schedule != null;
    if (r != null) _resolveDeviceNamesFromRule(r);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Fire-and-forget: load device names for existing rules (edit mode).
  Future<void> _resolveDeviceNamesFromRule(AutomationRule r) async {
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return;
    final ids = {
      ..._conditions
          .where((c) => c.type == 'device' && c.raw['device_id'] != null)
          .map((c) => c.raw['device_id'] as String),
      ..._actions
          .where((a) => a.type == 'device' && a.raw['device_id'] != null)
          .map((a) => a.raw['device_id'] as String),
    };
    if (ids.isEmpty) return;
    try {
      final svc = HomeService();
      final rooms = await svc.fetchRooms(home.id);
      for (final room in rooms) {
        final devices = await svc.fetchDevicesInRoom(room.id);
        for (final d in devices) {
          if (ids.contains(d.id) && mounted) {
            setState(() => _deviceNames[d.id] = d.displayName);
          }
        }
      }
    } catch (_) {}
  }

  String _deviceName(String id) =>
      _deviceNames[id] ?? '${id.substring(0, 8)}…';

  // ─── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đặt tên cho automation')),
      );
      return;
    }
    if (_actions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần ít nhất một hành động')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final home = ref.read(selectedHomeProvider).valueOrNull;
      if (home == null) return;

      final deviceIds = [
        ..._conditions
            .where((c) => c.type == 'device' && c.raw['device_id'] != null)
            .map((c) => c.raw['device_id'] as String),
        ..._actions
            .where((a) => a.type == 'device' && a.raw['device_id'] != null)
            .map((a) => a.raw['device_id'] as String),
      ];
      final target = await ExecutionTargetResolver().resolve(deviceIds);

      final id = widget.rule?.id ?? const Uuid().v4();
      final rule = AutomationRule(
        id: id,
        name: name,
        icon: _icon,
        color: _color,
        enabled: widget.rule?.enabled ?? true,
        ts: DateTime.now().millisecondsSinceEpoch,
        executionTarget: target,
        schedule: _scheduleEnabled ? _schedule : null,
        conditionMatch: _conditionMatch,
        conditions: _conditions,
        actions: _actions,
      );

      final svc = AutomationService();
      if (rule.isGatewayRule) {
        final currentIndex =
            await ref.read(gatewayRuleIndexProvider(rule.gatewayId!).future);
        await svc.saveGatewayRule(rule.gatewayId!, rule, currentIndex);
      } else {
        final currentRules = await ref.read(serverRulesProvider.future);
        final updated = [
          ...currentRules.where((r) => r.id != id),
          rule,
        ];
        await svc.saveServerRules(home.id, updated);
      }

      ref.invalidate(serverRulesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi lưu: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNew = widget.rule == null;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Text(isNew ? 'Tạo automation' : 'Sửa automation'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text('Lưu',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: cs.primary)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // ── Name + Icon + Color ──────────────────────────────────────────
          _NameCard(ctrl: _nameCtrl),
          const SizedBox(height: 8),
          _StyleCard(
            selectedIcon: _icon,
            selectedColor: _color,
            onIconChanged: (v) => setState(() => _icon = v),
            onColorChanged: (v) => setState(() => _color = v),
          ),
          const SizedBox(height: 16),

          // ── NẾU (Conditions) ─────────────────────────────────────────────
          _SectionBlock(
            label: 'NẾU',
            color: const Color(0xFF1976D2),
            trailing: _ConditionMatchPill(
              value: _conditionMatch,
              onChanged: (v) => setState(() => _conditionMatch = v),
            ),
            children: [
              if (_conditions.isEmpty)
                _EmptyHint(
                  'Không có điều kiện → automation chạy thủ công',
                  Icons.touch_app_outlined,
                ),
              for (int i = 0; i < _conditions.length; i++)
                _ConditionCard(
                  condition: _conditions[i],
                  deviceName: _conditions[i].type == 'device'
                      ? _deviceName(_conditions[i].raw['device_id'] as String? ?? '')
                      : null,
                  onDelete: () =>
                      setState(() => _conditions.removeAt(i)),
                ),
              _AddButton(
                label: '+ Thêm điều kiện',
                onTap: () => _showAddConditionSheet(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── THÌ (Actions) ────────────────────────────────────────────────
          _SectionBlock(
            label: 'THÌ',
            color: const Color(0xFF388E3C),
            children: [
              if (_actions.isEmpty)
                _EmptyHint(
                  'Chưa có hành động nào',
                  Icons.bolt_outlined,
                ),
              for (int i = 0; i < _actions.length; i++)
                _ActionCard(
                  action: _actions[i],
                  deviceName: _actions[i].type == 'device'
                      ? _deviceName(_actions[i].raw['device_id'] as String? ?? '')
                      : null,
                  onDelete: () =>
                      setState(() => _actions.removeAt(i)),
                ),
              _AddButton(
                label: '+ Thêm hành động',
                onTap: () => _showAddActionSheet(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Lịch ─────────────────────────────────────────────────────────
          _ScheduleCard(
            enabled: _scheduleEnabled,
            schedule: _schedule,
            onToggle: (v) => setState(() {
              _scheduleEnabled = v;
              if (v) _schedule ??= const RuleSchedule(days: 127);
            }),
            onChanged: (s) => setState(() => _schedule = s),
          ),
          const SizedBox(height: 8),

          // ── Execution target preview ─────────────────────────────────────
          _ExecutionTargetCard(
            conditions: _conditions,
            actions: _actions,
          ),
        ],
      ),
    );
  }

  // ─── Add condition sheet ──────────────────────────────────────────────────

  Future<void> _showAddConditionSheet() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => _TypePickerSheet(
        title: 'Thêm điều kiện',
        options: const [
          ('device', Icons.devices_other_outlined, 'Thiết bị',
              'Khi trạng thái thiết bị thỏa điều kiện'),
          ('timer', Icons.schedule_outlined, 'Hẹn giờ',
              'Kích hoạt tại thời điểm xác định'),
        ],
      ),
    );
    if (type == null || !mounted) return;

    RuleCondition? result;
    if (type == 'device') {
      result = await showModalBottomSheet<RuleCondition>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _DeviceConditionSheet(parentRef: ref),
      );
    } else if (type == 'timer') {
      result = await showModalBottomSheet<RuleCondition>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => const _TimerConditionSheet(),
      );
    }

    if (result != null) {
      setState(() => _conditions.add(result!));
      // Track device name if device condition
      if (result.type == 'device') {
        final devId = result.raw['device_id'] as String?;
        final devName = result.raw.remove('_device_name') as String?;
        if (devId != null && devName != null) {
          _deviceNames[devId] = devName;
        }
      }
    }
  }

  // ─── Add action sheet ─────────────────────────────────────────────────────

  Future<void> _showAddActionSheet() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => _TypePickerSheet(
        title: 'Thêm hành động',
        options: const [
          ('device', Icons.devices_other_outlined, 'Thiết bị',
              'Gửi lệnh điều khiển thiết bị'),
          ('delay', Icons.hourglass_bottom_outlined, 'Chờ',
              'Dừng N giây rồi tiếp tục'),
        ],
      ),
    );
    if (type == null || !mounted) return;

    RuleAction? result;
    if (type == 'device') {
      result = await showModalBottomSheet<RuleAction>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _DeviceActionSheet(parentRef: ref),
      );
    } else if (type == 'delay') {
      result = await showModalBottomSheet<RuleAction>(
        context: context,
        builder: (ctx) => const _DelaySheet(),
      );
    }

    if (result != null) {
      setState(() => _actions.add(result!));
      if (result.type == 'device') {
        final devId = result.raw['device_id'] as String?;
        final devName = result.raw.remove('_device_name') as String?;
        if (devId != null && devName != null) {
          _deviceNames[devId] = devName;
        }
      }
    }
  }
}

// ─── Name card ────────────────────────────────────────────────────────────────

class _NameCard extends StatelessWidget {
  const _NameCard({required this.ctrl});
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Đặt tên automation…',
          hintStyle: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w400,
              color: cs.onSurface.withValues(alpha: 0.35)),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// ─── Style card (icon + color) ────────────────────────────────────────────────

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.selectedIcon,
    required this.selectedColor,
    required this.onIconChanged,
    required this.onColorChanged,
  });
  final String selectedIcon;
  final String selectedColor;
  final ValueChanged<String> onIconChanged;
  final ValueChanged<String> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon row
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _kIcons.map((entry) {
                final (key, icon) = entry;
                final selected = selectedIcon == key;
                final accent = _hexColor(selectedColor);
                return GestureDetector(
                  onTap: () => onIconChanged(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.15)
                          : cs.surfaceContainerLow,
                      border: selected
                          ? Border.all(color: accent, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon,
                        color: selected ? accent : cs.onSurface.withValues(alpha: 0.45),
                        size: 22),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          // Color row
          Row(
            children: _kColors.map((hex) {
              final selected = selectedColor == hex;
              final c = _hexColor(hex);
              return GestureDetector(
                onTap: () => onColorChanged(hex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: selected ? 32 : 28,
                  height: selected ? 32 : 28,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    boxShadow: selected
                        ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)]
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Section block ────────────────────────────────────────────────────────────

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.label,
    required this.color,
    required this.children,
    this.trailing,
  });
  final String label;
  final Color color;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing!,
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ─── Condition match pill ─────────────────────────────────────────────────────

class _ConditionMatchPill extends StatelessWidget {
  const _ConditionMatchPill(
      {required this.value, required this.onChanged});
  final ConditionMatch value;
  final ValueChanged<ConditionMatch> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAll = value == ConditionMatch.all;
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillOption(
              label: 'Tất cả',
              selected: isAll,
              onTap: () => onChanged(ConditionMatch.all)),
          _PillOption(
              label: 'Một trong',
              selected: !isAll,
              onTap: () => onChanged(ConditionMatch.any)),
        ],
      ),
    );
  }
}

class _PillOption extends StatelessWidget {
  const _PillOption(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// ─── Condition card ───────────────────────────────────────────────────────────

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({
    required this.condition,
    required this.onDelete,
    this.deviceName,
  });
  final RuleCondition condition;
  final String? deviceName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, color) = _iconColor(condition);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _conditionTitle(condition),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (deviceName != null || _conditionSubtitle(condition).isNotEmpty)
                  Text(
                    [
                      if (deviceName != null) deviceName!,
                      if (_conditionSubtitle(condition).isNotEmpty)
                        _conditionSubtitle(condition),
                    ].join(' · '),
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.55)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  static (IconData, Color) _iconColor(RuleCondition c) {
    if (c.type == 'timer') return (Icons.schedule_rounded, Colors.orange);
    if (c.type == 'offline') {
      return (Icons.wifi_off_rounded, Colors.grey);
    }
    final key = c.raw['key'] as String? ?? '';
    return switch (key) {
      'temp' || 'cool_sp' => (Icons.thermostat_outlined, Colors.red.shade400),
      'hum' => (Icons.water_drop_outlined, Colors.blue.shade400),
      'pir' => (Icons.motion_photos_on_outlined, Colors.purple),
      'door' => (Icons.sensor_door_outlined, Colors.teal),
      'onoff0' || 'onoff1' || 'onoff2' => (Icons.power_settings_new_rounded, Colors.blue),
      'lux' => (Icons.wb_sunny_outlined, Colors.orange.shade400),
      'co2' => (Icons.co2_outlined, Colors.green),
      'power' => (Icons.bolt_outlined, Colors.amber),
      _ => (Icons.sensors_outlined, const Color(0xFF1976D2)),
    };
  }
}

// ─── Action card ──────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.onDelete,
    this.deviceName,
  });
  final RuleAction action;
  final String? deviceName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, color) = _iconColor(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.type == 'delay'
                      ? 'Chờ ${_actionSubtitle(action)}'
                      : (deviceName ?? _actionTitle(action)),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (action.type == 'device')
                  Text(
                    _actionTitle(action),
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.55)),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  static (IconData, Color) _iconColor(RuleAction a) {
    if (a.type == 'delay') {
      return (Icons.hourglass_bottom_outlined, Colors.purple);
    }
    if (a.type == 'notify') {
      return (Icons.notifications_outlined, Colors.teal);
    }
    if (a.type == 'scene') {
      return (Icons.auto_awesome_outlined, Colors.amber.shade700);
    }
    final data = a.raw['data'] as Map?;
    final hasOff = data?['onoff0'] == 0 || data?['onoff1'] == 0;
    final hasOn = data?['onoff0'] == 1 || data?['onoff1'] == 1;
    if (hasOn) return (Icons.power_settings_new_rounded, const Color(0xFF388E3C));
    if (hasOff) {
      return (Icons.power_settings_new_rounded, Colors.grey);
    }
    return (Icons.settings_remote_outlined, const Color(0xFF388E3C));
  }
}

// ─── Add button ───────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.35),
            width: 1.5,
            // dashed via BoxBorder is not directly supported in Flutter;
            // using solid with lower alpha achieves a similar soft look
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty hint ───────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text, this.icon);
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Schedule card ────────────────────────────────────────────────────────────

class _ScheduleCard extends StatefulWidget {
  const _ScheduleCard({
    required this.enabled,
    required this.schedule,
    required this.onToggle,
    required this.onChanged,
  });
  final bool enabled;
  final RuleSchedule? schedule;
  final ValueChanged<bool> onToggle;
  final ValueChanged<RuleSchedule> onChanged;

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  Future<void> _pickTime(bool isFrom) async {
    final current = isFrom
        ? widget.schedule?.timeFrom ?? '00:00'
        : widget.schedule?.timeTo ?? '23:59';
    final parts = current.split(':');
    final initial = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final str =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final s = widget.schedule ?? const RuleSchedule(days: 127);
    widget.onChanged(isFrom
        ? RuleSchedule(days: s.days, timeFrom: str, timeTo: s.timeTo)
        : RuleSchedule(days: s.days, timeFrom: s.timeFrom, timeTo: str));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = widget.schedule ?? const RuleSchedule(days: 127);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Toggle row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Giới hạn thời gian',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Switch.adaptive(
                  value: widget.enabled,
                  onChanged: widget.onToggle,
                ),
              ],
            ),
          ),
          if (widget.enabled) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day chips
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (i) {
                      final on = s.days & (1 << i) != 0;
                      return FilterChip(
                        label: Text(_kDayNames[i],
                            style: const TextStyle(fontSize: 12)),
                        selected: on,
                        onSelected: (v) {
                          int newDays = s.days;
                          if (v) {
                            newDays |= (1 << i);
                          } else {
                            newDays &= ~(1 << i);
                          }
                          widget.onChanged(RuleSchedule(
                              days: newDays,
                              timeFrom: s.timeFrom,
                              timeTo: s.timeTo));
                        },
                        visualDensity: VisualDensity.compact,
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  // Time range
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(s.timeFrom ?? 'Từ giờ'),
                          onPressed: () => _pickTime(true),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 16),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(s.timeTo ?? 'Đến giờ'),
                          onPressed: () => _pickTime(false),
                        ),
                      ),
                      if (s.timeFrom != null || s.timeTo != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => widget.onChanged(
                              RuleSchedule(days: s.days)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Execution target card ────────────────────────────────────────────────────

class _ExecutionTargetCard extends StatefulWidget {
  const _ExecutionTargetCard(
      {required this.conditions, required this.actions});
  final List<RuleCondition> conditions;
  final List<RuleAction> actions;

  @override
  State<_ExecutionTargetCard> createState() => _ExecutionTargetCardState();
}

class _ExecutionTargetCardState extends State<_ExecutionTargetCard> {
  String? _target;

  @override
  void didUpdateWidget(_ExecutionTargetCard old) {
    super.didUpdateWidget(old);
    _resolve();
  }

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final deviceIds = [
      ...widget.conditions
          .where((c) => c.type == 'device' && c.raw['device_id'] != null)
          .map((c) => c.raw['device_id'] as String),
      ...widget.actions
          .where((a) => a.type == 'device' && a.raw['device_id'] != null)
          .map((a) => a.raw['device_id'] as String),
    ];
    if (deviceIds.isEmpty) {
      if (mounted) setState(() => _target = 'server');
      return;
    }
    try {
      final t = await ExecutionTargetResolver().resolve(deviceIds);
      if (mounted) setState(() => _target = t);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_target == null) return const SizedBox.shrink();
    final isGw = _target!.startsWith('gw:');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isGw ? Icons.router_outlined : Icons.cloud_outlined,
            size: 20,
            color: isGw ? Colors.orange : cs.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGw ? 'Thực thi trên Gateway' : 'Thực thi trên Server',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  isGw
                      ? 'Hoạt động offline, độ trễ thấp'
                      : 'Cần kết nối cloud',
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isGw ? Colors.orange : cs.primary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isGw ? '⚡ Local' : '☁️ Cloud',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isGw ? Colors.orange : cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Type picker sheet ────────────────────────────────────────────────────────

class _TypePickerSheet extends StatelessWidget {
  const _TypePickerSheet(
      {required this.title, required this.options});
  final String title;
  final List<(String, IconData, String, String)> options;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...options.map((opt) {
              final (type, icon, label, subtitle) = opt;
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: cs.primary, size: 20),
                ),
                title: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(subtitle,
                    style: const TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, type),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Device condition sheet ───────────────────────────────────────────────────

class _DeviceConditionSheet extends ConsumerStatefulWidget {
  const _DeviceConditionSheet({required this.parentRef});
  final WidgetRef parentRef;

  @override
  ConsumerState<_DeviceConditionSheet> createState() =>
      _DeviceConditionSheetState();
}

class _DeviceConditionSheetState
    extends ConsumerState<_DeviceConditionSheet> {
  SmarthomeDevice? _device;
  ProfileMetadata? _meta;
  String? _key;
  String _op = '>';
  String _value = '';

  static const _defaultKeys = [
    'temp', 'hum', 'onoff0', 'dim', 'pir', 'lux', 'door', 'co2', 'pos',
  ];
  static const _allOps = ['>', '<', '>=', '<=', '==', '!='];
  static const _boolOps = ['==', '!='];

  List<String> get _availableKeys {
    final metaKeys = _meta?.states.keys.toList();
    if (metaKeys != null && metaKeys.isNotEmpty) return metaKeys;
    return _defaultKeys;
  }

  List<String> get _availableOps {
    if (_key != null) {
      final def = _meta?.states[_key!];
      if (def?.type == 'bool' || def?.type == 'enum') return _boolOps;
      final capOps = _meta?.automation?.conditions
          .where((c) => c.key == _key)
          .firstOrNull
          ?.ops;
      if (capOps != null && capOps.isNotEmpty) return capOps;
    }
    return _allOps;
  }

  Future<void> _loadMeta(SmarthomeDevice device) async {
    final profileId = device.deviceProfileId ?? '';
    if (profileId.isEmpty) {
      setState(() => _meta = null);
      return;
    }
    final meta = await widget.parentRef
        .read(profileMetadataServiceProvider)
        .getForProfile(profileId);
    if (mounted) {
      setState(() {
        _meta = meta;
        _key = _availableKeys.isNotEmpty ? _availableKeys.first : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keys = _availableKeys;
    final ops = _availableOps;
    final currentKey = _key ?? (keys.isNotEmpty ? keys.first : null);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Thêm điều kiện thiết bị',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _DevicePicker(
              onSelected: (d) {
                setState(() {
                  _device = d;
                  _meta = null;
                  _key = null;
                });
                _loadMeta(d);
              },
            ),
            if (_device != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: keys.contains(currentKey) ? currentKey : null,
                decoration: const InputDecoration(
                    labelText: 'Thuộc tính',
                    border: OutlineInputBorder()),
                items: keys.map((k) {
                  final label = _meta?.states[k]?.labelDefault ?? _keyLabel(k);
                  return DropdownMenuItem(
                      value: k, child: Text('$label ($k)'));
                }).toList(),
                onChanged: (v) => setState(() {
                  _key = v;
                  final newOps = _availableOps;
                  if (!newOps.contains(_op)) _op = newOps.first;
                }),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: ops.contains(_op) ? _op : ops.first,
                decoration: const InputDecoration(
                    labelText: 'Toán tử',
                    border: OutlineInputBorder()),
                items: ops
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _op = v!),
              ),
              const SizedBox(height: 8),
              _ValueInput(
                stateKey: _key,
                def: _key != null ? _meta?.states[_key!] : null,
                initial: _value,
                onChanged: (v) => _value = v,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (_device == null || _key == null)
                        ? null
                        : () {
                            final cond = RuleCondition(raw: {
                              'type': 'device',
                              'device_id': _device!.id,
                              '_device_name': _device!.displayName,
                              'key': _key!,
                              'op': _op,
                              'value': num.tryParse(_value) ?? _value,
                            });
                            Navigator.pop(context, cond);
                          },
                    style: FilledButton.styleFrom(
                        backgroundColor: cs.primary),
                    child: const Text('Thêm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Timer condition sheet ────────────────────────────────────────────────────

class _TimerConditionSheet extends StatefulWidget {
  const _TimerConditionSheet();

  @override
  State<_TimerConditionSheet> createState() => _TimerConditionSheetState();
}

class _TimerConditionSheetState extends State<_TimerConditionSheet> {
  int _days = 127;
  String _time = '07:00';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hẹn giờ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            // Time display + picker
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded),
                    const SizedBox(width: 12),
                    Text(
                      _time,
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Icon(Icons.edit_outlined,
                        size: 18,
                        color: cs.onSurface.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Ngày trong tuần',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final on = _days & (1 << i) != 0;
                return GestureDetector(
                  onTap: () => setState(() {
                    if (on) {
                      _days &= ~(1 << i);
                    } else {
                      _days |= (1 << i);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: on ? cs.primary : cs.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _kDayNames[i],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: on ? cs.onPrimary : cs.onSurface),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      RuleCondition(raw: {
                        'type': 'timer',
                        'days': _days,
                        'time': _time,
                      }),
                    ),
                    child: const Text('Thêm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final initial = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 7,
        minute: int.tryParse(parts[1]) ?? 0);
    final picked =
        await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      setState(() {
        _time =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }
}

// ─── Device action sheet ──────────────────────────────────────────────────────

class _DeviceActionSheet extends ConsumerStatefulWidget {
  const _DeviceActionSheet({required this.parentRef});
  final WidgetRef parentRef;

  @override
  ConsumerState<_DeviceActionSheet> createState() =>
      _DeviceActionSheetState();
}

class _DeviceActionSheetState
    extends ConsumerState<_DeviceActionSheet> {
  SmarthomeDevice? _device;
  ProfileMetadata? _meta;
  final _data = <String, dynamic>{};
  final _keyCtrl = TextEditingController();
  final _valCtrl = TextEditingController();

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeta(SmarthomeDevice device) async {
    final profileId = device.deviceProfileId ?? '';
    if (profileId.isEmpty) {
      setState(() => _meta = null);
      return;
    }
    final meta = await widget.parentRef
        .read(profileMetadataServiceProvider)
        .getForProfile(profileId);
    if (mounted) {
      setState(() {
        _meta = meta;
        _data.clear();
        if (!meta.isEmpty) {
          for (final e in meta.states.entries) {
            if (e.value.controllable) {
              _data[e.key] = e.value.type == 'bool' ? 1 : 0;
            }
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasMetaKeys =
        _meta != null && _meta!.states.values.any((d) => d.controllable);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Thêm hành động thiết bị',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _DevicePicker(
              onSelected: (d) {
                setState(() {
                  _device = d;
                  _meta = null;
                  _data.clear();
                });
                _loadMeta(d);
              },
            ),
            if (_device != null) ...[
              const SizedBox(height: 12),
              Text('Điều khiển',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              if (hasMetaKeys)
                ..._meta!.states.entries
                    .where((e) => e.value.controllable)
                    .map((e) => _ActionKeyEditor(
                          stateKey: e.key,
                          def: e.value,
                          value: _data[e.key],
                          onChanged: (v) =>
                              setState(() => _data[e.key] = v),
                        ))
              else ...[
                ..._data.entries.map((e) => ListTile(
                      dense: true,
                      title: Text('${e.key} = ${e.value}'),
                      trailing: IconButton(
                        icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 18),
                        onPressed: () =>
                            setState(() => _data.remove(e.key)),
                      ),
                    )),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _keyCtrl,
                        decoration: const InputDecoration(
                            hintText: 'key (onoff0…)',
                            isDense: true,
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _valCtrl,
                        decoration: const InputDecoration(
                            hintText: 'value',
                            isDense: true,
                            border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final k = _keyCtrl.text.trim();
                        final v = _valCtrl.text.trim();
                        if (k.isNotEmpty && v.isNotEmpty) {
                          setState(() {
                            _data[k] = num.tryParse(v) ?? v;
                            _keyCtrl.clear();
                            _valCtrl.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (_device == null || _data.isEmpty)
                        ? null
                        : () {
                            final action = RuleAction(raw: {
                              'type': 'device',
                              'device_id': _device!.id,
                              '_device_name': _device!.displayName,
                              'data': Map<String, dynamic>.from(_data),
                            });
                            Navigator.pop(context, action);
                          },
                    style: FilledButton.styleFrom(
                        backgroundColor: cs.primary),
                    child: const Text('Thêm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Delay sheet ──────────────────────────────────────────────────────────────

class _DelaySheet extends StatefulWidget {
  const _DelaySheet();

  @override
  State<_DelaySheet> createState() => _DelaySheetState();
}

class _DelaySheetState extends State<_DelaySheet> {
  int _seconds = 30;

  @override
  Widget build(BuildContext context) {
    final label = _seconds >= 60
        ? '${_seconds ~/ 60} phút ${_seconds % 60 > 0 ? "${_seconds % 60}s" : ""}'
        : '$_seconds giây';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Thời gian chờ',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Text(
              label,
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary),
            ),
            Slider(
              value: _seconds.toDouble(),
              min: 1,
              max: 3600,
              divisions: 100,
              onChanged: (v) => setState(() => _seconds = v.round()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      RuleAction(
                          raw: {'type': 'delay', 'seconds': _seconds}),
                    ),
                    child: const Text('Thêm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared: Device picker ────────────────────────────────────────────────────

class _DevicePicker extends ConsumerStatefulWidget {
  const _DevicePicker({required this.onSelected});

  final ValueChanged<SmarthomeDevice> onSelected;

  @override
  ConsumerState<_DevicePicker> createState() => _DevicePickerState();
}

class _DevicePickerState extends ConsumerState<_DevicePicker> {
  SmarthomeDevice? _selected;
  late Future<List<SmarthomeDevice>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
  }

  Future<List<SmarthomeDevice>> _loadAll() async {
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return [];
    final svc = HomeService();
    final rooms = await svc.fetchRooms(home.id);
    final all = <SmarthomeDevice>[];
    for (final r in rooms) {
      all.addAll(await svc.fetchDevicesInRoom(r.id));
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SmarthomeDevice>>(
      future: _future,
      builder: (ctx, snap) {
        final devices = snap.data ?? [];
        return DropdownButtonFormField<SmarthomeDevice>(
          value: _selected,
          decoration: const InputDecoration(
            labelText: 'Thiết bị',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.devices_other_outlined),
          ),
          hint: snap.connectionState == ConnectionState.waiting
              ? const Text('Đang tải…')
              : const Text('Chọn thiết bị'),
          items: devices.map((d) {
            return DropdownMenuItem(
              value: d,
              child: Text(d.displayName, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (d) {
            if (d == null) return;
            setState(() => _selected = d);
            widget.onSelected(d);
          },
        );
      },
    );
  }
}

// ─── Shared: Value input ──────────────────────────────────────────────────────

class _ValueInput extends StatefulWidget {
  const _ValueInput({
    required this.stateKey,
    required this.def,
    required this.initial,
    required this.onChanged,
  });

  final String? stateKey;
  final StateDef? def;
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_ValueInput> createState() => _ValueInputState();
}

class _ValueInputState extends State<_ValueInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    if (def?.type == 'bool') {
      final current = _ctrl.text == '1';
      return DropdownButtonFormField<int>(
        value: current ? 1 : 0,
        decoration: const InputDecoration(
            labelText: 'Giá trị', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 1, child: Text('BẬT (1)')),
          DropdownMenuItem(value: 0, child: Text('TẮT (0)')),
        ],
        onChanged: (v) {
          _ctrl.text = '$v';
          widget.onChanged('$v');
        },
      );
    }
    if (def?.type == 'enum' && def!.enumValues != null) {
      return DropdownButtonFormField<String>(
        value: def.enumValues!.contains(_ctrl.text) ? _ctrl.text : null,
        decoration: const InputDecoration(
            labelText: 'Giá trị', border: OutlineInputBorder()),
        items: def.enumValues!
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            _ctrl.text = v;
            widget.onChanged(v);
          }
        },
      );
    }
    if (def?.type == 'number' && def?.range != null) {
      final range = def!.range!;
      final current = double.tryParse(_ctrl.text) ?? range.min;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.stateKey ?? "Giá trị"}: ${current.toStringAsFixed(0)}${_kKeyUnit[widget.stateKey ?? ''] ?? ''}'),
          Slider(
            value: current.clamp(range.min, range.max),
            min: range.min,
            max: range.max,
            divisions: ((range.max - range.min).clamp(1, 100)).round(),
            onChanged: (v) {
              _ctrl.text = '${v.round()}';
              widget.onChanged('${v.round()}');
            },
          ),
        ],
      );
    }
    return TextFormField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
          labelText: 'Giá trị', border: OutlineInputBorder()),
      onChanged: widget.onChanged,
    );
  }
}

// ─── Shared: Action key editor ────────────────────────────────────────────────

class _ActionKeyEditor extends StatefulWidget {
  const _ActionKeyEditor({
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
  State<_ActionKeyEditor> createState() => _ActionKeyEditorState();
}

class _ActionKeyEditorState extends State<_ActionKeyEditor> {
  late dynamic _current;

  @override
  void initState() {
    super.initState();
    _current = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.def.labelDefault ?? _keyLabel(widget.stateKey);
    final unit = _kKeyUnit[widget.stateKey] ?? '';
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
      return DropdownButtonFormField<String>(
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
          Text('$label: ${numCurrent.round()}$unit'),
          Slider(
            value: numCurrent,
            min: range.min,
            max: range.max,
            divisions: ((range.max - range.min).clamp(1, 100)).round(),
            onChanged: (v) {
              setState(() => _current = v.round());
              widget.onChanged(v.round());
            },
          ),
        ],
      );
    }
    final ctrl = TextEditingController(text: '$_current');
    return TextFormField(
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
    );
  }
}
