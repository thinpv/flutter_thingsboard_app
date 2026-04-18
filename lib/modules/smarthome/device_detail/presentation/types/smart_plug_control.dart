import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';
import 'package:thingsboard_app/modules/smarthome/smart/domain/entities/automation_rule.dart';
import 'package:thingsboard_app/modules/smarthome/smart/presentation/automation_edit_page.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';

/// Smart plug detail — Tuya-inspired layout.
///
/// Keys: onoff0 | onoff | rl (on/off), power (W), energy (kWh), volt (V),
/// curr (A).
class SmartPlugControl extends StatefulWidget {
  const SmartPlugControl({
    required this.deviceId,
    required this.deviceName,
    required this.telemetry,
    required this.onRpc,
    super.key,
  });
  final String deviceId;
  final String deviceName;
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  @override
  State<SmartPlugControl> createState() => _SmartPlugControlState();
}

class _SmartPlugControlState extends State<SmartPlugControl> {
  final _control = DeviceControlService();

  /// Hourly average power for the last 24h (oldest-first), null while loading.
  List<(DateTime, double)>? _hourlyPower;
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(hours: 24));
    final data = await _control.fetchTimeseries(
      widget.deviceId,
      ['power'],
      startTs: start.millisecondsSinceEpoch,
      endTs: now.millisecondsSinceEpoch,
      interval: const Duration(hours: 1).inMilliseconds,
      agg: Aggregation.AVG,
      limit: 24,
    );
    final power = data['power'] ?? [];
    if (!mounted) return;
    setState(() {
      _hourlyPower = power
          .map((e) => (DateTime.fromMillisecondsSinceEpoch(e.$1),
              e.$2.toDouble()))
          .toList();
      _loadingHistory = false;
    });
  }

  bool get _isOn => isOn(widget.telemetry['onoff0'] ??
      widget.telemetry['onoff'] ??
      widget.telemetry['rl0'] ??
      widget.telemetry['rl']);

  double get _power => doubleVal(widget.telemetry['power']) ?? 0;
  double? get _volt => doubleVal(widget.telemetry['volt']);
  double? get _curr => doubleVal(widget.telemetry['curr']);
  double? get _energyNow => doubleVal(widget.telemetry['energy']);

  /// Average power over the last 24h window.
  double? get _avgPower24h {
    final p = _hourlyPower;
    if (p == null || p.isEmpty) return null;
    return p.map((e) => e.$2).reduce((a, b) => a + b) / p.length;
  }

  /// Peak power seen over the last 24h window.
  double? get _peakPower24h {
    final p = _hourlyPower;
    if (p == null || p.isEmpty) return null;
    return p.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
  }

  /// Rough energy estimate for the 24h window: trapezoidal integration of
  /// hourly average power samples. Gateway doesn't publish a cumulative
  /// `energy` key on Aqara plugs so we compute it client-side.
  double? get _energy24h {
    final p = _hourlyPower;
    if (p == null || p.isEmpty) return null;
    // Each sample is an hourly average → sum × 1h / 1000 → kWh.
    final sumW = p.map((e) => e.$2).reduce((a, b) => a + b);
    return sumW / 1000;
  }

  void _openAutomationWithDeviceAction() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AutomationEditPage(
          prefillName: 'Tự động • ${widget.deviceName}',
          prefillActions: [
            RuleAction(raw: {
              'type': 'device',
              'deviceId': widget.deviceId,
              'data': {'onoff0': _isOn ? 0 : 1},
            }),
          ],
        ),
      ),
    );
  }

  void _openScheduleAutomation() {
    final now = TimeOfDay.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AutomationEditPage(
          prefillName: 'Hẹn giờ • ${widget.deviceName}',
          prefillConditions: [
            RuleCondition(raw: {
              'type': 'timer',
              'days': 127,
              'time': time,
            }),
          ],
          prefillActions: [
            RuleAction(raw: {
              'type': 'device',
              'deviceId': widget.deviceId,
              'data': {'onoff0': 1},
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
          isOn: _isOn,
          power: _power,
          onToggle: () => widget.onRpc('setValue', {'onoff0': _isOn ? 0 : 1}),
        ),
        const SizedBox(height: 20),
        _MetricsStrip(
          power: _power,
          volt: _volt,
          curr: _curr,
          energyNow: _energyNow,
        ),
        const SizedBox(height: 24),
        _Power24hStatsCard(
          avg: _avgPower24h,
          peak: _peakPower24h,
          energy: _energy24h,
          loading: _loadingHistory,
        ),
        const SizedBox(height: 16),
        _Power24hChart(
          data: _hourlyPower,
          loading: _loadingHistory,
        ),
        const SizedBox(height: 24),
        _QuickActionsGrid(
          onScheduleTap: _openScheduleAutomation,
          onAutomationTap: _openAutomationWithDeviceAction,
        ),
      ],
    );
  }
}

// ─── Hero card ─────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.isOn,
    required this.power,
    required this.onToggle,
  });
  final bool isOn;
  final double power;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isOn ? MpColors.amberSoft : MpColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.power,
                    color: isOn ? MpColors.amber : MpColors.text3, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                isOn ? 'Đang bật' : 'Đã tắt',
                style: TextStyle(
                  color: isOn ? MpColors.text : MpColors.text3,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOn ? MpColors.text : MpColors.surfaceAlt,
                border: Border.all(
                    color: isOn ? MpColors.text : MpColors.border, width: 2),
              ),
              child: Icon(
                Icons.power_settings_new,
                size: 48,
                color: isOn ? MpColors.bg : MpColors.text3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${power.toStringAsFixed(1)} W',
            style: const TextStyle(
              color: MpColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Text(
            'Công suất hiện tại',
            style: TextStyle(color: MpColors.text3, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Metrics strip (4 mini-cards: W / V / A / kWh total) ──────────────────

class _MetricsStrip extends StatelessWidget {
  const _MetricsStrip({
    required this.power,
    required this.volt,
    required this.curr,
    required this.energyNow,
  });
  final double power;
  final double? volt, curr, energyNow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _miniCard(Icons.bolt, 'W', power.toStringAsFixed(1), MpColors.amber),
        const SizedBox(width: 8),
        _miniCard(Icons.electrical_services, 'V',
            volt == null ? '—' : volt!.toStringAsFixed(0), MpColors.blue),
        const SizedBox(width: 8),
        _miniCard(Icons.speed, 'A',
            curr == null ? '—' : curr!.toStringAsFixed(2), MpColors.violet),
        const SizedBox(width: 8),
        _miniCard(
            Icons.electric_meter,
            'kWh',
            energyNow == null ? '—' : energyNow!.toStringAsFixed(1),
            MpColors.green),
      ],
    );
  }

  Widget _miniCard(IconData icon, String unit, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: MpColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MpColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 5),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  color: MpColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: const TextStyle(
                color: MpColors.text3,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 24h power stats card ────────────────────────────────────────────────

class _Power24hStatsCard extends StatelessWidget {
  const _Power24hStatsCard({
    required this.avg,
    required this.peak,
    required this.energy,
    required this.loading,
  });
  final double? avg, peak, energy;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, size: 16, color: MpColors.text3),
              SizedBox(width: 6),
              Text('Thống kê 24h',
                  style: TextStyle(
                      color: MpColors.text2,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 14),
          if (loading)
            const SizedBox(
              height: 44,
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            Row(
              children: [
                _stat('TB', avg, 'W'),
                _divider(),
                _stat('Đỉnh', peak, 'W'),
                _divider(),
                _stat('Ước tính', energy, 'kWh'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, double? value, String unit) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style:
                  const TextStyle(color: MpColors.text3, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value == null
                    ? '—'
                    : value.toStringAsFixed(unit == 'kWh' ? 2 : 1),
                style: const TextStyle(
                  color: MpColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(unit,
                    style: const TextStyle(
                        color: MpColors.text3, fontSize: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: MpColors.border,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}

// ─── 24h power bar chart ──────────────────────────────────────────────────

class _Power24hChart extends StatelessWidget {
  const _Power24hChart({required this.data, required this.loading});
  final List<(DateTime, double)>? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, size: 16, color: MpColors.text3),
              SizedBox(width: 6),
              Text('Công suất 24h',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MpColors.text2,
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: loading
                ? const Center(
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final d = data;
    if (d == null || d.isEmpty) {
      return Center(
        child: const Text('Chưa có dữ liệu',
            style: TextStyle(color: MpColors.text3, fontSize: 12)),
      );
    }

    final maxVal = d.map((e) => e.$2).fold<double>(0, (a, b) => b > a ? b : a);
    // Label every 6th bar to avoid crowding.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(d.length, (i) {
        final bar = d[i];
        final frac = maxVal == 0 ? 0.0 : bar.$2 / maxVal;
        final showLabel = i == 0 || i == d.length - 1 || i % 6 == 0;
        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: FractionallySizedBox(
                  heightFactor: frac.clamp(0.02, 1.0),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: MpColors.text,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                showLabel
                    ? '${bar.$1.hour.toString().padLeft(2, '0')}h'
                    : '',
                style: const TextStyle(fontSize: 9, color: MpColors.text3),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Quick actions ─────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onScheduleTap,
    required this.onAutomationTap,
  });
  final VoidCallback onScheduleTap;
  final VoidCallback onAutomationTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.flash_on, size: 16, color: MpColors.text3),
            SizedBox(width: 6),
            Text('Thao tác nhanh',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MpColors.text2,
                    letterSpacing: 0.3)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _action(context, Icons.schedule, 'Hẹn giờ', MpColors.blue,
                onScheduleTap),
            const SizedBox(width: 10),
            _action(context, Icons.auto_awesome, 'Automation',
                MpColors.violet, onAutomationTap),
          ],
        ),
      ],
    );
  }

  Widget _action(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: MpColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MpColors.border, width: 0.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      color: MpColors.text2,
                      fontWeight: FontWeight.w500,
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
