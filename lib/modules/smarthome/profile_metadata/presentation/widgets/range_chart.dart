import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/section_card.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';

/// Tile vẽ chart timeseries cho [StateDef.chartable] == true.
///
/// Tự động fetch lịch sử 24h gần nhất bằng [DeviceControlService.fetchTimeseries].
/// Render bằng [CustomPainter] — không phụ thuộc package chart bên ngoài.
class RangeChart extends ConsumerStatefulWidget {
  const RangeChart({
    required this.deviceId,
    required this.stateKey,
    required this.def,
    super.key,
  });

  final String deviceId;
  final String stateKey;
  final StateDef def;

  @override
  ConsumerState<RangeChart> createState() => _RangeChartState();
}

class _RangeChartState extends ConsumerState<RangeChart> {
  List<(int, num)>? _points;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final start = now - const Duration(hours: 24).inMilliseconds;
    try {
      final svc = DeviceControlService();
      final data = await svc.fetchTimeseries(
        widget.deviceId,
        [widget.stateKey],
        startTs: start,
        endTs: now,
        limit: 200,
      );
      if (mounted) {
        setState(() {
          _points = data[widget.stateKey] ?? [];
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
    final label = widget.def.labelDefault ?? widget.stateKey;
    final unit = widget.def.unit ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              if (!_loading && _points != null && _points!.isNotEmpty)
                Text(
                  '${_points!.last.$2.toStringAsFixed(widget.def.precision ?? 1)} $unit',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                    _points = null;
                  });
                  _fetchData();
                },
                child: const Icon(Icons.refresh, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: _buildChart(context),
          ),
          const SizedBox(height: 4),
          Text(
            '24 giờ qua',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    if (_loading) {
      return const Center(child: SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ));
    }
    if (_error != null) {
      return ErrorTile(_error!);
    }
    final pts = _points ?? [];
    if (pts.isEmpty) {
      return Center(
        child: Text(
          'Chưa có dữ liệu',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      );
    }
    return CustomPaint(
      painter: _LineChartPainter(
        points: pts,
        color: Theme.of(context).colorScheme.primary,
        range: widget.def.range,
      ),
      child: const SizedBox.expand(),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.color,
    this.range,
  });

  final List<(int, num)> points;
  final Color color;
  final StateRange? range;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final minX = points.first.$1.toDouble();
    final maxX = points.last.$1.toDouble();
    final xRange = (maxX - minX).clamp(1.0, double.infinity);

    double minY, maxY;
    if (range != null) {
      minY = range!.min;
      maxY = range!.max;
    } else {
      minY = points.map((p) => p.$2.toDouble()).reduce(math.min);
      maxY = points.map((p) => p.$2.toDouble()).reduce(math.max);
      if (minY == maxY) {
        minY -= 1;
        maxY += 1;
      }
    }
    final yRange = (maxY - minY).clamp(0.01, double.infinity);

    Offset toOffset((int, num) p) {
      final x = (p.$1 - minX) / xRange * size.width;
      final y = (1 - (p.$2.toDouble() - minY) / yRange) * size.height;
      return Offset(x, y);
    }

    // Fill area under line
    final fillPath = Path()..moveTo(0, size.height);
    for (final p in points) {
      final o = toOffset(p);
      fillPath.lineTo(o.dx, o.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );

    // Draw line
    final path = Path();
    bool first = true;
    for (final p in points) {
      final o = toOffset(p);
      if (first) {
        path.moveTo(o.dx, o.dy);
        first = false;
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Last point dot
    final last = toOffset(points.last);
    canvas.drawCircle(last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.points != points || old.color != color;
}
