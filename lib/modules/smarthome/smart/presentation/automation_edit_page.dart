import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/profile_metadata_providers.dart';
import 'package:thingsboard_app/modules/smarthome/smart/domain/entities/automation_rule.dart';
import 'package:thingsboard_app/modules/smarthome/smart/providers/automation_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/automation_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/execution_target_resolver.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';
import 'package:uuid/uuid.dart';

class AutomationEditPage extends ConsumerStatefulWidget {
  const AutomationEditPage({
    this.rule,
    this.prefillName,
    this.prefillConditions,
    this.prefillActions,
    super.key,
  });

  /// null → create new rule.
  final AutomationRule? rule;

  /// Optional seed values used only when [rule] is null (create mode).
  /// Useful for quick actions on device detail pages that jump into the
  /// editor with the device already populated as a condition or action.
  final String? prefillName;
  final List<RuleCondition>? prefillConditions;
  final List<RuleAction>? prefillActions;

  @override
  ConsumerState<AutomationEditPage> createState() => _AutomationEditPageState();
}

class _AutomationEditPageState extends ConsumerState<AutomationEditPage> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1 — Basic Info
  late String _name;
  late String _icon;
  late String _color;

  // Step 2 — Conditions
  late List<RuleCondition> _conditions;
  late ConditionMatch _conditionMatch;

  // Step 3 — Actions
  late List<RuleAction> _actions;

  // Step 4 — Schedule
  late RuleSchedule? _schedule;

  bool _saving = false;
  String? _executionTarget; // resolved before save

  static const _icons = [
    'auto_awesome', 'wb_sunny', 'nights_stay', 'thermostat',
    'schedule', 'lightbulb', 'security',
  ];
  static const _colors = [
    '#2196F3', '#FF9800', '#4CAF50', '#E91E63',
    '#9C27B0', '#FF5722', '#607D8B',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _name = r?.name ?? widget.prefillName ?? '';
    _icon = r?.icon ?? 'auto_awesome';
    _color = r?.color ?? '#2196F3';
    _conditions =
        r?.conditions.toList() ?? widget.prefillConditions?.toList() ?? [];
    _conditionMatch = r?.conditionMatch ?? ConditionMatch.all;
    _actions = r?.actions.toList() ?? widget.prefillActions?.toList() ?? [];
    _schedule = r?.schedule;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool get _canProceed {
    return switch (_currentStep) {
      0 => _name.trim().isNotEmpty,
      1 => true, // conditions optional (tap-to-run)
      2 => _actions.isNotEmpty,
      3 => true,
      _ => false,
    };
  }

  // ─── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final home = ref.read(selectedHomeProvider).valueOrNull;
      if (home == null) return;

      // Collect all device IDs from conditions + actions
      final deviceIds = [
        ..._conditions
            .where((c) => c.type == 'device' && c.raw['device_id'] != null)
            .map((c) => c.raw['device_id'] as String),
        ..._actions
            .where((a) => a.type == 'device' && a.raw['device_id'] != null)
            .map((a) => a.raw['device_id'] as String),
      ];

      _executionTarget =
          await ExecutionTargetResolver().resolve(deviceIds);

      final id = widget.rule?.id ?? const Uuid().v4();
      final rule = AutomationRule(
        id: id,
        name: _name.trim(),
        icon: _icon,
        color: _color,
        enabled: widget.rule?.enabled ?? true,
        ts: DateTime.now().millisecondsSinceEpoch,
        executionTarget: _executionTarget!,
        schedule: _schedule,
        conditionMatch: _conditionMatch,
        conditions: _conditions,
        actions: _actions,
      );

      final svc = AutomationService();
      if (rule.isGatewayRule) {
        final currentIndex = (await ref.read(
          gatewayRuleIndexProvider(rule.gatewayId!).future,
        ));
        await svc.saveGatewayRule(rule.gatewayId!, rule, currentIndex);
      } else {
        final currentRules =
            await ref.read(serverRulesProvider.future);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu rule: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isNew = widget.rule == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Tạo automation' : 'Sửa automation'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _StepIndicator(current: _currentStep, onTap: _goToStep),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1BasicInfo(
                  name: _name,
                  icon: _icon,
                  color: _color,
                  icons: _icons,
                  colors: _colors,
                  onNameChanged: (v) => setState(() => _name = v),
                  onIconChanged: (v) => setState(() => _icon = v),
                  onColorChanged: (v) => setState(() => _color = v),
                ),
                _Step2Conditions(
                  conditions: _conditions,
                  conditionMatch: _conditionMatch,
                  onChanged: (c, m) =>
                      setState(() { _conditions = c; _conditionMatch = m; }),
                ),
                _Step3Actions(
                  actions: _actions,
                  onChanged: (a) => setState(() => _actions = a),
                ),
                _Step4Schedule(
                  schedule: _schedule,
                  onChanged: (s) => setState(() => _schedule = s),
                ),
              ],
            ),
          ),
          _StepNavBar(
            currentStep: _currentStep,
            totalSteps: 4,
            canProceed: _canProceed,
            saving: _saving,
            onBack: () => _goToStep(_currentStep - 1),
            onNext: () => _goToStep(_currentStep + 1),
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

// ─── Step Indicator ──────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.onTap});

  final int current;
  final ValueChanged<int> onTap;

  static const _labels = ['Thông tin', 'Điều kiện', 'Hành động', 'Lịch'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final active = i == current;
          final done = i < current;
          return Expanded(
            child: GestureDetector(
              onTap: done ? () => onTap(i) : null,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: active
                        ? scheme.primary
                        : done
                            ? scheme.primary.withValues(alpha: 0.4)
                            : scheme.surfaceContainerHighest,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: (active || done) ? scheme.onPrimary : null,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[i],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: active ? scheme.primary : null,
                        ),
                  ),
                  if (i < _labels.length - 1)
                    const SizedBox.shrink()
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Step Nav Bar ────────────────────────────────────────────────────────────

class _StepNavBar extends StatelessWidget {
  const _StepNavBar({
    required this.currentStep,
    required this.totalSteps,
    required this.canProceed,
    required this.saving,
    required this.onBack,
    required this.onNext,
    required this.onSave,
  });

  final int currentStep;
  final int totalSteps;
  final bool canProceed;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == totalSteps - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            if (currentStep > 0)
              OutlinedButton(
                onPressed: saving ? null : onBack,
                child: const Text('Quay lại'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: (canProceed && !saving)
                  ? (isLast ? onSave : onNext)
                  : null,
              child: isLast
                  ? (saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Lưu'))
                  : const Text('Tiếp theo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 1: Basic Info ───────────────────────────────────────────────────────

class _Step1BasicInfo extends StatelessWidget {
  const _Step1BasicInfo({
    required this.name,
    required this.icon,
    required this.color,
    required this.icons,
    required this.colors,
    required this.onNameChanged,
    required this.onIconChanged,
    required this.onColorChanged,
  });

  final String name;
  final String icon;
  final String color;
  final List<String> icons;
  final List<String> colors;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onIconChanged;
  final ValueChanged<String> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Tên automation',
            hintText: 'Bật đèn lúc 7h sáng…',
            border: OutlineInputBorder(),
          ),
          controller: TextEditingController(text: name)
            ..selection = TextSelection.collapsed(offset: name.length),
          onChanged: onNameChanged,
        ),
        const SizedBox(height: 20),
        Text('Biểu tượng', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: icons.map((ic) {
            final selected = ic == icon;
            return GestureDetector(
              onTap: () => onIconChanged(ic),
              child: CircleAvatar(
                backgroundColor: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  _iconData(ic),
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text('Màu sắc', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: colors.map((c) {
            final selected = c == color;
            return GestureDetector(
              onTap: () => onColorChanged(c),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _parseColor(c),
                  border: selected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        )
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _iconData(String name) => switch (name) {
        'wb_sunny' => Icons.wb_sunny,
        'nights_stay' => Icons.nights_stay,
        'thermostat' => Icons.thermostat,
        'schedule' => Icons.schedule,
        'lightbulb' => Icons.lightbulb,
        'security' => Icons.security,
        _ => Icons.auto_awesome,
      };

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }
}

// ─── Step 2: Conditions ───────────────────────────────────────────────────────

class _Step2Conditions extends ConsumerWidget {
  const _Step2Conditions({
    required this.conditions,
    required this.conditionMatch,
    required this.onChanged,
  });

  final List<RuleCondition> conditions;
  final ConditionMatch conditionMatch;
  final void Function(List<RuleCondition>, ConditionMatch) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // AND / OR toggle
        Row(
          children: [
            Text('Khớp', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 12),
            SegmentedButton<ConditionMatch>(
              segments: const [
                ButtonSegment(value: ConditionMatch.all, label: Text('TẤT CẢ (AND)')),
                ButtonSegment(value: ConditionMatch.any, label: Text('BẤT KỲ (OR)')),
              ],
              selected: {conditionMatch},
              onSelectionChanged: (s) =>
                  onChanged(conditions, s.first),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Condition list
        ...conditions.asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;
          return _ConditionTile(
            condition: c,
            onDelete: () {
              final updated = [...conditions]..removeAt(i);
              onChanged(updated, conditionMatch);
            },
          );
        }),
        const SizedBox(height: 8),
        // Add condition buttons
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.devices),
              label: const Text('Thiết bị'),
              onPressed: () => _addDeviceCondition(context, ref),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: const Text('Hẹn giờ'),
              onPressed: () => _addTimerCondition(context),
            ),
          ],
        ),
        if (conditions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              'Không có điều kiện → rule chạy thủ công (Tap to run)',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Future<void> _addDeviceCondition(BuildContext ctx, WidgetRef ref) async {
    final result = await showDialog<RuleCondition>(
      context: ctx,
      builder: (_) => _DeviceConditionDialog(ref: ref),
    );
    if (result != null) {
      onChanged([...conditions, result], conditionMatch);
    }
  }

  Future<void> _addTimerCondition(BuildContext ctx) async {
    final result = await showDialog<RuleCondition>(
      context: ctx,
      builder: (_) => const _TimerConditionDialog(),
    );
    if (result != null) {
      onChanged([...conditions, result], conditionMatch);
    }
  }
}

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({required this.condition, required this.onDelete});

  final RuleCondition condition;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final raw = condition.raw;
    String subtitle;
    IconData icon;

    if (condition.type == 'timer') {
      final days = raw['days'] as int? ?? 127;
      final time = raw['time'] as String? ?? '00:00';
      subtitle = 'Hẹn giờ $time · ${_daysLabel(days)}';
      icon = Icons.schedule;
    } else {
      final key = raw['key'] as String? ?? '';
      final op = raw['op'] as String? ?? '==';
      final value = raw['value'];
      subtitle = '$key $op $value';
      icon = Icons.device_hub;
    }

    return ListTile(
      leading: Icon(icon),
      title: Text(condition.type == 'timer' ? 'Hẹn giờ' : 'Thiết bị'),
      subtitle: Text(subtitle),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }

  String _daysLabel(int mask) {
    if (mask == 127 || mask == 255) return 'Mỗi ngày';
    const names = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    final days = <String>[];
    for (int i = 0; i < 7; i++) {
      if (mask & (1 << i) != 0) days.add(names[i]);
    }
    return days.join(', ');
  }
}

// ─── Step 3: Actions ──────────────────────────────────────────────────────────

class _Step3Actions extends ConsumerWidget {
  const _Step3Actions({required this.actions, required this.onChanged});

  final List<RuleAction> actions;
  final ValueChanged<List<RuleAction>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...actions.asMap().entries.map((e) {
          final i = e.key;
          final a = e.value;
          return _ActionTile(
            action: a,
            onDelete: () {
              final updated = [...actions]..removeAt(i);
              onChanged(updated);
            },
          );
        }),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.devices),
              label: const Text('Thiết bị'),
              onPressed: () => _addDeviceAction(context, ref),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.timer),
              label: const Text('Chờ'),
              onPressed: () => _addDelayAction(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addDeviceAction(BuildContext ctx, WidgetRef ref) async {
    final result = await showDialog<RuleAction>(
      context: ctx,
      builder: (_) => _DeviceActionDialog(ref: ref),
    );
    if (result != null) onChanged([...actions, result]);
  }

  Future<void> _addDelayAction(BuildContext ctx) async {
    final result = await showDialog<RuleAction>(
      context: ctx,
      builder: (_) => const _DelayActionDialog(),
    );
    if (result != null) onChanged([...actions, result]);
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.onDelete});

  final RuleAction action;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final raw = action.raw;
    String subtitle;
    IconData icon;

    if (action.type == 'delay') {
      final s = raw['seconds'] as int? ?? 1;
      subtitle = 'Chờ $s giây';
      icon = Icons.timer;
    } else {
      final data = raw['data'] as Map? ?? {};
      subtitle = data.entries.map((e) => '${e.key}=${e.value}').join(', ');
      icon = Icons.flash_on;
    }

    return ListTile(
      leading: Icon(icon),
      title: Text(action.type == 'delay' ? 'Chờ' : 'Điều khiển thiết bị'),
      subtitle: Text(subtitle),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}

// ─── Step 4: Schedule ────────────────────────────────────────────────────────

class _Step4Schedule extends StatefulWidget {
  const _Step4Schedule({required this.schedule, required this.onChanged});

  final RuleSchedule? schedule;
  final ValueChanged<RuleSchedule?> onChanged;

  @override
  State<_Step4Schedule> createState() => _Step4ScheduleState();
}

class _Step4ScheduleState extends State<_Step4Schedule> {
  late bool _hasSchedule;
  late int _days;
  String? _timeFrom;
  String? _timeTo;

  static const _dayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

  @override
  void initState() {
    super.initState();
    _hasSchedule = widget.schedule != null;
    _days = widget.schedule?.days ?? 127;
    _timeFrom = widget.schedule?.timeFrom;
    _timeTo = widget.schedule?.timeTo;
  }

  void _notify() {
    if (!_hasSchedule) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(RuleSchedule(
      days: _days,
      timeFrom: _timeFrom,
      timeTo: _timeTo,
    ));
  }

  Future<void> _pickTime(bool isFrom) async {
    final current = isFrom ? _timeFrom : _timeTo;
    TimeOfDay initial = TimeOfDay.now();
    if (current != null) {
      final parts = current.split(':');
      if (parts.length == 2) {
        initial = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final str =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isFrom) {
          _timeFrom = str;
        } else {
          _timeTo = str;
        }
        _notify();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Giới hạn thời gian'),
          value: _hasSchedule,
          onChanged: (v) {
            setState(() => _hasSchedule = v);
            _notify();
          },
        ),
        if (_hasSchedule) ...[
          const SizedBox(height: 8),
          Text('Ngày trong tuần',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(7, (i) {
              final selected = _days & (1 << i) != 0;
              return FilterChip(
                label: Text(_dayNames[i]),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _days |= (1 << i);
                    } else {
                      _days &= ~(1 << i);
                    }
                    _notify();
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          Text('Khoảng giờ hiệu lực',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(true),
                  child: Text(_timeFrom ?? 'Từ giờ…'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('→'),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(false),
                  child: Text(_timeTo ?? 'Đến giờ…'),
                ),
              ),
              if (_timeFrom != null || _timeTo != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _timeFrom = null;
                      _timeTo = null;
                      _notify();
                    });
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        // Execution target preview (resolved at save time)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nơi thực thi',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                const Text(
                  'Sẽ được phân tích tự động khi lưu:\n'
                  '⚡ Gateway local — nếu tất cả thiết bị cùng 1 gateway\n'
                  '☁️ Server — nếu thiết bị thuộc nhiều gateway hoặc cloud-only',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Dialogs: Device Condition ────────────────────────────────────────────────

class _DeviceConditionDialog extends ConsumerStatefulWidget {
  const _DeviceConditionDialog({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_DeviceConditionDialog> createState() =>
      _DeviceConditionDialogState();
}

class _DeviceConditionDialogState
    extends ConsumerState<_DeviceConditionDialog> {
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
      // automation caps override
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
    final meta = await ref
        .read(profileMetadataServiceProvider)
        .getForProfile(profileId);
    if (mounted) {
      setState(() {
        _meta = meta;
        // reset key to first available
        _key = _availableKeys.isNotEmpty ? _availableKeys.first : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = _availableKeys;
    final ops = _availableOps;
    final currentKey = _key ?? (keys.isNotEmpty ? keys.first : null);

    return AlertDialog(
      title: const Text('Thêm điều kiện thiết bị'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: keys.contains(currentKey) ? currentKey : null,
              decoration: const InputDecoration(labelText: 'Key'),
              items: keys
                  .map((k) {
                    final label =
                        _meta?.states[k]?.labelDefault ?? k;
                    return DropdownMenuItem(
                      value: k,
                      child: Text('$label ($k)'),
                    );
                  })
                  .toList(),
              onChanged: (v) => setState(() {
                _key = v;
                // Reset op to first valid for new key
                final newOps = _availableOps;
                if (!newOps.contains(_op)) _op = newOps.first;
              }),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: ops.contains(_op) ? _op : ops.first,
              decoration: const InputDecoration(labelText: 'Toán tử'),
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: (_device == null || _key == null)
              ? null
              : () {
                  final cond = RuleCondition(raw: {
                    'type': 'device',
                    'device_id': _device!.id,
                    'key': _key!,
                    'op': _op,
                    'value': num.tryParse(_value) ?? _value,
                  });
                  Navigator.pop(context, cond);
                },
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}

// ─── Dialogs: Timer Condition ────────────────────────────────────────────────

class _TimerConditionDialog extends StatefulWidget {
  const _TimerConditionDialog();

  @override
  State<_TimerConditionDialog> createState() => _TimerConditionDialogState();
}

class _TimerConditionDialogState extends State<_TimerConditionDialog> {
  int _days = 127;
  String _time = '07:00';

  static const _dayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm hẹn giờ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thời gian:'),
            OutlinedButton(
              onPressed: _pickTime,
              child: Text(_time),
            ),
            const SizedBox(height: 12),
            const Text('Ngày trong tuần:'),
            Wrap(
              spacing: 4,
              children: List.generate(7, (i) {
                final on = _days & (1 << i) != 0;
                return FilterChip(
                  label: Text(_dayNames[i]),
                  selected: on,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _days |= (1 << i);
                    } else {
                      _days &= ~(1 << i);
                    }
                  }),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            final cond = RuleCondition(raw: {
              'type': 'timer',
              'days': _days,
              'time': _time,
            });
            Navigator.pop(context, cond);
          },
          child: const Text('Thêm'),
        ),
      ],
    );
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 7,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        _time =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }
}

// ─── Dialogs: Device Action ───────────────────────────────────────────────────

class _DeviceActionDialog extends ConsumerStatefulWidget {
  const _DeviceActionDialog({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_DeviceActionDialog> createState() =>
      _DeviceActionDialogState();
}

class _DeviceActionDialogState extends ConsumerState<_DeviceActionDialog> {
  SmarthomeDevice? _device;
  ProfileMetadata? _meta;
  final Map<String, dynamic> _data = {};
  // Controllers for manual key/value entry (fallback when no metadata)
  final _keyController = TextEditingController();
  final _valController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    _valController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta(SmarthomeDevice device) async {
    final profileId = device.deviceProfileId ?? '';
    if (profileId.isEmpty) {
      setState(() => _meta = null);
      return;
    }
    final meta = await ref
        .read(profileMetadataServiceProvider)
        .getForProfile(profileId);
    if (mounted) {
      setState(() {
        _meta = meta;
        _data.clear();
        // Pre-fill controllable keys with default values
        if (meta != null && !meta.isEmpty) {
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
    final hasMetaKeys =
        _meta != null && _meta!.states.values.any((d) => d.controllable);

    return AlertDialog(
      title: const Text('Thêm hành động thiết bị'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              Text('Dữ liệu điều khiển',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              if (hasMetaKeys)
                // Metadata-driven: show editable fields per controllable key
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
                // Fallback: manual key/value input
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
                        controller: _keyController,
                        decoration: const InputDecoration(
                          hintText: 'key (onoff0…)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _valController,
                        decoration: const InputDecoration(
                          hintText: 'value',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final k = _keyController.text.trim();
                        final v = _valController.text.trim();
                        if (k.isNotEmpty && v.isNotEmpty) {
                          setState(() {
                            _data[k] = num.tryParse(v) ?? v;
                            _keyController.clear();
                            _valController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: (_device == null || _data.isEmpty)
              ? null
              : () {
                  final action = RuleAction(raw: {
                    'type': 'device',
                    'device_id': _device!.id,
                    'data': Map<String, dynamic>.from(_data),
                  });
                  Navigator.pop(context, action);
                },
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}

// ─── Metadata-driven value input (C-A-11) ────────────────────────────────────

/// Smart input widget that adapts to [StateDef.type], [StateDef.range],
/// and [StateDef.enumValues] to show the most appropriate input control.
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
  late String _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
  }

  @override
  void didUpdateWidget(_ValueInput old) {
    super.didUpdateWidget(old);
    if (old.stateKey != widget.stateKey) {
      _current = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    if (def == null) {
      return _textField('Giá trị');
    }

    switch (def.type) {
      case 'bool':
        return DropdownButtonFormField<String>(
          value: ['0', '1'].contains(_current) ? _current : '1',
          decoration: const InputDecoration(labelText: 'Giá trị'),
          items: const [
            DropdownMenuItem(value: '1', child: Text('Bật (1)')),
            DropdownMenuItem(value: '0', child: Text('Tắt (0)')),
          ],
          onChanged: (v) {
            setState(() => _current = v!);
            widget.onChanged(v!);
          },
        );

      case 'enum':
        final values = def.enumValues ?? [];
        if (values.isEmpty) return _textField('Giá trị');
        final safeVal = values.contains(_current) ? _current : values.first;
        return DropdownButtonFormField<String>(
          value: safeVal,
          decoration: const InputDecoration(labelText: 'Giá trị'),
          items: values
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) {
            setState(() => _current = v!);
            widget.onChanged(v!);
          },
        );

      case 'number':
        if (def.range != null) {
          final range = def.range!;
          final numVal =
              double.tryParse(_current) ?? range.min;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Giá trị',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    '${numVal.toStringAsFixed(def.precision ?? 0)} ${def.unit ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Slider(
                value: numVal.clamp(range.min, range.max),
                min: range.min,
                max: range.max,
                divisions: ((range.max - range.min) / (def.precision == 0 ? 1 : 0.1))
                    .round()
                    .clamp(1, 200),
                onChanged: (v) {
                  final s = v.toStringAsFixed(def.precision ?? 0);
                  setState(() => _current = s);
                  widget.onChanged(s);
                },
              ),
            ],
          );
        }
        return _textField(
          'Giá trị${def.unit != null ? ' (${def.unit})' : ''}',
          type: TextInputType.number,
        );

      default:
        return _textField('Giá trị');
    }
  }

  Widget _textField(String label, {TextInputType? type}) {
    return TextFormField(
      initialValue: _current,
      decoration: InputDecoration(labelText: label),
      keyboardType: type ?? TextInputType.text,
      onChanged: (v) {
        _current = v;
        widget.onChanged(v);
      },
    );
  }
}

/// Row for editing a single action key in metadata-driven mode.
class _ActionKeyEditor extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final label = def.labelDefault ?? stateKey;

    switch (def.type) {
      case 'bool':
        final isOn = value == 1 || value == true || value == '1';
        return SwitchListTile(
          dense: true,
          title: Text(label,
              style: const TextStyle(fontSize: 14)),
          value: isOn,
          onChanged: (v) => onChanged(v ? 1 : 0),
        );

      case 'enum':
        final values = def.enumValues ?? [];
        final current = value?.toString();
        return DropdownButtonFormField<String>(
          value: values.contains(current) ? current : null,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
          ),
          items: values
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => onChanged(v),
        );

      case 'number':
        if (def.range != null) {
          final range = def.range!;
          final numVal = (value is num
                  ? (value as num).toDouble()
                  : double.tryParse(value?.toString() ?? '') ?? range.min)
              .clamp(range.min, range.max);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 14)),
                  Text(
                    '${numVal.toStringAsFixed(def.precision ?? 0)} ${def.unit ?? ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              Slider(
                value: numVal,
                min: range.min,
                max: range.max,
                divisions: ((range.max - range.min) /
                        (def.precision == 0 ? 1 : 0.1))
                    .round()
                    .clamp(1, 200),
                onChanged: (v) => onChanged(
                    num.tryParse(v.toStringAsFixed(
                            def.precision ?? 0)) ??
                        v),
              ),
            ],
          );
        }
        return TextFormField(
          initialValue: value?.toString() ?? '0',
          decoration: InputDecoration(
            labelText: '$label${def.unit != null ? ' (${def.unit})' : ''}',
            isDense: true,
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) => onChanged(num.tryParse(v) ?? v),
        );

      default:
        return TextFormField(
          initialValue: value?.toString() ?? '',
          decoration: InputDecoration(labelText: label, isDense: true),
          onChanged: onChanged,
        );
    }
  }
}

// ─── Dialogs: Delay Action ────────────────────────────────────────────────────

class _DelayActionDialog extends StatefulWidget {
  const _DelayActionDialog();

  @override
  State<_DelayActionDialog> createState() => _DelayActionDialogState();
}

class _DelayActionDialogState extends State<_DelayActionDialog> {
  int _seconds = 30;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm hành động chờ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$_seconds giây',
              style: Theme.of(context).textTheme.headlineMedium),
          Slider(
            value: _seconds.toDouble(),
            min: 1,
            max: 3600,
            divisions: 100,
            label: '$_seconds giây',
            onChanged: (v) => setState(() => _seconds = v.round()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            final action = RuleAction(raw: {'type': 'delay', 'seconds': _seconds});
            Navigator.pop(context, action);
          },
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}

// ─── Shared: Device Picker ────────────────────────────────────────────────────

/// Lists all devices across all rooms of the selected home for selection.
class _DevicePicker extends ConsumerWidget {
  const _DevicePicker({required this.onSelected});

  final ValueChanged<SmarthomeDevice> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);
    return rooms.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Lỗi: $e'),
      data: (roomList) {
        return FutureBuilder<List<SmarthomeDevice>>(
          future: _loadAllDevices(roomList.map((r) => r.id).toList()),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const LinearProgressIndicator();
            }
            final devices = snap.data!;
            if (devices.isEmpty) {
              return const Text('Không có thiết bị nào');
            }
            return DropdownButtonFormField<SmarthomeDevice>(
              decoration: const InputDecoration(labelText: 'Thiết bị'),
              items: devices
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.name),
                      ))
                  .toList(),
              onChanged: (d) { if (d != null) onSelected(d); },
            );
          },
        );
      },
    );
  }

  Future<List<SmarthomeDevice>> _loadAllDevices(List<String> roomIds) async {
    final svc = HomeService();
    final all = <SmarthomeDevice>[];
    for (final id in roomIds) {
      all.addAll(await svc.fetchDevicesInRoom(id));
    }
    return all;
  }
}
