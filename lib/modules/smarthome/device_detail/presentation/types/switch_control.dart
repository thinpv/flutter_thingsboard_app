import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';

/// Generic on/off wall switch — auto-adapts to 1/2/3/4-gang layouts using
/// [WallPlateView]. Detects gangs from any of the supported key conventions
/// the gateway might publish:
///   - Tuya TS0601:    bt, bt2, bt3, bt4
///   - BLE relay:      rl0..rlN, or single rl
///   - Zigbee on/off:  onoff0..onoffN
///
/// [meta] — profile metadata used to determine the authoritative channel count
/// even when some channels have no telemetry in ThingsBoard yet.
class SwitchControl extends StatelessWidget {
  const SwitchControl({
    required this.telemetry,
    required this.onRpc,
    this.meta,
    super.key,
  });
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;
  final ProfileMetadata? meta;

  List<({String key, String label})> get _gangs =>
      detectSwitchGangs(telemetry, meta: meta);

  bool _gangOn(String key) => isOn(telemetry[key]);

  @override
  Widget build(BuildContext context) {
    final gangs = _gangs;
    final allOn = gangs.every((g) => _gangOn(g.key));
    final anyOn = gangs.any((g) => _gangOn(g.key));

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
            allOn ? 'Tất cả bật' : anyOn ? 'Một số đang bật' : 'Tất cả tắt',
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
                isOn: _gangOn(g.key),
                onTap: () =>
                    onRpc('setValue', {g.key: _gangOn(g.key) ? 0 : 1}),
              ),
          ],
        ),

        // ── Power info ──
        if (telemetry['power'] != null || telemetry['energy'] != null) ...[
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              if (telemetry['power'] != null)
                InfoCard(
                  icon: Icons.bolt,
                  label: 'Công suất',
                  value: '${telemetry['power']} W',
                  iconColor: MpColors.amber,
                ),
              if (telemetry['energy'] != null)
                InfoCard(
                  icon: Icons.electric_meter,
                  label: 'Điện năng',
                  value: '${telemetry['energy']} kWh',
                  iconColor: MpColors.green,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
