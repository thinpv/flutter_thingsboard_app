import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

class _AlarmTimeRange {
  const _AlarmTimeRange(this.startTime, this.endTime);
  final int startTime;
  final int endTime;

  @override
  bool operator ==(Object other) =>
      other is _AlarmTimeRange &&
      other.startTime == startTime &&
      other.endTime == endTime;

  @override
  int get hashCode => Object.hash(startTime, endTime);
}

final _alarmsProvider = FutureProvider.autoDispose
    .family<List<AlarmInfo>, _AlarmTimeRange>((ref, range) async {
  final client = getIt<ITbClientService>().client;
  final query = AlarmQueryV2(
    TimePageLink(
      100,
      0,
      null,
      SortOrder('createdTime', Direction.DESC),
      range.startTime,
      range.endTime,
    ),
  );
  final page = await client.getAlarmService().getAllAlarmsV2(query);
  return page.data;
});

// ─── Main widget ──────────────────────────────────────────────────────────────

class ActivityTab extends ConsumerStatefulWidget {
  const ActivityTab({super.key});

  @override
  ConsumerState<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<ActivityTab> {
  _Period _period = _Period.today;

  _AlarmTimeRange get _range {
    final now = DateTime.now();
    final end = now.millisecondsSinceEpoch;
    final start = switch (_period) {
      _Period.today =>
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
      _Period.week =>
        now.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
      _Period.month =>
        now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
    };
    return _AlarmTimeRange(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final alarmsAsync = ref.watch(_alarmsProvider(_range));

    return Scaffold(
      backgroundColor: MpColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Text(
                'Hoạt động',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.22,
                  color: MpColors.text,
                ),
              ),
            ),

            // ── Period chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Hôm nay',
                    active: _period == _Period.today,
                    onTap: () => setState(() => _period = _Period.today),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: '7 ngày',
                    active: _period == _Period.week,
                    onTap: () => setState(() => _period = _Period.week),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: '30 ngày',
                    active: _period == _Period.month,
                    onTap: () => setState(() => _period = _Period.month),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: RefreshIndicator(
                color: MpColors.text,
                backgroundColor: MpColors.surface,
                onRefresh: () async => ref.invalidate(_alarmsProvider(_range)),
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
                                  'Không thể tải lịch sử',
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
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final alarms = alarmsAsync.value!;
                              return _AlarmItem(
                                alarm: alarms[i],
                                isLast: i == alarms.length - 1,
                              );
                            },
                            childCount: alarmsAsync.value?.length ?? 0,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Period { today, week, month }

// ─── Alarm item (timeline row) ────────────────────────────────────────────────

class _AlarmItem extends StatelessWidget {
  const _AlarmItem({required this.alarm, required this.isLast});
  final AlarmInfo alarm;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ts = alarm.startTs ?? alarm.createdTime ?? 0;
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final dotColor = _severityColor(alarm.severity);
    final timeStr = _timeStr(dt);
    final title = _title();
    final sub = _subtitle();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                timeStr,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, color: MpColors.text3),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Dot + connector
          SizedBox(
            width: 10,
            child: Stack(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: Border.all(color: MpColors.bg, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.18),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Positioned(
                    top: 18,
                    left: 4,
                    bottom: -20,
                    child: Container(width: 1, color: MpColors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MpColors.text,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 11, color: MpColors.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeStr(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _title() {
    final device = alarm.originatorDisplayName ??
        alarm.originatorName ??
        alarm.originator.id ?? '';
    if (device.isEmpty) return alarm.type;
    return '$device — ${alarm.type}';
  }

  String _subtitle() {
    final parts = <String>[_severityLabel(alarm.severity)];
    if (alarm.cleared) {
      parts.add('Đã xóa');
    } else if (alarm.acknowledged) {
      parts.add('Đã xác nhận');
    } else {
      parts.add('Chưa xác nhận');
    }
    return parts.join(' · ');
  }

  Color _severityColor(AlarmSeverity s) => switch (s) {
        AlarmSeverity.CRITICAL => MpColors.red,
        AlarmSeverity.MAJOR => MpColors.red,
        AlarmSeverity.MINOR => MpColors.amber,
        AlarmSeverity.WARNING => MpColors.amber,
        AlarmSeverity.INDETERMINATE => MpColors.text3,
      };

  String _severityLabel(AlarmSeverity s) => switch (s) {
        AlarmSeverity.CRITICAL => 'Nghiêm trọng',
        AlarmSeverity.MAJOR => 'Cao',
        AlarmSeverity.MINOR => 'Trung bình',
        AlarmSeverity.WARNING => 'Cảnh báo',
        AlarmSeverity.INDETERMINATE => 'Không xác định',
      };
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip(
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
