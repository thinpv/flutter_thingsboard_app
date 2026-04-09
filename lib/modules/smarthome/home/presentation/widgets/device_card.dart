import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/device_detail_page.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

// ─── Device card ──────────────────────────────────────────────────────────────

/// A card displaying a device's status. Receives the device object directly so
/// live updates come from the parent grid (which watches the appropriate provider).
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    required this.device,
    this.roomName,
    this.onAssignToRoom,
    super.key,
  });

  final SmarthomeDevice device;

  /// Optional room label shown below the device name (Tuya style).
  final String? roomName;

  /// If set, shows a long-press "Gán vào phòng" action.
  final VoidCallback? onAssignToRoom;

  @override
  Widget build(BuildContext context) {
    final isOn = device.telemetry['onoff0'] == 1;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: isOn ? colorScheme.primaryContainer : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DeviceDetailPage(device: device),
          ),
        ),
        onLongPress: onAssignToRoom == null
            ? null
            : () => showModalBottomSheet(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.meeting_room_outlined),
                          title: const Text('Gán vào phòng'),
                          onTap: () {
                            Navigator.pop(context);
                            onAssignToRoom!();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _iconFor(device.type),
                    size: 28,
                    color: isOn ? colorScheme.primary : Colors.grey.shade400,
                  ),
                  const Spacer(),
                  // ON/OFF toggle dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: device.isOnline ? Colors.green : Colors.grey.shade400,
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
              if (roomName != null || device.label != null) ...[
                const SizedBox(height: 2),
                Text(
                  [if (roomName != null) roomName!, if (device.label != null) device.label!].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
      'switch' => Icons.toggle_on_outlined,
      _ => Icons.devices_other,
    };
  }
}

// ─── Device grids ─────────────────────────────────────────────────────────────

/// Grid of devices belonging to a room. Watches [devicesInRoomProvider] for
/// live telemetry updates and passes each [SmarthomeDevice] to [DeviceCard].
class RoomDeviceGrid extends ConsumerWidget {
  const RoomDeviceGrid({
    required this.roomId,
    required this.roomName,
    required this.deviceIds,
    super.key,
  });

  final String roomId;
  final String roomName;
  final List<String> deviceIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesInRoomProvider(roomId));
    final list = devices.valueOrNull ?? [];

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final dev = list.firstWhere(
            (d) => d.id == deviceIds[i],
            orElse: () => SmarthomeDevice(id: deviceIds[i], name: '…', type: ''),
          );
          return DeviceCard(device: dev, roomName: roomName);
        },
        childCount: deviceIds.length,
      ),
      gridDelegate: _gridDelegate,
    );
  }
}

/// Grid of devices directly under a home asset (gateways + unassigned).
/// Watches [devicesInHomeProvider] for live updates.
/// Long-pressing a card offers "Gán vào phòng" to move it into a room.
class HomeDeviceGrid extends ConsumerWidget {
  const HomeDeviceGrid({required this.homeId, super.key});

  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesInHomeProvider(homeId));
    final rooms = ref.watch(roomsProvider).valueOrNull ?? [];

    return devices.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (list) {
        if (list.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, i) => DeviceCard(
              device: list[i],
              onAssignToRoom: rooms.isEmpty
                  ? null
                  : () => _showRoomPicker(context, ref, list[i], rooms),
            ),
            childCount: list.length,
          ),
          gridDelegate: _gridDelegate,
        );
      },
    );
  }

  Future<void> _showRoomPicker(
    BuildContext context,
    WidgetRef ref,
    SmarthomeDevice device,
    List<SmarthomeRoom> rooms,
  ) async {
    final room = await showDialog<SmarthomeRoom>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Gán "${device.name}" vào phòng'),
        children: rooms
            .map(
              (r) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, r),
                child: Text(r.name),
              ),
            )
            .toList(),
      ),
    );
    if (room == null) return;

    try {
      await HomeService().assignDeviceToRoom(device.id, room.id, homeId);
      // Invalidate both providers so the UI refreshes
      ref.invalidate(devicesInHomeProvider(homeId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gán "${device.name}" vào "${room.name}"')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }
}

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  childAspectRatio: 1.2,
);

// ─── Legacy DeviceGrid kept for any remaining callers ─────────────────────────

/// @deprecated Use [RoomDeviceGrid] or [HomeDeviceGrid].
class DeviceGrid extends ConsumerWidget {
  const DeviceGrid({required this.roomId, required this.deviceIds, super.key});

  final String roomId;
  final List<String> deviceIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesInRoomProvider(roomId));
    final list = devices.valueOrNull ?? [];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: deviceIds.length,
      itemBuilder: (context, i) {
        final dev = list.firstWhere(
          (d) => d.id == deviceIds[i],
          orElse: () => SmarthomeDevice(id: deviceIds[i], name: '…', type: ''),
        );
        return DeviceCard(device: dev);
      },
    );
  }
}
