import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/device_alert/domain/alert_rule.dart';
import 'package:thingsboard_app/modules/smarthome/device_alert/domain/device_alert_config.dart';
import 'package:thingsboard_app/modules/smarthome/device_alert/providers/device_alert_providers.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/alert_template.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/profile_metadata_providers.dart';

/// Cấu hình cảnh báo per-device. Render động từ
/// `profile.alertTemplates` × `device.alertConfig.rules`.
///
/// Spec: NOTIFICATION_SYSTEM.md §4.1.3 + §6.6.
class DeviceAlertSettingsPage extends ConsumerStatefulWidget {
  const DeviceAlertSettingsPage({
    required this.deviceId,
    required this.deviceName,
    required this.profileId,
    super.key,
  });

  final String deviceId;
  final String deviceName;
  final String profileId;

  @override
  ConsumerState<DeviceAlertSettingsPage> createState() =>
      _DeviceAlertSettingsPageState();
}

class _DeviceAlertSettingsPageState
    extends ConsumerState<DeviceAlertSettingsPage> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(deviceProfileMetadataProvider(widget.profileId));
    final configAsync = ref.watch(deviceAlertConfigProvider(widget.deviceId));
    final muteAsync = ref.watch(deviceMuteUntilProvider(widget.deviceId));

    return Scaffold(
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: MpColors.text),
        title: Column(
          children: [
            const Text(
              'Cảnh báo',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: MpColors.text,
              ),
            ),
            Text(
              widget.deviceName,
              style: const TextStyle(fontSize: 11, color: MpColors.text3),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: switch ((profileAsync, configAsync)) {
        (AsyncLoading(), _) ||
        (_, AsyncLoading()) =>
          const Center(
            child: CircularProgressIndicator(
              color: MpColors.text3,
              strokeWidth: 1.5,
            ),
          ),
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) =>
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không tải được cấu hình: $error',
                style: const TextStyle(color: MpColors.text3, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        (AsyncData(value: final profile), AsyncData(value: final config)) =>
          _buildBody(
            templates: profile.alertTemplates,
            config: config,
            muteUntil: muteAsync.valueOrNull,
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildBody({
    required List<AlertTemplate> templates,
    required DeviceAlertConfig config,
    required int? muteUntil,
  }) {
    if (templates.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_off_outlined,
                  size: 40, color: MpColors.text3),
              SizedBox(height: 12),
              Text(
                'Thiết bị này chưa hỗ trợ cảnh báo',
                style: TextStyle(
                    color: MpColors.text, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4),
              Text(
                'Cần admin bổ sung alertTemplates vào device profile',
                style: TextStyle(color: MpColors.text3, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _MuteCard(
          muteUntil: muteUntil,
          onPickDuration: _showMutePicker,
          onClear: _clearMute,
        ),
        const SizedBox(height: 14),
        const _SectionLabel('CÁC LOẠI CẢNH BÁO'),
        const SizedBox(height: 6),
        ...templates.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AlertTile(
              template: t,
              rule: config.findByKey(t.key),
              busy: _saving,
              onToggle: (enabled) => _toggleRule(t, config, enabled),
              onEdit: () => _editRule(t, config),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Toggle / edit handlers ────────────────────────────────────────────────

  Future<void> _toggleRule(
    AlertTemplate t,
    DeviceAlertConfig config,
    bool enabled,
  ) async {
    final existing = config.findByKey(t.key);
    final next = existing?.copyWith(enabled: enabled) ??
        AlertRule(
          key: t.key,
          op: t.op,
          severity: t.severity,
          enabled: enabled,
          value: t.defaultValue,
          message: t.defaultMessage,
        );
    await _saveConfig(config.upsertRule(next));
  }

  Future<void> _editRule(AlertTemplate t, DeviceAlertConfig config) async {
    final existing = config.findByKey(t.key);
    final initialValue = existing?.value ?? t.defaultValue;
    final initialMessage = existing?.message ?? t.defaultMessage ?? '';

    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditRuleSheet(
        template: t,
        initialValue: initialValue,
        initialMessage: initialMessage,
      ),
    );
    if (result == null) return;

    final next = (existing ??
            AlertRule(
              key: t.key,
              op: t.op,
              severity: t.severity,
              enabled: t.defaultEnabled,
              value: t.defaultValue,
              message: t.defaultMessage,
            ))
        .copyWith(value: result.value, message: result.message);
    await _saveConfig(config.upsertRule(next));
  }

  Future<void> _saveConfig(DeviceAlertConfig config) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(deviceAlertServiceProvider)
          .saveConfig(widget.deviceId, config);
      ref.invalidate(deviceAlertConfigProvider(widget.deviceId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lưu thất bại: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Mute handlers ─────────────────────────────────────────────────────────

  Future<void> _showMutePicker() async {
    final picked = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MuteDurationSheet(),
    );
    if (picked == null) return;

    final until = DateTime.now().add(picked).millisecondsSinceEpoch;
    try {
      await ref
          .read(deviceAlertServiceProvider)
          .setMuteUntil(widget.deviceId, until);
      ref.invalidate(deviceMuteUntilProvider(widget.deviceId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lưu thất bại: $e')),
        );
      }
    }
  }

  Future<void> _clearMute() async {
    try {
      await ref.read(deviceAlertServiceProvider).clearMute(widget.deviceId);
      ref.invalidate(deviceMuteUntilProvider(widget.deviceId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lưu thất bại: $e')),
        );
      }
    }
  }
}

// ─── Mute card ────────────────────────────────────────────────────────────────

class _MuteCard extends StatelessWidget {
  const _MuteCard({
    required this.muteUntil,
    required this.onPickDuration,
    required this.onClear,
  });

  final int? muteUntil;
  final VoidCallback onPickDuration;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final muted = muteUntil != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: muted ? MpColors.amberSoft : MpColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            muted ? Icons.notifications_paused : Icons.notifications_active_outlined,
            color: muted ? MpColors.amber : MpColors.text2,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  muted ? 'Đang tạm tắt cảnh báo' : 'Cảnh báo đang hoạt động',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MpColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  muted
                      ? 'Hết hạn lúc ${_fmtTime(muteUntil!)}'
                      : 'Tất cả các loại cảnh báo bên dưới đều có thể fire',
                  style: const TextStyle(
                    fontSize: 11,
                    color: MpColors.text3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (muted)
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Bật lại',
                  style: TextStyle(fontSize: 12, color: MpColors.blue)),
            )
          else
            TextButton(
              onPressed: onPickDuration,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Tạm tắt',
                  style: TextStyle(fontSize: 12, color: MpColors.blue)),
            ),
        ],
      ),
    );
  }

  String _fmtTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final today = DateTime.now();
    final isToday = dt.year == today.year &&
        dt.month == today.month &&
        dt.day == today.day;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (isToday) return '$h:$m';
    return '${dt.day}/${dt.month} $h:$m';
  }
}

// ─── Mute duration picker sheet ───────────────────────────────────────────────

class _MuteDurationSheet extends StatelessWidget {
  const _MuteDurationSheet();

  @override
  Widget build(BuildContext context) {
    final options = <(String, Duration)>[
      ('1 giờ', const Duration(hours: 1)),
      ('8 giờ', const Duration(hours: 8)),
      ('24 giờ', const Duration(days: 1)),
      ('7 ngày', const Duration(days: 7)),
    ];
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Tạm tắt cảnh báo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: MpColors.text,
              ),
            ),
          ),
          for (final (label, dur) in options)
            InkWell(
              onTap: () => Navigator.pop(context, dur),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 20, color: MpColors.text2),
                    const SizedBox(width: 14),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: MpColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Alert tile ───────────────────────────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.template,
    required this.rule,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
  });

  final AlertTemplate template;
  final AlertRule? rule;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final enabled = rule?.enabled ?? template.defaultEnabled;
    final value = rule?.value ?? template.defaultValue;
    final message = (rule?.message?.isNotEmpty ?? false)
        ? rule!.message!
        : (template.defaultMessage ?? '—');
    final severity = rule?.severity ?? template.severity;

    return Container(
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          // Header row: icon + title + severity + toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _severityColor(severity).withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    _iconFor(template.icon),
                    size: 16,
                    color: _severityColor(severity),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleFor(template),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: MpColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _severityLabel(severity),
                        style: TextStyle(
                          fontSize: 10,
                          color: _severityColor(severity),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: busy ? null : onToggle,
                  activeColor: MpColors.green,
                ),
              ],
            ),
          ),
          // Body row: threshold + message + edit
          if (enabled) ...[
            Container(height: 0.5, color: MpColors.border),
            InkWell(
              onTap: busy ? null : onEdit,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.tune,
                                  size: 12, color: MpColors.text3),
                              const SizedBox(width: 4),
                              Text(
                                'Ngưỡng: ${_formatCondition(template.op, value)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: MpColors.text2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.message_outlined,
                                  size: 12, color: MpColors.text3),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  message,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: MpColors.text2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined,
                        size: 16, color: MpColors.text3),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _titleFor(AlertTemplate t) {
    // labelKey i18n có thể wire sau; tạm fallback theo key.
    return t.labelKey ?? _humanizeKey(t.key);
  }

  String _humanizeKey(String key) => switch (key) {
        'door' => 'Cảm biến cửa',
        'pir' || 'motion' => 'Phát hiện chuyển động',
        'smoke' => 'Cảm biến khói',
        'gas' => 'Cảm biến khí gas',
        'leak' => 'Rò nước',
        'temp' => 'Nhiệt độ',
        'hum' => 'Độ ẩm',
        'pin' || 'bat' => 'Pin yếu',
        'co2' => 'CO₂',
        'pm25' => 'Bụi mịn PM2.5',
        'lux' => 'Ánh sáng',
        'power' => 'Công suất',
        'volt' => 'Điện áp',
        'curr' => 'Dòng điện',
        _ => key,
      };

  IconData _iconFor(String? name) => switch (name) {
        'door_open' || 'door' => Icons.sensor_door_outlined,
        'battery_alert' || 'battery_low' => Icons.battery_alert,
        'wifi_off' || 'offline' => Icons.wifi_off,
        'smoke' => Icons.local_fire_department_outlined,
        'gas' => Icons.gas_meter_outlined,
        'leak' || 'water_drop' => Icons.water_drop_outlined,
        'thermostat' => Icons.thermostat_outlined,
        'motion' || 'pir' => Icons.directions_run,
        _ => Icons.notifications_outlined,
      };

  Color _severityColor(String s) => switch (s) {
        'critical' => MpColors.red,
        'warning' => MpColors.amber,
        'info' => MpColors.blue,
        _ => MpColors.text3,
      };

  String _severityLabel(String s) => switch (s) {
        'critical' => 'NGHIÊM TRỌNG',
        'warning' => 'CẢNH BÁO',
        'info' => 'THÔNG TIN',
        _ => s.toUpperCase(),
      };

  String _formatCondition(String op, dynamic value) {
    if (op == '<>' && value is List && value.length == 2) {
      return 'trong khoảng [${value[0]}, ${value[1]}]';
    }
    final opLabel = switch (op) {
      '>' => '>',
      '<' => '<',
      '>=' => '≥',
      '<=' => '≤',
      '==' => '=',
      '!=' => '≠',
      _ => op,
    };
    return '$opLabel $value';
  }
}

// ─── Edit rule sheet ──────────────────────────────────────────────────────────

class _EditResult {
  const _EditResult({required this.value, required this.message});
  final dynamic value;
  final String? message;
}

class _EditRuleSheet extends StatefulWidget {
  const _EditRuleSheet({
    required this.template,
    required this.initialValue,
    required this.initialMessage,
  });

  final AlertTemplate template;
  final dynamic initialValue;
  final String initialMessage;

  @override
  State<_EditRuleSheet> createState() => _EditRuleSheetState();
}

class _EditRuleSheetState extends State<_EditRuleSheet> {
  late final TextEditingController _msgCtrl;
  late final TextEditingController _valueCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;

  bool get _isRange => widget.template.op == '<>';

  @override
  void initState() {
    super.initState();
    _msgCtrl = TextEditingController(text: widget.initialMessage);
    if (_isRange &&
        widget.initialValue is List &&
        (widget.initialValue as List).length == 2) {
      final list = widget.initialValue as List;
      _minCtrl = TextEditingController(text: '${list[0]}');
      _maxCtrl = TextEditingController(text: '${list[1]}');
      _valueCtrl = TextEditingController();
    } else {
      _valueCtrl = TextEditingController(text: '${widget.initialValue ?? ''}');
      _minCtrl = TextEditingController();
      _maxCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _valueCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _save() {
    dynamic value;
    if (_isRange) {
      final mn = num.tryParse(_minCtrl.text);
      final mx = num.tryParse(_maxCtrl.text);
      if (mn == null || mx == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Min/max phải là số')),
        );
        return;
      }
      value = [mn, mx];
    } else {
      // Op == hỗ trợ cả số lẫn chuỗi (vd door == 1, hoặc state == 'open')
      final txt = _valueCtrl.text.trim();
      value = num.tryParse(txt) ?? txt;
    }
    final msg = _msgCtrl.text.trim();
    Navigator.pop(
      context,
      _EditResult(value: value, message: msg.isEmpty ? null : msg),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: MpColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                widget.template.labelKey ?? widget.template.key,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: MpColors.text,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Operator: ${widget.template.op}',
                style: const TextStyle(fontSize: 12, color: MpColors.text3),
              ),
            ),
            // Threshold inputs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _isRange
                  ? Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'Min',
                            controller: _minCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _LabeledField(
                            label: 'Max',
                            controller: _maxCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                          ),
                        ),
                      ],
                    )
                  : _LabeledField(
                      label: 'Ngưỡng',
                      controller: _valueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                    ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _LabeledField(
                label: 'Message',
                controller: _msgCtrl,
                maxLines: 3,
                maxLength: 200,
                hint: widget.template.defaultMessage ?? '',
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy',
                          style: TextStyle(color: MpColors.text2)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: MpColors.text,
                        foregroundColor: MpColors.bg,
                      ),
                      child: const Text('Lưu'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: MpColors.text3,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(color: MpColors.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: MpColors.text3),
            filled: true,
            fillColor: MpColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            counterText: '',
          ),
        ),
      ],
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: MpColors.text3,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
