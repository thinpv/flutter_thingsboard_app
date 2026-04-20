import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/scene.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/scene_provider.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/profile_metadata_providers.dart';
import 'package:thingsboard_app/modules/smarthome/smart/domain/entities/automation_rule.dart';
import 'package:thingsboard_app/modules/smarthome/smart/providers/automation_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/automation_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/execution_target_resolver.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/scene_service.dart';
import 'package:uuid/uuid.dart';

/// Action types that require server-side execution and cannot run on a gateway.
const _serverOnlyActionTypes = {'notify', 'offline', 'scene'};

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
  'energy': 'Điện năng', 'coolSp': 'Nhiệt đặt lạnh',
  'mode': 'Chế độ', 'lock': 'Khóa', 'bat': 'Pin',
};

const _kKeyUnit = <String, String>{
  'temp': '°C', 'hum': '%', 'co2': ' ppm',
  'lux': ' lux', 'dim': '%', 'pos': '%',
  'power': ' W', 'energy': ' kWh', 'coolSp': '°C',
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
  if (a.type == 'notify') {
    final title = (a.raw['title'] as String?)?.trim() ?? '';
    if (title.isNotEmpty) return title;
    final msg = (a.raw['message'] as String?)?.trim() ?? '';
    if (msg.isNotEmpty) return msg;
    return 'Thông báo';
  }
  if (a.type == 'scene') {
    final name = (a.raw['_scene_name'] as String?)?.trim() ?? '';
    return name.isNotEmpty ? name : 'Kịch bản';
  }
  return a.type;
}

String _actionSubtitle(RuleAction a) {
  if (a.type == 'delay') {
    final s = (a.raw['seconds'] as num?)?.toInt() ?? 0;
    if (s >= 3600) return '${(s / 3600).toStringAsFixed(1)} giờ';
    if (s >= 60) return '${s ~/ 60} phút ${s % 60 > 0 ? "${s % 60} giây" : ""}';
    return '$s giây';
  }
  if (a.type == 'notify') {
    final target = a.raw['target'] as String? ?? 'all';
    final severity = a.raw['severity'] as String? ?? 'info';
    return '${_notifyTargetLabel(target)} · ${_notifySeverityLabel(severity)}';
  }
  if (a.type == 'scene') return 'Kích hoạt kịch bản';
  return '';
}

String _notifyTargetLabel(String t) {
  if (t == 'all') return 'Tất cả thành viên';
  if (t == 'owner') return 'Chủ nhà';
  if (t.startsWith('userId:')) return 'Người dùng cụ thể';
  if (t.startsWith('role:')) return 'Vai trò ${t.substring(5)}';
  return t;
}

String _notifySeverityLabel(String s) => switch (s.toUpperCase()) {
      'CRITICAL' => 'Nghiêm trọng',
      'WARNING' || 'MAJOR' || 'MINOR' => 'Cảnh báo',
      _ => 'Thông tin',
    };

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
    return MpColors.blue;
  }
}

// ─── Main widget ──────────────────────────────────────────────────────────────

class AutomationEditPage extends ConsumerStatefulWidget {
  const AutomationEditPage({
    this.rule,
    this.prefillName,
    this.prefillConditions,
    this.prefillActions,
    this.isTapToRun = false,
    this.scene,
    super.key,
  });

  final AutomationRule? rule;
  final String? prefillName;
  final List<RuleCondition>? prefillConditions;
  final List<RuleAction>? prefillActions;
  final bool isTapToRun;
  final SmarthomeScene? scene;

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
    final sc = widget.scene;
    _nameCtrl = TextEditingController(
        text: r?.name ?? sc?.name ?? widget.prefillName ?? '');
    _icon = r?.icon ?? sc?.icon ?? 'auto_awesome';
    _color = r?.color ?? sc?.color ?? '#FF9800';
    _conditions = r?.conditions.toList() ??
        widget.prefillConditions?.toList() ?? [];
    _conditionMatch = r?.conditionMatch ?? ConditionMatch.all;
    if (widget.isTapToRun && sc != null) {
      _actions = sc.actions
          .map((raw) => RuleAction(raw: Map<String, dynamic>.from(raw)))
          .toList();
    } else {
      _actions = r?.actions.toList() ??
          widget.prefillActions?.toList() ?? [];
    }
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
    final home = await _awaitHome();
    if (home == null) return;
    final ids = {
      ..._conditions
          .where((c) => c.type == 'device' && c.raw['deviceId'] != null)
          .map((c) => c.raw['deviceId'] as String),
      ..._actions
          .where((a) => a.type == 'device' && a.raw['deviceId'] != null)
          .map((a) => a.raw['deviceId'] as String),
    };
    if (ids.isEmpty) return;
    try {
      final svc = HomeService();
      final rooms = await svc.fetchRooms(home.id);
      final all = <SmarthomeDevice>[];
      for (final room in rooms) {
        all.addAll(await svc.fetchDevicesInRoom(room.id));
      }
      all.addAll(await svc.fetchDevicesInHome(home.id));
      final resolved = await resolveDeviceProfileMetaFromCache(all);
      for (final d in resolved) {
        if (ids.contains(d.id) && mounted) {
          setState(() => _deviceNames[d.id] = d.displayName);
        }
      }
    } catch (_) {}
  }

  String _deviceName(String id) {
    if (_deviceNames.containsKey(id)) return _deviceNames[id]!;
    if (id.length <= 8) return id.isEmpty ? '—' : id;
    return '${id.substring(0, 8)}…';
  }

  Future<SmarthomeHome?> _awaitHome() async {
    try {
      final homes = await ref.read(homesProvider.future);
      if (homes.isEmpty) return null;
      final selectedId = ref.read(selectedHomeIdProvider);
      return selectedId == null
          ? homes.first
          : homes.firstWhere((h) => h.id == selectedId,
              orElse: () => homes.first);
    } catch (_) {
      return null;
    }
  }

  // ─── Save ────────────────────────────────────────────────────────────────────

  Future<void> _saveTapToRun() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đặt tên cho kịch bản')),
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
      final home = await _awaitHome();
      if (home == null) return;

      final actions = _actions.map((a) {
        final raw = Map<String, dynamic>.from(a.raw);
        raw.remove('_device_name');
        raw.remove('_scene_name');
        return raw;
      }).toList();

      final scene = SmarthomeScene(
        id: widget.scene?.id ?? const Uuid().v4(),
        name: name,
        icon: _icon,
        color: _color,
        actions: actions,
      );

      await SceneService().saveScene(home.id, scene);
      ref.invalidate(scenesProvider);
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

  Future<void> _save() async {
    if (widget.isTapToRun) {
      await _saveTapToRun();
      return;
    }
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
      final home = await _awaitHome();
      if (home == null) return;

      final hasServerOnlyAction =
          _actions.any((a) => _serverOnlyActionTypes.contains(a.type));
      final deviceIds = [
        ..._conditions
            .where((c) => c.type == 'device' && c.raw['deviceId'] != null)
            .map((c) => c.raw['deviceId'] as String),
        ..._actions
            .where((a) => a.type == 'device' && a.raw['deviceId'] != null)
            .map((a) => a.raw['deviceId'] as String),
      ];
      final target = hasServerOnlyAction
          ? 'server'
          : await ExecutionTargetResolver()
              .resolve(deviceIds, homeId: home.id);

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

      // If editing and the execution target changed (gw→server, server→gw,
      // or gw A→gw B), delete the stale copy from its previous location so
      // the rule doesn't run twice.
      final oldTarget = widget.rule?.executionTarget;
      if (oldTarget != null && oldTarget != target) {
        if (oldTarget.startsWith('gw:')) {
          final oldGwId = oldTarget.substring(3);
          final oldIndex = await svc.fetchGatewayRuleIndex(oldGwId);
          await svc.deleteGatewayRule(oldGwId, id, oldIndex);
          ref.invalidate(gatewayRuleIndexProvider(oldGwId));
        } else if (oldTarget == 'server') {
          final currentRules = await svc.fetchServerRules(home.id);
          final pruned = currentRules.where((r) => r.id != id).toList();
          await svc.saveServerRules(home.id, pruned);
        }
      }

      if (rule.isGatewayRule) {
        final currentIndex =
            await ref.read(gatewayRuleIndexProvider(rule.gatewayId!).future);
        await svc.saveGatewayRule(rule.gatewayId!, rule, currentIndex);
        ref.invalidate(gatewayRuleIndexProvider(rule.gatewayId!));
      } else {
        final currentRules = await svc.fetchServerRules(home.id);
        final updated = [
          ...currentRules.where((r) => r.id != id),
          rule,
        ];
        await svc.saveServerRules(home.id, updated);
      }

      ref.invalidate(serverRulesProvider);
      ref.invalidate(allRulesProvider);
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
    final isNew = widget.rule == null && widget.scene == null;
    final isTtr = widget.isTapToRun;

    return Scaffold(
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 72,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Huỷ',
            style: TextStyle(fontSize: 15, color: MpColors.text2),
          ),
        ),
        title: Text(
          isTtr
              ? (isNew ? 'Tạo kịch bản' : 'Sửa kịch bản')
              : (isNew ? 'Tạo tự động hóa' : 'Sửa tự động hóa'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: MpColors.text,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: MpColors.text3,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                'Lưu',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: MpColors.blue,
                ),
              ),
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

          // ── NẾU ─────────────────────────────────────────────────────────
          if (isTtr)
            _TapToRunTriggerCard()
          else
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
                        ? _deviceName(_conditions[i].raw['deviceId'] as String? ?? '')
                        : null,
                    onTap: () => _editCondition(i),
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
                      ? _deviceName(_actions[i].raw['deviceId'] as String? ?? '')
                      : null,
                  onTap: () => _editAction(i),
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

          // ── Lịch (hidden for tap-to-run) ──────────────────────────────
          if (!isTtr) ...[
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

            // ── Execution target preview ─────────────────────────────────
            _ExecutionTargetCard(
              conditions: _conditions,
              actions: _actions,
            ),
          ],
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
        final devId = result.raw['deviceId'] as String?;
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
        options: [
          const ('device', Icons.devices_other_outlined, 'Thiết bị',
              'Gửi lệnh điều khiển thiết bị'),
          const ('scene', Icons.auto_awesome_outlined, 'Kịch bản',
              'Kích hoạt một kịch bản chạm để chạy khác'),
          const ('delay', Icons.hourglass_bottom_outlined, 'Chờ',
              'Dừng N giây rồi tiếp tục'),
          if (widget.isTapToRun)
            const ('notify', Icons.notifications_outlined, 'Thông báo',
                'Hiển thị thông báo trên thiết bị khi chạy')
          else
            const ('notify', Icons.notifications_outlined, 'Thông báo',
                'Gửi push notification cho thành viên của nhà'),
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
    } else if (type == 'scene') {
      result = await showModalBottomSheet<RuleAction>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _ScenePickerSheet(parentRef: ref),
      );
    } else if (type == 'delay') {
      result = await showModalBottomSheet<RuleAction>(
        context: context,
        builder: (ctx) => const _DelaySheet(),
      );
    } else if (type == 'notify') {
      result = await showModalBottomSheet<RuleAction>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => const _NotifyActionSheet(),
      );
    }

    if (result != null) {
      setState(() => _actions.add(result!));
      if (result.type == 'device') {
        final devId = result.raw['deviceId'] as String?;
        final devName = result.raw.remove('_device_name') as String?;
        if (devId != null && devName != null) {
          _deviceNames[devId] = devName;
        }
      }
    }
  }

  // ─── Edit existing condition ──────────────────────────────────────────────

  Future<void> _editCondition(int index) async {
    final existing = _conditions[index];
    RuleCondition? result;
    if (existing.type == 'device') {
      result = await showModalBottomSheet<RuleCondition>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _DeviceConditionSheet(
          parentRef: ref,
          initial: existing,
        ),
      );
    } else if (existing.type == 'timer') {
      result = await showModalBottomSheet<RuleCondition>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _TimerConditionSheet(initial: existing),
      );
    }
    if (result != null && mounted) {
      setState(() => _conditions[index] = result!);
      if (result.type == 'device') {
        final devId = result.raw['deviceId'] as String?;
        final devName = result.raw.remove('_device_name') as String?;
        if (devId != null && devName != null) {
          _deviceNames[devId] = devName;
        }
      }
    }
  }

  // ─── Edit existing action ────────────────────────────────────────────────

  Future<void> _editAction(int index) async {
    final existing = _actions[index];
    RuleAction? result;
    if (existing.type == 'device') {
      result = await showModalBottomSheet<RuleAction>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _DeviceActionSheet(
          parentRef: ref,
          initial: existing,
        ),
      );
    } else if (existing.type == 'scene') {
      result = await showModalBottomSheet<RuleAction>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _ScenePickerSheet(parentRef: ref, initial: existing),
      );
    } else if (existing.type == 'delay') {
      result = await showModalBottomSheet<RuleAction>(
        context: context,
        builder: (ctx) => _DelaySheet(initial: existing),
      );
    } else if (existing.type == 'notify') {
      result = await showModalBottomSheet<RuleAction>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _NotifyActionSheet(initial: existing),
      );
    }
    if (result != null && mounted) {
      setState(() => _actions[index] = result!);
      if (result.type == 'device') {
        final devId = result.raw['deviceId'] as String?;
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: MpColors.text,
        ),
        decoration: const InputDecoration(
          hintText: 'Đặt tên automation…',
          hintStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: MpColors.text3,
          ),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MpColors.border, width: 0.5),
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
                    width: 46,
                    height: 46,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.12)
                          : MpColors.surfaceAlt,
                      border: selected
                          ? Border.all(color: accent, width: 1.5)
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: selected ? accent : MpColors.text3,
                      size: 20,
                    ),
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
                  width: selected ? 30 : 26,
                  height: selected ? 30 : 26,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    boxShadow: selected
                        ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 5)]
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: MpColors.bg, size: 14)
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

// ─── Tap-to-run trigger card ──────────────────────────────────────────────────

class _TapToRunTriggerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: MpColors.amberSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.touch_app_outlined,
                      size: 13, color: MpColors.amber),
                ),
                const SizedBox(width: 8),
                const Text(
                  'NẾU',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MpColors.amber,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: MpColors.amberSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app, size: 18, color: MpColors.amber),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Kịch bản',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: MpColors.amber,
                    ),
                  ),
                ),
              ],
            ),
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
    return Container(
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
    final isAll = value == ConditionMatch.all;
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: MpColors.surfaceAlt,
        borderRadius: BorderRadius.circular(7),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? MpColors.text : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? MpColors.bg : MpColors.text3,
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
    this.onTap,
  });
  final RuleCondition condition;
  final String? deviceName;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconColor(condition);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: MpColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: color, width: 3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _conditionTitle(condition),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MpColors.text,
                      ),
                    ),
                    if (deviceName != null || _conditionSubtitle(condition).isNotEmpty)
                      Text(
                        [
                          if (deviceName != null) deviceName!,
                          if (_conditionSubtitle(condition).isNotEmpty)
                            _conditionSubtitle(condition),
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: MpColors.text3,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: MpColors.text3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static (IconData, Color) _iconColor(RuleCondition c) {
    if (c.type == 'timer') return (Icons.schedule_rounded, MpColors.amber);
    if (c.type == 'offline') return (Icons.wifi_off_rounded, MpColors.text3);
    final key = c.raw['key'] as String? ?? '';
    return switch (key) {
      'temp' || 'coolSp' => (Icons.thermostat_outlined, MpColors.red),
      'hum' => (Icons.water_drop_outlined, MpColors.blue),
      'pir' => (Icons.motion_photos_on_outlined, MpColors.violet),
      'door' => (Icons.sensor_door_outlined, MpColors.green),
      'onoff0' || 'onoff1' || 'onoff2' => (Icons.power_settings_new_rounded, MpColors.text2),
      'lux' => (Icons.wb_sunny_outlined, MpColors.amber),
      'co2' => (Icons.co2_outlined, MpColors.green),
      'power' => (Icons.bolt_outlined, MpColors.amber),
      _ => (Icons.sensors_outlined, MpColors.blue),
    };
  }
}

// ─── Action card ──────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.onDelete,
    this.deviceName,
    this.onTap,
  });
  final RuleAction action;
  final String? deviceName;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconColor(action);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: MpColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: color, width: 3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: color),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MpColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (action.type == 'device')
                      Text(
                        _actionTitle(action),
                        style: const TextStyle(
                          fontSize: 11,
                          color: MpColors.text3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (action.type == 'notify')
                      Text(
                        _actionSubtitle(action),
                        style: const TextStyle(
                          fontSize: 11,
                          color: MpColors.text3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: MpColors.text3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static (IconData, Color) _iconColor(RuleAction a) {
    if (a.type == 'delay') return (Icons.hourglass_bottom_outlined, MpColors.violet);
    if (a.type == 'notify') return (Icons.notifications_outlined, MpColors.blue);
    if (a.type == 'scene') return (Icons.auto_awesome_outlined, MpColors.amber);
    final data = a.raw['data'] as Map?;
    final hasOff = data?['onoff0'] == 0 || data?['onoff1'] == 0;
    final hasOn = data?['onoff0'] == 1 || data?['onoff1'] == 1;
    if (hasOn) return (Icons.power_settings_new_rounded, MpColors.green);
    if (hasOff) return (Icons.power_settings_new_rounded, MpColors.text3);
    return (Icons.settings_remote_outlined, MpColors.green);
  }
}

// ─── Add button ───────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: MpColors.borderStrong, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: MpColors.text2),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MpColors.text2,
              ),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: MpColors.text3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: MpColors.text3),
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
    final s = widget.schedule ?? const RuleSchedule(days: 127);

    return Container(
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 18, color: MpColors.text2),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Giới hạn thời gian',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MpColors.text,
                    ),
                  ),
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
    final hasServerOnlyAction =
        widget.actions.any((a) => _serverOnlyActionTypes.contains(a.type));
    if (hasServerOnlyAction) {
      if (mounted) setState(() => _target = 'server');
      return;
    }
    final deviceIds = [
      ...widget.conditions
          .where((c) => c.type == 'device' && c.raw['deviceId'] != null)
          .map((c) => c.raw['deviceId'] as String),
      ...widget.actions
          .where((a) => a.type == 'device' && a.raw['deviceId'] != null)
          .map((a) => a.raw['deviceId'] as String),
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
    if (_target == null) return const SizedBox.shrink();
    final isGw = _target!.startsWith('gw:');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            isGw ? Icons.router_outlined : Icons.cloud_outlined,
            size: 18,
            color: isGw ? MpColors.amber : MpColors.blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGw ? 'Thực thi trên Gateway' : 'Thực thi trên Server',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MpColors.text,
                  ),
                ),
                Text(
                  isGw ? 'Hoạt động offline, độ trễ thấp' : 'Cần kết nối cloud',
                  style: const TextStyle(fontSize: 11, color: MpColors.text3),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isGw ? MpColors.amberSoft : MpColors.blueSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isGw ? '⚡ Local' : '☁️ Cloud',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isGw ? MpColors.amber : MpColors.blue,
              ),
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
    return Container(
      decoration: const BoxDecoration(
        color: MpColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: MpColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: MpColors.text,
              ),
            ),
          ),
          ...options.map((opt) {
            final (type, icon, label, subtitle) = opt;
            return InkWell(
              onTap: () => Navigator.pop(context, type),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: MpColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: MpColors.text2, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: MpColors.text,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: MpColors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: MpColors.text3),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Device condition sheet ───────────────────────────────────────────────────

class _DeviceConditionSheet extends ConsumerStatefulWidget {
  const _DeviceConditionSheet({required this.parentRef, this.initial});
  final WidgetRef parentRef;
  final RuleCondition? initial;

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

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _key = init.raw['key'] as String?;
      _op = init.raw['op'] as String? ?? '>';
      final v = init.raw['value'];
      _value = v?.toString() ?? '';
    }
  }

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
        final keys = _availableKeys;
        if (_key == null || !keys.contains(_key)) {
          _key = keys.isNotEmpty ? keys.first : null;
          _syncOpAndValue();
        } else {
          final ops = _availableOps;
          if (!ops.contains(_op)) _op = ops.first;
        }
      });
    }
  }

  void _syncOpAndValue() {
    final ops = _availableOps;
    if (!ops.contains(_op)) _op = ops.first;
    final def = _key != null ? _meta?.states[_key!] : null;
    if (def?.type == 'bool') {
      if (_value.isEmpty) _value = '0';
    } else if (def?.type == 'enum' && def!.enumValues != null && def.enumValues!.isNotEmpty) {
      if (_value.isEmpty) _value = def.enumValues!.first;
    } else if (_value.isEmpty && def?.type == 'number') {
      _value = '0';
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text(widget.initial != null ? 'Sửa điều kiện thiết bị' : 'Thêm điều kiện thiết bị',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _DevicePicker(
              initialDeviceId: widget.initial?.raw['deviceId'] as String?,
              onSelected: (d) {
                setState(() {
                  _device = d;
                  _meta = null;
                  if (widget.initial == null ||
                      d.id != widget.initial?.raw['deviceId']) {
                    _key = null;
                  }
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
                  _syncOpAndValue();
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
                              'deviceId': _device!.id,
                              '_device_name': _device!.displayName,
                              'key': _key!,
                              'op': _op,
                              'value': num.tryParse(_value) ?? _value,
                            });
                            Navigator.pop(context, cond);
                          },
                    style: FilledButton.styleFrom(
                        backgroundColor: MpColors.text),
                    child: Text(widget.initial != null ? 'Lưu' : 'Thêm'),
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
  const _TimerConditionSheet({this.initial});
  final RuleCondition? initial;

  @override
  State<_TimerConditionSheet> createState() => _TimerConditionSheetState();
}

class _TimerConditionSheetState extends State<_TimerConditionSheet> {
  late int _days;
  late String _time;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _days = init?.raw['days'] as int? ?? 127;
    _time = init?.raw['time'] as String? ?? '07:00';
  }

  @override
  Widget build(BuildContext context) {
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
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: MpColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MpColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: MpColors.text2),
                    const SizedBox(width: 12),
                    Text(
                      _time,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: MpColors.text),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_outlined, size: 18, color: MpColors.text3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Ngày trong tuần',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                      color: on ? MpColors.text : MpColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _kDayNames[i],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: on ? MpColors.bg : MpColors.text2),
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
  const _DeviceActionSheet({required this.parentRef, this.initial});
  final WidgetRef parentRef;
  final RuleAction? initial;

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
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      final raw = init.raw['data'];
      if (raw is Map) {
        _data.addAll(Map<String, dynamic>.from(raw));
      }
    }
  }

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
      setState(() => _meta = meta);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text(widget.initial != null ? 'Sửa hành động thiết bị' : 'Thêm hành động thiết bị',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _DevicePicker(
              initialDeviceId: widget.initial?.raw['deviceId'] as String?,
              onSelected: (d) {
                setState(() {
                  _device = d;
                  _meta = null;
                  if (widget.initial == null ||
                      d.id != widget.initial?.raw['deviceId']) {
                    _data.clear();
                  }
                });
                _loadMeta(d);
              },
            ),
            if (_device != null) ...[
              const SizedBox(height: 12),
              const Text('Điều khiển',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: MpColors.text3, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              if (hasMetaKeys)
                ..._meta!.states.entries
                    .where((e) => e.value.controllable)
                    .map((e) {
                      final key = e.key;
                      final def = e.value;
                      final included = _data.containsKey(key);
                      final label = def.labelDefault ?? _keyLabel(key);
                      const disabledColor = MpColors.text3;

                      if (def.type == 'bool') {
                        final isOn = included &&
                            (_data[key] == 1 || _data[key] == true);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Checkbox(
                            value: included,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _data[key] = 1;
                              } else {
                                _data.remove(key);
                              }
                            }),
                          ),
                          title: Text(label,
                              style: TextStyle(
                                  color:
                                      included ? null : disabledColor)),
                          trailing: Switch.adaptive(
                            value: isOn,
                            onChanged: included
                                ? (v) => setState(
                                    () => _data[key] = v ? 1 : 0)
                                : null,
                          ),
                        );
                      }

                      // Non-bool types: checkbox to include, value editor below
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            dense: true,
                            title: Text(label,
                                style: TextStyle(
                                    color: included
                                        ? null
                                        : disabledColor)),
                            value: included,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _data[key] = def.type == 'number'
                                    ? (def.range?.min.round() ?? 0)
                                    : '';
                              } else {
                                _data.remove(key);
                              }
                            }),
                          ),
                          if (included)
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 16, bottom: 4),
                              child: _ActionKeyEditor(
                                stateKey: key,
                                def: def,
                                value: _data[key],
                                onChanged: (v) =>
                                    setState(() => _data[key] = v),
                              ),
                            ),
                        ],
                      );
                    })
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
                              'deviceId': _device!.id,
                              '_device_name': _device!.displayName,
                              'data': Map<String, dynamic>.from(_data),
                            });
                            Navigator.pop(context, action);
                          },
                    style: FilledButton.styleFrom(
                        backgroundColor: MpColors.text),
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
  const _DelaySheet({this.initial});
  final RuleAction? initial;

  @override
  State<_DelaySheet> createState() => _DelaySheetState();
}

class _DelaySheetState extends State<_DelaySheet> {
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _seconds = widget.initial?.raw['seconds'] as int? ?? 30;
  }

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
                  color: MpColors.text),
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

// ─── Notify action sheet ─────────────────────────────────────────────────────

class _NotifyActionSheet extends StatefulWidget {
  const _NotifyActionSheet({this.initial});
  final RuleAction? initial;

  @override
  State<_NotifyActionSheet> createState() => _NotifyActionSheetState();
}

class _NotifyActionSheetState extends State<_NotifyActionSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _msgCtrl;
  late String _target;
  late String _severity;

  @override
  void initState() {
    super.initState();
    final raw = widget.initial?.raw ?? const {};
    _titleCtrl = TextEditingController(text: raw['title'] as String? ?? '');
    _msgCtrl = TextEditingController(text: raw['message'] as String? ?? '');
    _target = raw['target'] as String? ?? 'all';
    _severity = (raw['severity'] as String? ?? 'INDETERMINATE').toUpperCase();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nội dung thông báo không được để trống')),
      );
      return;
    }
    final raw = <String, dynamic>{
      'type': 'notify',
      'message': msg,
      'target': _target,
      'severity': _severity,
    };
    final title = _titleCtrl.text.trim();
    if (title.isNotEmpty) raw['title'] = title;
    Navigator.pop(context, RuleAction(raw: raw));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Gửi thông báo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              const Text(
                'Tiêu đề (tùy chọn)',
                style: TextStyle(
                  fontSize: 11,
                  color: MpColors.text3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                maxLength: 80,
                style: const TextStyle(color: MpColors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'VD: Cảnh báo phòng khách',
                  hintStyle: const TextStyle(color: MpColors.text3),
                  filled: true,
                  fillColor: MpColors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),

              // Message
              const Text(
                'Nội dung *',
                style: TextStyle(
                  fontSize: 11,
                  color: MpColors.text3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _msgCtrl,
                maxLines: 3,
                maxLength: 200,
                style: const TextStyle(color: MpColors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'VD: Nhiệt độ phòng khách vượt 30°C',
                  hintStyle: const TextStyle(color: MpColors.text3),
                  filled: true,
                  fillColor: MpColors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),

              // Target
              const Text(
                'Gửi cho',
                style: TextStyle(
                  fontSize: 11,
                  color: MpColors.text3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ChoiceChip(
                    label: 'Tất cả thành viên',
                    selected: _target == 'all',
                    onTap: () => setState(() => _target = 'all'),
                  ),
                  _ChoiceChip(
                    label: 'Chủ nhà',
                    selected: _target == 'owner',
                    onTap: () => setState(() => _target = 'owner'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Severity
              const Text(
                'Mức độ',
                style: TextStyle(
                  fontSize: 11,
                  color: MpColors.text3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SeverityChip(
                    label: 'Thông tin',
                    color: MpColors.blue,
                    selected: _severity == 'INDETERMINATE',
                    onTap: () => setState(() => _severity = 'INDETERMINATE'),
                  ),
                  _SeverityChip(
                    label: 'Cảnh báo',
                    color: MpColors.amber,
                    selected: _severity == 'WARNING',
                    onTap: () => setState(() => _severity = 'WARNING'),
                  ),
                  _SeverityChip(
                    label: 'Nghiêm trọng',
                    color: MpColors.red,
                    selected: _severity == 'CRITICAL',
                    onTap: () => setState(() => _severity = 'CRITICAL'),
                  ),
                ],
              ),
              const SizedBox(height: 22),

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
                      onPressed: _save,
                      child: Text(widget.initial == null ? 'Thêm' : 'Lưu'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? MpColors.text : MpColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.transparent : MpColors.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? MpColors.bg : MpColors.text2,
          ),
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared: Device picker ────────────────────────────────────────────────────

class _DevicePicker extends ConsumerStatefulWidget {
  const _DevicePicker({required this.onSelected, this.initialDeviceId});

  final ValueChanged<SmarthomeDevice> onSelected;
  final String? initialDeviceId;

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
    final home = await _awaitHome();
    if (home == null) return [];
    final svc = HomeService();
    final rooms = await svc.fetchRooms(home.id);
    final all = <SmarthomeDevice>[];
    final seen = <String>{};
    for (final r in rooms) {
      for (final d in await svc.fetchDevicesInRoom(r.id)) {
        if (seen.add(d.id)) all.add(d);
      }
    }
    for (final d in await svc.fetchDevicesInHome(home.id)) {
      if (seen.add(d.id)) all.add(d);
    }
    // Populate profileName so `displayName` applies the 3-level priority
    // (label > profileName > name) — same as device cards.
    return resolveDeviceProfileMetaFromCache(all);
  }

  Future<SmarthomeHome?> _awaitHome() async {
    try {
      final homes = await ref.read(homesProvider.future);
      if (homes.isEmpty) return null;
      final selectedId = ref.read(selectedHomeIdProvider);
      return selectedId == null
          ? homes.first
          : homes.firstWhere((h) => h.id == selectedId,
              orElse: () => homes.first);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SmarthomeDevice>>(
      future: _future,
      builder: (ctx, snap) {
        final devices = snap.data ?? [];
        // Auto-select initial device once loaded.
        if (_selected == null &&
            widget.initialDeviceId != null &&
            devices.isNotEmpty) {
          final match = devices
              .where((d) => d.id == widget.initialDeviceId)
              .firstOrNull;
          if (match != null) {
            _selected = match;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onSelected(match);
            });
          }
        }
        return DropdownButtonFormField<SmarthomeDevice>(
          value: _selected,
          isExpanded: true,
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

// ─── Scene picker sheet ───────────────────────────────────────────────────────

class _ScenePickerSheet extends ConsumerWidget {
  const _ScenePickerSheet({required this.parentRef, this.initial});
  final WidgetRef parentRef;
  final RuleAction? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenesAsync = ref.watch(scenesProvider);

    return Container(
      decoration: const BoxDecoration(
        color: MpColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: MpColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chọn kịch bản',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: MpColors.text,
                ),
              ),
            ),
          ),
          scenesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: MpColors.text3),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Lỗi: $e',
                  style: const TextStyle(color: MpColors.text3)),
            ),
            data: (scenes) {
              if (scenes.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Chưa có kịch bản nào',
                    style: TextStyle(color: MpColors.text3),
                  ),
                );
              }
              final selectedId = initial?.raw['sceneId'] as String?;
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: scenes.length,
                  itemBuilder: (ctx, i) {
                    final scene = scenes[i];
                    final isSelected = scene.id == selectedId;
                    return InkWell(
                      onTap: () => Navigator.pop(
                        context,
                        RuleAction(raw: {
                          'type': 'scene',
                          'sceneId': scene.id,
                          '_scene_name': scene.name,
                        }),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? MpColors.amber
                                    : MpColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.auto_awesome,
                                size: 18,
                                color: isSelected
                                    ? Colors.white
                                    : MpColors.text3,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                scene.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: MpColors.text,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_rounded,
                                  size: 16, color: MpColors.amber),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
