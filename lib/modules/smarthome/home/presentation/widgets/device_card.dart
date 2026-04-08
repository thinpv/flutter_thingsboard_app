import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/device_detail_page.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';

/// Finds [SmarthomeDevice] with [deviceId] from any room's stream.
/// Caller is responsible for passing the correct roomId via context or
/// wrapping. For simplicity the card receives the device directly once found.
class DeviceCard extends ConsumerWidget {
  const DeviceCard({required this.deviceId, super.key});

  final String deviceId;

  // This widget is placed inside a _DeviceGrid which already has the roomId.
  // We receive deviceId only; the parent stream holds the full state.
  // DeviceCard looks up device state from the nearest room stream via
  // [_DeviceGridInheritedData] — see DeviceGrid widget below.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inherited = _DeviceGridData.of(context);
    if (inherited == null) return const SizedBox.shrink();

    final devices = ref.watch(devicesInRoomProvider(inherited.roomId));
    final device = devices.valueOrNull?.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => SmarthomeDevice(id: deviceId, name: '…', type: ''),
    );

    if (device == null) return const SizedBox.shrink();
    return _DeviceCardContent(device: device);
  }
}

class _DeviceCardContent extends StatelessWidget {
  const _DeviceCardContent({required this.device});

  final SmarthomeDevice device;

  @override
  Widget build(BuildContext context) {
    final isOn = device.telemetry['onoff0'] == 1;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: isOn ? colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DeviceDetailPage(device: device),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _iconFor(device.type),
                    color: isOn ? colorScheme.primary : Colors.grey,
                  ),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: device.isOnline ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                device.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (device.label != null)
                Text(
                  device.label!,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'light' => Icons.lightbulb_outline,
      'air_conditioner' => Icons.ac_unit,
      'smart_plug' => Icons.electrical_services,
      'curtain' => Icons.blinds,
      'door_sensor' => Icons.sensor_door_outlined,
      'motion_sensor' => Icons.motion_photos_on_outlined,
      'temp_humidity' => Icons.thermostat,
      'camera' => Icons.videocam_outlined,
      'gateway' => Icons.router_outlined,
      _ => Icons.devices_other,
    };
  }
}

// ─── Inherited widget to pass roomId down to DeviceCard ────────────────────

class DeviceGrid extends StatelessWidget {
  const DeviceGrid({required this.roomId, required this.deviceIds, super.key});

  final String roomId;
  final List<String> deviceIds;

  @override
  Widget build(BuildContext context) {
    return _DeviceGridData(
      roomId: roomId,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemCount: deviceIds.length,
        itemBuilder: (context, index) =>
            DeviceCard(deviceId: deviceIds[index]),
      ),
    );
  }
}

class _DeviceGridData extends InheritedWidget {
  const _DeviceGridData({required this.roomId, required super.child});

  final String roomId;

  static _DeviceGridData? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_DeviceGridData>();
  }

  @override
  bool updateShouldNotify(_DeviceGridData old) => roomId != old.roomId;
}
