import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/activity/providers/alarms_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_name_provider.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/notification_service.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class AlarmsSubTab extends ConsumerStatefulWidget {
  const AlarmsSubTab({super.key});

  @override
  ConsumerState<AlarmsSubTab> createState() => _AlarmsSubTabState();
}

class _AlarmsSubTabState extends ConsumerState<AlarmsSubTab>
    with AutomaticKeepAliveClientMixin {
  AlarmPeriod _period = AlarmPeriod.day;
  StreamSubscription<RemoteMessage>? _fcmSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fcmSub = FirebaseMessaging.onMessage.listen((_) => _invalidate());
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    super.dispose();
  }

  void _invalidate() {
    ref.invalidate(alarmsProvider(_period));
    ref.invalidate(activeUnackAlarmsCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final alarmsAsync = ref.watch(alarmsProvider(_period));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              _Chip(
                label: '1 ngày',
                active: _period == AlarmPeriod.day,
                onTap: () => setState(() => _period = AlarmPeriod.day),
              ),
              const SizedBox(width: 6),
              _Chip(
                label: '7 ngày',
                active: _period == AlarmPeriod.week,
                onTap: () => setState(() => _period = AlarmPeriod.week),
              ),
              const SizedBox(width: 6),
              _Chip(
                label: '30 ngày',
                active: _period == AlarmPeriod.month,
                onTap: () => setState(() => _period = AlarmPeriod.month),
              ),
              const SizedBox(width: 6),
              _Chip(
                label: 'Tất cả',
                active: _period == AlarmPeriod.all,
                onTap: () => setState(() => _period = AlarmPeriod.all),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: MpColors.text,
            backgroundColor: MpColors.surface,
            onRefresh: () async => _invalidate(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (alarmsAsync.isLoading && !alarmsAsync.hasValue)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: MpColors.text3,
                        strokeWidth: 1.5,
                      ),
                    ),
                  )
                else if (alarmsAsync.hasError)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: MpColors.text3, size: 36),
                            const SizedBox(height: 12),
                            const Text(
                              'Không thể tải cảnh báo',
                              style: TextStyle(
                                  color: MpColors.text,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${alarmsAsync.error}',
                              style: const TextStyle(
                                  color: MpColors.text3, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Vuốt xuống để thử lại',
                              style: TextStyle(
                                  color: MpColors.text3, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (alarmsAsync.value?.isEmpty ?? false)
                  const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none_outlined,
                              size: 40, color: MpColors.text3),
                          SizedBox(height: 12),
                          Text(
                            'Không có cảnh báo nào',
                            style: TextStyle(
                                color: MpColors.text,
                                fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Trong khoảng thời gian đã chọn',
                            style: TextStyle(
                                color: MpColors.text3, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _buildList(alarmsAsync.value!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  AlarmService get _alarmService =>
      getIt<ITbClientService>().client.getAlarmService();

  Future<void> _ackAll(List<AlarmInfo> alarms) async {
    NotificationService.suppressFor(const Duration(seconds: 10));
    await Future.wait(
      alarms.map((a) => _alarmService.ackAlarm(a.id!.id!)),
    );
    _invalidate();
  }

  Future<void> _deleteAll(List<AlarmInfo> alarms) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MpColors.surface,
        title: Text(
          'Xóa ${alarms.length} cảnh báo?',
          style: const TextStyle(
              color: MpColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Tất cả sẽ bị xóa vĩnh viễn và không thể khôi phục.',
          style: TextStyle(color: MpColors.text2, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy',
                style: TextStyle(color: MpColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa tất cả',
                style: TextStyle(
                    color: MpColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    NotificationService.suppressFor(const Duration(seconds: 10));
    await Future.wait(
      alarms.map((a) => _alarmService.deleteAlarm(a.id!.id!)),
    );
    _invalidate();
  }

  Widget _buildList(List<AlarmInfo> alarms) {
    final active = alarms.where((a) => !a.cleared).toList();
    final clearedUnack =
        alarms.where((a) => a.cleared && !a.acknowledged).toList();
    final clearedAck =
        alarms.where((a) => a.cleared && a.acknowledged).toList();

    final entries = <_ListEntry>[];
    if (active.isNotEmpty) {
      entries.add(const _SectionEntry('Đang cảnh báo'));
      for (final a in active) { entries.add(_AlarmEntry(a)); }
    }
    if (clearedUnack.isNotEmpty) {
      entries.add(_SectionEntry(
        'Đã xử lý',
        actionLabel: 'Xác nhận tất cả',
        actionColor: MpColors.amber,
        onAction: () => _ackAll(clearedUnack),
      ));
      for (final a in clearedUnack) { entries.add(_AlarmEntry(a)); }
    }
    if (clearedAck.isNotEmpty) {
      entries.add(_SectionEntry(
        'Đã xong',
        actionLabel: 'Xóa tất cả',
        actionColor: MpColors.text3,
        onAction: () => _deleteAll(clearedAck),
      ));
      for (final a in clearedAck) { entries.add(_AlarmEntry(a)); }
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final entry = entries[i];
          return switch (entry) {
            _SectionEntry(
                  :final label,
                  :final actionLabel,
                  :final actionColor,
                  :final onAction) =>
              _SectionHeader(
                  label: label,
                  actionLabel: actionLabel,
                  actionColor: actionColor,
                  onAction: onAction),
            _AlarmEntry(:final alarm) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AlarmItem(
                  key: ValueKey(alarm.id?.id),
                  alarm: alarm,
                  onRefresh: _invalidate,
                ),
              ),
          };
        },
      ),
    );
  }
}

// ─── List entry types ─────────────────────────────────────────────────────────

sealed class _ListEntry {
  const _ListEntry();
}

class _SectionEntry extends _ListEntry {
  const _SectionEntry(this.label,
      {this.actionLabel, this.actionColor, this.onAction});
  final String label;
  final String? actionLabel;
  final Color? actionColor;
  final VoidCallback? onAction;
}

class _AlarmEntry extends _ListEntry {
  const _AlarmEntry(this.alarm);
  final AlarmInfo alarm;
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.label, this.actionLabel, this.actionColor, this.onAction});
  final String label;
  final String? actionLabel;
  final Color? actionColor;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MpColors.text3,
              letterSpacing: 0.6,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const Spacer(),
            _InlineActionButton(
              label: actionLabel!,
              color: actionColor ?? MpColors.text3,
              enabled: true,
              onTap: onAction!,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Alarm card ───────────────────────────────────────────────────────────────

class _AlarmItem extends ConsumerStatefulWidget {
  const _AlarmItem({super.key, required this.alarm, required this.onRefresh});
  final AlarmInfo alarm;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_AlarmItem> createState() => _AlarmItemState();
}

class _AlarmItemState extends ConsumerState<_AlarmItem> {
  bool _busy = false;

  AlarmService get _alarmService =>
      getIt<ITbClientService>().client.getAlarmService();

  Future<void> _doClearAndAck() async {
    final alarmId = widget.alarm.id?.id;
    if (alarmId == null) return;
    setState(() => _busy = true);
    NotificationService.suppressFor(const Duration(seconds: 6));
    try {
      await _alarmService.clearAlarm(alarmId);
      await _alarmService.ackAlarm(alarmId);
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Không thể xử lý cảnh báo: $e'),
          backgroundColor: MpColors.red,
        ));
      }
    }
  }

  Future<void> _doAck() async {
    final alarmId = widget.alarm.id?.id;
    if (alarmId == null) return;
    setState(() => _busy = true);
    NotificationService.suppressFor(const Duration(seconds: 6));
    try {
      await _alarmService.ackAlarm(alarmId);
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Không thể xác nhận: $e'),
          backgroundColor: MpColors.red,
        ));
      }
    }
  }

  Future<void> _doDelete() async {
    final alarmId = widget.alarm.id?.id;
    if (alarmId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MpColors.surface,
        title: const Text(
          'Xóa cảnh báo?',
          style: TextStyle(
              color: MpColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Cảnh báo sẽ bị xóa vĩnh viễn và không thể khôi phục.',
          style: TextStyle(color: MpColors.text2, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy',
                style: TextStyle(color: MpColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa',
                style: TextStyle(
                    color: MpColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    NotificationService.suppressFor(const Duration(seconds: 6));
    try {
      await _alarmService.deleteAlarm(alarmId);
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể xóa: $e'),
            backgroundColor: MpColors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alarm = widget.alarm;
    final cleared = alarm.cleared;
    final acked = alarm.acknowledged;

    // ACTIVE_UNACK | CLEARED_UNACK | CLEARED_ACK
    final cat = !cleared
        ? _AlarmCat.active
        : (!acked ? _AlarmCat.clearedUnack : _AlarmCat.clearedAck);

    final bgColor = switch (cat) {
      _AlarmCat.active => MpColors.redSoft,
      _AlarmCat.clearedUnack => MpColors.amberSoft,
      _AlarmCat.clearedAck => MpColors.surfaceAlt,
    };
    final accentColor = switch (cat) {
      _AlarmCat.active => MpColors.red,
      _AlarmCat.clearedUnack => MpColors.amber,
      _AlarmCat.clearedAck => MpColors.borderStrong,
    };
    final titleColor = switch (cat) {
      _AlarmCat.active => MpColors.text,
      _AlarmCat.clearedUnack => MpColors.text2,
      _AlarmCat.clearedAck => MpColors.text3,
    };
    final subtitleColor =
        cat == _AlarmCat.active ? MpColors.text2 : MpColors.text3;
    final double cardOpacity = cat == _AlarmCat.clearedAck ? 0.65 : 1.0;
    final bool strikethrough = cat == _AlarmCat.clearedAck;

    final deviceName = ref
        .watch(deviceDisplayNameProvider(alarm.originator.id ?? ''))
        .valueOrNull ??
        alarm.originatorLabel ??
        alarm.originatorDisplayName ??
        alarm.originatorName ??
        '';

    return Opacity(
      opacity: cardOpacity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withValues(alpha: cat == _AlarmCat.active ? 0.25 : 0.12),
              width: 0.5,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar
                Container(width: 3, color: accentColor),
                // Card content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Severity icon
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.12),
                          ),
                          child: Icon(
                            _severityIcon(alarm.severity),
                            size: 17,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Text block
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _alarmTitle(alarm),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: cat == _AlarmCat.active
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: titleColor,
                                  height: 1.3,
                                  decoration: strikethrough
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: MpColors.text3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (deviceName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  deviceName,
                                  style: TextStyle(
                                      fontSize: 12, color: subtitleColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    _severityLabel(alarm.severity),
                                    style: TextStyle(
                                        fontSize: 11, color: accentColor),
                                  ),
                                  const SizedBox(width: 6),
                                  _TimeStamp(
                                      ts: alarm.startTs ??
                                          alarm.createdTime ??
                                          0),
                                  if (cat == _AlarmCat.clearedUnack ||
                                      cat == _AlarmCat.clearedAck) ...[
                                    const Spacer(),
                                    _InlineActionButton(
                                      label: cat == _AlarmCat.clearedUnack
                                          ? 'Xác nhận'
                                          : 'Xóa',
                                      color: cat == _AlarmCat.clearedUnack
                                          ? MpColors.amber
                                          : MpColors.text3,
                                      enabled: !_busy,
                                      onTap: cat == _AlarmCat.clearedUnack
                                          ? _doAck
                                          : _doDelete,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Menu ... chỉ hiện cho active
                        if (cat == _AlarmCat.active)
                          SizedBox(
                            width: 32,
                            height: 34,
                            child: _busy
                                ? const Center(
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: MpColors.text3),
                                    ),
                                  )
                                : PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_horiz_rounded,
                                        size: 18, color: MpColors.text3),
                                    padding: EdgeInsets.zero,
                                    color: MpColors.surface,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    onSelected: (_) => _doClearAndAck(),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'clearAndAck',
                                        child: _MenuRow(
                                            icon: Icons
                                                .check_circle_outline_rounded,
                                            label: 'Xác nhận đã xử lý',
                                            color: MpColors.text),
                                      ),
                                    ],
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _alarmTitle(AlarmInfo alarm) {
    final d = alarm.details;
    if (d is Map) {
      final t = d['title']?.toString() ?? d['message']?.toString();
      if (t != null && t.isNotEmpty) return t;
    }
    return alarm.type;
  }

  IconData _severityIcon(AlarmSeverity s) => switch (s) {
        AlarmSeverity.CRITICAL => Icons.warning_rounded,
        AlarmSeverity.MAJOR => Icons.warning_amber_rounded,
        AlarmSeverity.MINOR => Icons.info_outline_rounded,
        AlarmSeverity.WARNING => Icons.warning_amber_outlined,
        AlarmSeverity.INDETERMINATE => Icons.help_outline_rounded,
      };

  String _severityLabel(AlarmSeverity s) => switch (s) {
        AlarmSeverity.CRITICAL => 'Nghiêm trọng',
        AlarmSeverity.MAJOR => 'Cao',
        AlarmSeverity.MINOR => 'Trung bình',
        AlarmSeverity.WARNING => 'Cảnh báo',
        AlarmSeverity.INDETERMINATE => 'Không xác định',
      };
}

enum _AlarmCat { active, clearedUnack, clearedAck }

class _MenuRow extends StatelessWidget {
  const _MenuRow(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }
}

// ─── Inline action button (Xác nhận / Xóa trên card) ─────────────────────────

class _InlineActionButton extends StatelessWidget {
  const _InlineActionButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Timestamp ────────────────────────────────────────────────────────────────

class _TimeStamp extends StatelessWidget {
  const _TimeStamp({required this.ts});
  final int ts;

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;

    final hm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final label = isToday
        ? hm
        : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} $hm';

    return Text(
      label,
      style: const TextStyle(fontSize: 11, color: MpColors.text3),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? MpColors.text : MpColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? Colors.transparent : MpColors.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? MpColors.bg : MpColors.text2,
          ),
        ),
      ),
    );
  }
}
