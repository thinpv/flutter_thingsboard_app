import 'package:flutter/material.dart';

import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';

/// Energy-metering wall switch — same gang detection as [SwitchControl] but
/// adds live power monitoring (W/V/A/kWh). Suits products that report relay
/// state plus electrical readings (e.g. Aqara T1, Lumi ctrl_ln1/2).
///
/// [meta] — profile metadata used to determine the authoritative channel count
/// even when some channels have no telemetry in ThingsBoard yet.
class ElectricalSwitchView extends StatelessWidget {
  const ElectricalSwitchView({
    required this.telemetry,
    required this.onRpc,
    this.meta,
    super.key,
  });
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;
  final ProfileMetadata? meta;

  @override
  Widget build(BuildContext context) {
    final gangs = detectSwitchGangs(telemetry, meta: meta);
    final anyOn = gangs.any((g) => isOn(telemetry[g.key]));
    final allOn = gangs.every((g) => isOn(telemetry[g.key]));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const SizedBox(height: 8),

        // ── Master toggle ──
        Center(
          child: PowerButton(
            isOn: anyOn,
            icon: Icons.power_settings_new,
            size: 88,
            onTap: () {
              final target = allOn ? 0 : 1;
              onRpc('setValue', {for (final g in gangs) g.key: target});
            },
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            allOn
                ? 'Tất cả bật'
                : anyOn
                    ? 'Một số đang bật'
                    : 'Tất cả tắt',
            style: TextStyle(
              fontSize: 14,
              color: anyOn ? MpColors.text : MpColors.text3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Wall plate ──
        WallPlateView(
          buttons: [
            for (final g in gangs)
              WallPlateButton(
                label: g.label,
                isOn: isOn(telemetry[g.key]),
                onTap: () => onRpc(
                    'setValue', {g.key: isOn(telemetry[g.key]) ? 0 : 1}),
              ),
          ],
        ),

        // ── Energy monitoring ──
        if (telemetry['power'] != null || telemetry['volt'] != null) ...[
          const SizedBox(height: 24),
          const Text(
            'Đo lường điện',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MpColors.text,
            ),
          ),
          const SizedBox(height: 10),
          if (telemetry['power'] != null) ...[
            _PowerBar(power: doubleVal(telemetry['power']) ?? 0),
            const SizedBox(height: 16),
          ],
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              if (telemetry['energy'] != null)
                InfoCard(
                  icon: Icons.electric_meter,
                  label: 'Điện năng',
                  value: '${telemetry['energy']} kWh',
                  iconColor: MpColors.green,
                  color: MpColors.greenSoft,
                ),
              if (telemetry['volt'] != null)
                InfoCard(
                  icon: Icons.electrical_services,
                  label: 'Điện áp',
                  value: '${telemetry['volt']} V',
                  iconColor: MpColors.blue,
                  color: MpColors.blue.withValues(alpha: 0.08),
                ),
              if (telemetry['curr'] != null)
                InfoCard(
                  icon: Icons.speed,
                  label: 'Dòng điện',
                  value: '${telemetry['curr']} A',
                  iconColor: MpColors.violet,
                  color: MpColors.violetSoft,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PowerBar extends StatelessWidget {
  const _PowerBar({required this.power});
  final double power;

  @override
  Widget build(BuildContext context) {
    final color = power > 2400
        ? MpColors.red
        : power > 1500
            ? MpColors.amber
            : MpColors.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt, size: 16, color: color),
            const SizedBox(width: 6),
            const Text(
              'Công suất',
              style: TextStyle(fontSize: 12, color: MpColors.text2),
            ),
            const Spacer(),
            Text(
              '${power.toStringAsFixed(1)} W',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (power / 3000).clamp(0.0, 1.0),
          backgroundColor: MpColors.surfaceAlt,
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
