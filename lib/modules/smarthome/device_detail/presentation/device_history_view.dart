import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';

// ─── Key classification ───────────────────────────────────────────────────────

/// Binary (on/off / event) telemetry keys — shown as state-interval timeline.
const _binaryKeys = {
  'onoff0', 'onoff1', 'onoff2',
  'pir', 'door', 'leak', 'smoke', 'gas', 'vibration', 'lock',
};

/// Continuous numeric keys — shown as mini chart + min/avg/max stats.
const _continuousKeys = {
  'temp', 'hum', 'co2', 'power', 'lux', 'dim', 'pos',
  'coolSp', 'heatSp', 'curr', 'volt', 'pressure', 'bat', 'pin',
};

/// Cumulative energy — shown separately as total consumed.
const _energyKey = 'energy';

// ─── Labels & units ──────────────────────────────────────────────────────────

const _keyLabels = <String, String>{
  'onoff0': 'Bật / Tắt', 'onoff1': 'Kênh 2', 'onoff2': 'Kênh 3',
  'dim': 'Độ sáng', 'temp': 'Nhiệt độ', 'hum': 'Độ ẩm',
  'pir': 'Cảm biến chuyển động', 'lux': 'Ánh sáng',
  'door': 'Cửa', 'leak': 'Rò nước', 'smoke': 'Khói', 'gas': 'Gas',
  'co2': 'CO₂', 'pos': 'Vị trí rèm', 'lock': 'Khóa',
  'power': 'Công suất', 'energy': 'Điện năng tiêu thụ',
  'volt': 'Điện áp', 'curr': 'Dòng điện',
  'coolSp': 'Nhiệt độ đặt lạnh', 'heatSp': 'Nhiệt độ đặt sưởi',
  'pin': 'Pin', 'bat': 'Pin', 'vibration': 'Rung', 'pressure': 'Áp suất',
};

const _keyUnits = <String, String>{
  'dim': '%', 'temp': '°C', 'hum': '%', 'lux': ' lux',
  'co2': ' ppm', 'pos': '%', 'power': ' W', 'energy': ' kWh',
  'volt': ' V', 'curr': ' A', 'coolSp': '°C', 'heatSp': '°C',
  'pin': '%', 'bat': '%', 'pressure': ' hPa',
};

const _activeLabel = <String, String>{
  'onoff0': 'BẬT', 'onoff1': 'BẬT', 'onoff2': 'BẬT',
  'pir': 'Phát hiện chuyển động', 'door': 'Mở', 'leak': 'Phát hiện rò nước',
  'smoke': 'Phát hiện khói', 'gas': 'Phát hiện gas', 'vibration': 'Rung',
  'lock': 'Đã khóa',
};

const _inactiveLabel = <String, String>{
  'onoff0': 'TẮT', 'onoff1': 'TẮT', 'onoff2': 'TẮT',
  'pir': 'Không có chuyển động', 'door': 'Đóng', 'leak': 'Bình thường',
  'smoke': 'Bình thường', 'gas': 'Bình thường', 'vibration': 'Yên tĩnh',
  'lock': 'Mở khóa',
};

// ─── Period selector ─────────────────────────────────────────────────────────

enum _Period {
  day('1 Ngày', Duration(hours: 24)),
  week('7 Ngày', Duration(days: 7)),
  month('30 Ngày', Duration(days: 30));

  const _Period(this.label, this.duration);
  final String label;
  final Duration duration;
}

// ─── Data models ─────────────────────────────────────────────────────────────

class _Stats {
  const _Stats({required this.min, required this.max, required this.avg});
  final num min;
  final num max;
  final num avg;
}

/// One continuous on/off interval derived from a binary telemetry timeseries.
class _Interval {
  const _Interval({
    required this.startTs,
    required this.endTs,
    required this.isActive,
    required this.key,
  });
  final int startTs;
  final int endTs;
  final bool isActive;
  final String key;

  Duration get duration => Duration(milliseconds: endTs - startTs);
  DateTime get start => DateTime.fromMillisecondsSinceEpoch(startTs);
  DateTime get end => DateTime.fromMillisecondsSinceEpoch(endTs);
}

// ─── Processing helpers ───────────────────────────────────────────────────────

_Stats _computeStats(List<(int, num)> pts) {
  final values = pts.map((p) => p.$2.toDouble()).toList();
  final min = values.reduce(math.min);
  final max = values.reduce(math.max);
  final avg = values.reduce((a, b) => a + b) / values.length;
  return _Stats(min: min, max: max, avg: avg);
}

/// Converts a binary timeseries (sorted ASC) to state intervals.
List<_Interval> _toIntervals(
    String key, List<(int, num)> pts, int periodEndTs) {
  if (pts.isEmpty) return [];
  final result = <_Interval>[];
  int curStart = pts.first.$1;
  bool curActive = pts.first.$2 > 0.5;

  for (int i = 1; i < pts.length; i++) {
    final newActive = pts[i].$2 > 0.5;
    if (newActive != curActive) {
      result.add(_Interval(
          startTs: curStart, endTs: pts[i].$1,
          isActive: curActive, key: key));
      curStart = pts[i].$1;
      curActive = newActive;
    }
  }
  result.add(_Interval(
      startTs: curStart, endTs: periodEndTs,
      isActive: curActive, key: key));
  return result;
}

/// Total "active" time and number of activations from a list of intervals.
({Duration total, int count}) _activeStats(List<_Interval> intervals) {
  Duration total = Duration.zero;
  int count = 0;
  for (final iv in intervals) {
    if (iv.isActive) {
      total += iv.duration;
      count++;
    }
  }
  return (total: total, count: count);
}

String _fmtDuration(Duration d) {
  if (d.inHours >= 1) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m > 0 ? '$h giờ $m phút' : '$h giờ';
  }
  if (d.inMinutes >= 1) return '${d.inMinutes} phút';
  return '${d.inSeconds} giây';
}

String _fmtNum(num v, {int precision = 1}) {
  if (v == v.truncate()) return v.toInt().toString();
  return v.toStringAsFixed(precision);
}

String _dateHeader(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  if (day == today) return 'Hôm nay';
  if (day == today.subtract(const Duration(days: 1))) return 'Hôm qua';
  return DateFormat('EEEE, dd/MM', 'vi').format(dt);
}

// ─── Main widget ─────────────────────────────────────────────────────────────

/// Device activity history view — adapts layout to device capabilities.
///
/// • Binary keys (onoff, pir, door…)  → state-interval timeline with duration.
/// • Continuous keys (temp, hum, power…) → sparkline chart + min/avg/max stats.
/// • Energy key                        → total consumed in period.
class DeviceHistoryView extends StatefulWidget {
  const DeviceHistoryView({
    required this.deviceId,
    required this.telemetry,
    super.key,
  });

  final String deviceId;

  /// Latest live telemetry — used to determine which keys to fetch history for.
  final Map<String, dynamic> telemetry;

  @override
  State<DeviceHistoryView> createState() => _DeviceHistoryViewState();
}

class _DeviceHistoryViewState extends State<DeviceHistoryView>
    with AutomaticKeepAliveClientMixin {
  _Period _period = _Period.day;
  bool _loading = true;
  String? _error;
  Map<String, List<(int, num)>> _data = {};
  late int _endTs;

  @override
  bool get wantKeepAlive => true;

  List<String> get _binKeys => widget.telemetry.keys
      .where((k) => _binaryKeys.contains(k))
      .toList();

  List<String> get _contKeys => widget.telemetry.keys
      .where((k) => _continuousKeys.contains(k))
      .toList();

  bool get _hasEnergy => widget.telemetry.containsKey(_energyKey);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    _endTs = DateTime.now().millisecondsSinceEpoch;
    final startTs = _endTs - _period.duration.inMilliseconds;

    final keys = {
      ..._binKeys,
      ..._contKeys,
      if (_hasEnergy) _energyKey,
    }.toList();

    if (keys.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final data = await DeviceControlService().fetchTimeseries(
        widget.deviceId,
        keys,
        startTs: startTs,
        endTs: _endTs,
        limit: _period == _Period.day ? 200 : 500,
      );
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _PeriodBar(
          selected: _period,
          onSelect: (p) {
            setState(() => _period = p);
            _load();
          },
        ),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorPanel(error: _error!, onRetry: _load);
    }
    if (_data.isEmpty) {
      return _EmptyPanel(onRetry: _load);
    }

    final sections = <Widget>[];

    // ── Continuous sensor section ──────────────────────────────────────────
    for (final key in _contKeys) {
      final pts = _data[key];
      if (pts == null || pts.isEmpty) continue;
      sections.add(_SensorCard(
        keyName: key,
        label: _keyLabels[key] ?? key,
        unit: _keyUnits[key] ?? '',
        points: pts,
        stats: _computeStats(pts),
      ));
    }

    // ── Energy section ─────────────────────────────────────────────────────
    if (_hasEnergy) {
      final pts = _data[_energyKey];
      if (pts != null && pts.length >= 2) {
        final consumed = (pts.last.$2 - pts.first.$2).abs();
        sections.add(_EnergyCard(
          consumed: consumed,
          period: _period,
        ));
      }
    }

    // ── Binary / toggle section ────────────────────────────────────────────
    for (final key in _binKeys) {
      final pts = _data[key];
      if (pts == null || pts.isEmpty) continue;
      final intervals = _toIntervals(key, pts, _endTs);
      final stats = _activeStats(intervals);
      sections.add(_ToggleCard(
        keyName: key,
        label: _keyLabels[key] ?? key,
        intervals: intervals,
        stats: stats,
      ));
    }

    if (sections.isEmpty) {
      return _EmptyPanel(onRetry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: sections,
      ),
    );
  }
}

// ─── Period bar ───────────────────────────────────────────────────────────────

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.selected, required this.onSelect});
  final _Period selected;
  final void Function(_Period) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MpColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: _Period.values.map((p) {
          final isSelected = p == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? MpColors.text : MpColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  p.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? MpColors.bg : MpColors.text2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Sensor chart card ────────────────────────────────────────────────────────

class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.keyName,
    required this.label,
    required this.unit,
    required this.points,
    required this.stats,
  });
  final String keyName;
  final String label;
  final String unit;
  final List<(int, num)> points;
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final latest = points.last.$2;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(keyName), size: 18, color: MpColors.text2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MpColors.text)),
              ),
              Text(
                '${_fmtNum(latest)}$unit',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: MpColors.text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: CustomPaint(
              painter: _SparklinePainter(points: points, color: MpColors.text),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(
                  label: 'Thấp',
                  value: '${_fmtNum(stats.min)}$unit',
                  icon: Icons.arrow_downward_rounded,
                  color: MpColors.blue),
              const SizedBox(width: 8),
              _StatChip(
                  label: 'Trung bình',
                  value: '${_fmtNum(stats.avg)}$unit',
                  icon: Icons.remove_rounded,
                  color: MpColors.text2),
              const SizedBox(width: 8),
              _StatChip(
                  label: 'Cao',
                  value: '${_fmtNum(stats.max)}$unit',
                  icon: Icons.arrow_upward_rounded,
                  color: MpColors.amber),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String key) => switch (key) {
        'temp' => Icons.thermostat_outlined,
        'hum' => Icons.water_drop_outlined,
        'co2' => Icons.co2_outlined,
        'power' => Icons.bolt_outlined,
        'lux' => Icons.wb_sunny_outlined,
        'dim' => Icons.brightness_medium_outlined,
        'pos' => Icons.blinds_outlined,
        'coolSp' || 'heatSp' => Icons.thermostat_auto_outlined,
        'curr' => Icons.electrical_services_outlined,
        'volt' => Icons.electric_bolt_outlined,
        'pressure' => Icons.compress_outlined,
        'bat' || 'pin' => Icons.battery_full_outlined,
        _ => Icons.show_chart_rounded,
      };
}

// ─── Energy card ──────────────────────────────────────────────────────────────

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({required this.consumed, required this.period});
  final num consumed;
  final _Period period;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: MpColors.amberSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MpColors.border, width: 0.5),
            ),
            child: const Icon(Icons.electric_meter_outlined, color: MpColors.amber, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Điện năng tiêu thụ',
                    style: TextStyle(fontSize: 13, color: MpColors.text3)),
                const SizedBox(height: 2),
                Text(
                  '${_fmtNum(consumed, precision: 2)} kWh',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: MpColors.text),
                ),
              ],
            ),
          ),
          Text(
            'trong ${period.label.toLowerCase()}',
            style: const TextStyle(fontSize: 12, color: MpColors.text3),
          ),
        ],
      ),
    );
  }
}

// ─── Toggle / binary card ─────────────────────────────────────────────────────

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.keyName,
    required this.label,
    required this.intervals,
    required this.stats,
  });
  final String keyName;
  final String label;
  final List<_Interval> intervals;
  final ({Duration total, int count}) stats;

  @override
  Widget build(BuildContext context) {
    final sortedIntervals = intervals.reversed.toList();

    final groups = <String, List<_Interval>>{};
    for (final iv in sortedIntervals) {
      final dateKey = _dateHeader(iv.start);
      (groups[dateKey] ??= []).add(iv);
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(keyName), size: 18, color: MpColors.text2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MpColors.text)),
              ),
            ],
          ),
          if (stats.count > 0) ...[
            const SizedBox(height: 10),
            _SummaryBanner(
              activeLabel: _activeLabel[keyName] ?? 'Hoạt động',
              totalTime: stats.total,
              count: stats.count,
            ),
          ],
          const SizedBox(height: 12),
          // Timeline groups
          ...groups.entries.expand((entry) => [
                _DateLabel(label: entry.key),
                ...entry.value.map((iv) => _IntervalTile(
                      interval: iv,
                      activeLabel: _activeLabel[keyName] ?? 'Bật',
                      inactiveLabel: _inactiveLabel[keyName] ?? 'Tắt',
                    )),
              ]),
        ],
      ),
    );
  }

  static IconData _iconFor(String key) => switch (key) {
        'onoff0' || 'onoff1' || 'onoff2' => Icons.power_settings_new_rounded,
        'pir' => Icons.motion_photos_on_outlined,
        'door' => Icons.sensor_door_outlined,
        'leak' => Icons.water_drop_outlined,
        'smoke' => Icons.local_fire_department_outlined,
        'gas' => Icons.gas_meter_outlined,
        'vibration' => Icons.vibration_rounded,
        'lock' => Icons.lock_outline_rounded,
        _ => Icons.toggle_on_rounded,
      };
}

// ─── Summary banner (on-time stats) ──────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.activeLabel,
    required this.totalTime,
    required this.count,
  });
  final String activeLabel;
  final Duration totalTime;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MpColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: MpColors.text2),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Tổng thời gian: ${_fmtDuration(totalTime)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: MpColors.text),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: MpColors.bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: MpColors.border, width: 0.5),
            ),
            child: Text(
              '$count lần',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MpColors.text2),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Date group label ─────────────────────────────────────────────────────────

class _DateLabel extends StatelessWidget {
  const _DateLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: MpColors.text3,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Interval tile ────────────────────────────────────────────────────────────

class _IntervalTile extends StatelessWidget {
  const _IntervalTile({
    required this.interval,
    required this.activeLabel,
    required this.inactiveLabel,
  });
  final _Interval interval;
  final String activeLabel;
  final String inactiveLabel;

  @override
  Widget build(BuildContext context) {
    final isActive = interval.isActive;
    final stateLabel = isActive ? activeLabel : inactiveLabel;

    final startStr = DateFormat('HH:mm').format(interval.start);
    final isOngoing = DateTime.now().millisecondsSinceEpoch - interval.endTs < 10000;
    final endStr = isOngoing ? 'hiện tại' : DateFormat('HH:mm').format(interval.end);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: isActive ? MpColors.text : MpColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? MpColors.text : MpColors.text3,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              stateLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? MpColors.text : MpColors.text3,
              ),
            ),
          ),
          Text(
            '$startStr → $endStr',
            style: const TextStyle(fontSize: 12, color: MpColors.text3),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isActive ? MpColors.surfaceAlt : MpColors.surfaceAlt,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: MpColors.border, width: 0.5),
            ),
            child: Text(
              _fmtDuration(interval.duration),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isActive ? MpColors.text2 : MpColors.text3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: MpColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MpColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MpColors.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label,
                style: const TextStyle(fontSize: 10, color: MpColors.text3)),
          ],
        ),
      ),
    );
  }
}

// ─── Shared card container ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: child,
    );
  }
}

// ─── Sparkline chart painter ──────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.points, required this.color});

  final List<(int, num)> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minX = points.first.$1.toDouble();
    final maxX = points.last.$1.toDouble();
    final xRange = (maxX - minX).clamp(1.0, double.infinity);

    final allY = points.map((p) => p.$2.toDouble());
    double minY = allY.reduce(math.min);
    double maxY = allY.reduce(math.max);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final yRange = maxY - minY;

    Offset toOffset((int, num) p) {
      final x = (p.$1 - minX) / xRange * size.width;
      final y = (1.0 - (p.$2.toDouble() - minY) / yRange) * size.height;
      return Offset(x, y);
    }

    // Fill gradient
    final fillPath = Path()..moveTo(0, size.height);
    for (final p in points) {
      final o = toOffset(p);
      fillPath.lineTo(o.dx, o.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.18),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePath = Path();
    bool first = true;
    for (final p in points) {
      final o = toOffset(p);
      if (first) {
        linePath.moveTo(o.dx, o.dy);
        first = false;
      } else {
        linePath.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Last-point dot
    final last = toOffset(points.last);
    canvas.drawCircle(last, 4, Paint()..color = color);
    canvas.drawCircle(
        last, 4, Paint()..color = MpColors.bg..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Y-axis labels (min/max)
    _drawYLabel(canvas, size, _fmtNum(maxY), const Offset(4, 2));
    _drawYLabel(canvas, size, _fmtNum(minY), Offset(4, size.height - 14));
  }

  void _drawYLabel(Canvas canvas, Size size, String text, Offset pos) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9,
          color: color.withValues(alpha: 0.5),
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.color != color;
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_toggle_off_outlined, size: 60, color: MpColors.text3),
          const SizedBox(height: 12),
          const Text('Chưa có dữ liệu lịch sử',
              style: TextStyle(fontSize: 14, color: MpColors.text3)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: MpColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MpColors.border, width: 0.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 16, color: MpColors.text2),
                  SizedBox(width: 6),
                  Text('Tải lại', style: TextStyle(fontSize: 14, color: MpColors.text2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: MpColors.red),
            const SizedBox(height: 12),
            const Text('Không thể tải lịch sử',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: MpColors.text)),
            const SizedBox(height: 6),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: MpColors.text3),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: MpColors.text,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 16, color: MpColors.bg),
                    SizedBox(width: 6),
                    Text('Thử lại', style: TextStyle(fontSize: 14, color: MpColors.bg, fontWeight: FontWeight.w600)),
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
