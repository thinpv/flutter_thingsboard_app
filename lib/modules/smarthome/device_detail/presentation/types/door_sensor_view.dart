import 'package:flutter/material.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';
import 'package:thingsboard_app/modules/smarthome/smart/domain/entities/automation_rule.dart';
import 'package:thingsboard_app/modules/smarthome/smart/presentation/automation_edit_page.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';

/// Door / window sensor — Tuya-inspired layout.
///
/// Keys: door (1=closed, 0=open), bat/pin.
class DoorSensorView extends StatefulWidget {
  const DoorSensorView({
    required this.deviceId,
    required this.deviceName,
    required this.telemetry,
    super.key,
  });
  final String deviceId;
  final String deviceName;
  final Map<String, dynamic> telemetry;

  @override
  State<DoorSensorView> createState() => _DoorSensorViewState();
}

class _DoorSensorViewState extends State<DoorSensorView> {
  final _control = DeviceControlService();

  /// Raw `door` events over the past 24h (ts, value).
  List<(DateTime, int)>? _history24h;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 24));
      final data = await _control.fetchTimeseries(
        widget.deviceId,
        ['door'],
        startTs: start.millisecondsSinceEpoch,
        endTs: now.millisecondsSinceEpoch,
        limit: 200,
      );
      final events = data['door'] ?? [];
      if (!mounted) return;
      setState(() {
        _history24h = events
            .map((e) =>
                (DateTime.fromMillisecondsSinceEpoch(e.$1), e.$2.toInt()))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool get _isClosed => isOn(widget.telemetry['door']);

  /// Count of open events (door transitioned to 0) in last 24h.
  int get _openCountToday {
    final h = _history24h;
    if (h == null || h.isEmpty) return 0;
    var count = 0;
    int? prev;
    for (final e in h) {
      if (prev == 1 && e.$2 == 0) count++;
      prev = e.$2;
    }
    return count;
  }

  /// Timestamp of the most recent "opened" event.
  DateTime? get _lastOpened {
    final h = _history24h;
    if (h == null) return null;
    DateTime? last;
    for (final e in h) {
      if (e.$2 == 0) last = e.$1;
    }
    return last;
  }

  /// Total minutes the door was open in the last 24h.
  int get _openMinutesToday {
    final h = _history24h;
    if (h == null || h.isEmpty) return 0;
    var totalMs = 0;
    DateTime? openSince;
    for (final e in h) {
      if (e.$2 == 0 && openSince == null) {
        openSince = e.$1;
      } else if (e.$2 == 1 && openSince != null) {
        totalMs += e.$1.difference(openSince).inMilliseconds;
        openSince = null;
      }
    }
    // Still open at "now".
    if (openSince != null) {
      totalMs += DateTime.now().difference(openSince).inMilliseconds;
    }
    return (totalMs / 60000).round();
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  void _openAutomationOnOpen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AutomationEditPage(
          prefillName: 'Khi mở • ${widget.deviceName}',
          prefillConditions: [
            RuleCondition(raw: {
              'type': 'device',
              'deviceId': widget.deviceId,
              'key': 'door',
              'op': '==',
              'value': 0,
            }),
          ],
        ),
      ),
    );
  }

  void _openAutomationNotify() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AutomationEditPage(
          prefillName: 'Cảnh báo mở • ${widget.deviceName}',
          prefillConditions: [
            RuleCondition(raw: {
              'type': 'device',
              'deviceId': widget.deviceId,
              'key': 'door',
              'op': '==',
              'value': 0,
            }),
          ],
          prefillActions: [
            RuleAction(raw: {
              'type': 'notify',
              'message': '${widget.deviceName} vừa mở',
              'target': 'all',
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _HeroCard(
          isClosed: _isClosed,
          lastUpdated: _lastOpened,
        ),
        const SizedBox(height: 20),
        _StatsRow(
          openCount: _openCountToday,
          openMinutes: _openMinutesToday,
          lastOpened: _lastOpened,
          loading: _loading,
        ),
        const SizedBox(height: 16),
        if (batLevel(widget.telemetry) != null) ...[
          BatteryIndicator(level: batLevel(widget.telemetry)!.toDouble()),
          const SizedBox(height: 16),
        ],
        _HistoryCard(
          events: _history24h,
          loading: _loading,
          timeFmt: _fmtTime,
          ageFmt: _timeAgo,
        ),
        const SizedBox(height: 24),
        _QuickActionsGrid(
          onAutomationTap: _openAutomationOnOpen,
          onNotifyTap: _openAutomationNotify,
        ),
      ],
    );
  }
}

// ─── Hero card ─────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.isClosed, required this.lastUpdated});
  final bool isClosed;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final gradColors = isClosed
        ? [Colors.green.shade400, Colors.teal.shade500]
        : [Colors.orange.shade400, Colors.deepOrange.shade500];
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradColors.first.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.25),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Icon(
              isClosed ? Icons.sensor_door : Icons.sensor_door_outlined,
              size: 68,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isClosed ? 'Cửa đóng' : 'Cửa mở',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isClosed ? 'Không phát hiện xâm nhập' : 'Chú ý: cửa đang mở',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Stats row (3 cards: open count / duration / last opened) ────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.openCount,
    required this.openMinutes,
    required this.lastOpened,
    required this.loading,
  });
  final int openCount;
  final int openMinutes;
  final DateTime? lastOpened;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    String lastStr;
    if (loading) {
      lastStr = '…';
    } else if (lastOpened == null) {
      lastStr = '—';
    } else {
      final two = (int n) => n.toString().padLeft(2, '0');
      lastStr = '${two(lastOpened!.hour)}:${two(lastOpened!.minute)}';
    }

    return Row(
      children: [
        _card(context, Icons.swap_vert, '$openCount', 'lần mở', Colors.blue),
        const SizedBox(width: 10),
        _card(context, Icons.timelapse, '${openMinutes}p', 'tổng thời gian',
            Colors.orange),
        const SizedBox(width: 10),
        _card(context, Icons.history, lastStr, 'lần cuối', Colors.purple),
      ],
    );
  }

  Widget _card(BuildContext context, IconData icon, String value, String label,
      Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── History list ─────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.events,
    required this.loading,
    required this.timeFmt,
    required this.ageFmt,
  });
  final List<(DateTime, int)>? events;
  final bool loading;
  final String Function(DateTime) timeFmt;
  final String Function(DateTime) ageFmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text('Lịch sử 24h',
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const SizedBox(
              height: 48,
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (events == null || events!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Không có sự kiện trong 24 giờ qua',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            )
          else
            ..._buildEventList(),
        ],
      ),
    );
  }

  List<Widget> _buildEventList() {
    // Show newest first, max 10.
    final sorted = [...events!]
      ..sort((a, b) => b.$1.compareTo(a.$1));
    final top = sorted.take(10);
    return top.map((e) {
      final opened = e.$2 == 0;
      final color = opened ? Colors.orange : Colors.green;
      final icon = opened ? Icons.lock_open : Icons.lock;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opened ? 'Mở cửa' : 'Đóng cửa',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(ageFmt(e.$1),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Text(timeFmt(e.$1),
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }).toList();
  }
}

// ─── Quick actions ─────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onAutomationTap,
    required this.onNotifyTap,
  });
  final VoidCallback onAutomationTap;
  final VoidCallback onNotifyTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text('Thao tác nhanh',
                style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _action(context, Icons.auto_awesome, 'Tạo automation',
                Colors.deepPurple, onAutomationTap),
            const SizedBox(width: 12),
            _action(context, Icons.notifications_active, 'Cảnh báo khi mở',
                Colors.red, onNotifyTap),
          ],
        ),
      ],
    );
  }

  Widget _action(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 8),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
