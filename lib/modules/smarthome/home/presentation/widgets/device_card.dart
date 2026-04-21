import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/constants/app_constants.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/device_detail_page.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/card_composer.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/profile_metadata_providers.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

const _switchableUiTypes = {
  'light',
  'smartPlug',
  'switch',
  'electricalSwitch',
};

// ─── Device card (mPipe tile style) ──────────────────────────────────────────

class DeviceCard extends ConsumerWidget {
  const DeviceCard({
    required this.device,
    this.roomName,
    this.onAssignToRoom,
    super.key,
  });

  final SmarthomeDevice device;
  final String? roomName;
  final VoidCallback? onAssignToRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileId = device.deviceProfileId ?? '';
    final metaAsync = profileId.isNotEmpty
        ? ref.watch(deviceProfileMetadataProvider(profileId))
        : null;
    final meta = metaAsync?.valueOrNull;

    bool isOn;
    bool showToggle;
    IconData fallbackIcon;

    if (meta != null && CardComposer.canCompose(meta)) {
      isOn = CardComposer.resolveIsOn(device, meta);
      showToggle = CardComposer.hasPrimaryToggle(meta);
      fallbackIcon = CardComposer.resolveIcon(device, meta);
    } else {
      final t = device.telemetry;
      final raw = t['onoff0'] ?? t['bt'];
      isOn = raw == 1 || raw == '1' || raw == true;
      showToggle = _switchableUiTypes.contains(device.effectiveUiType);
      fallbackIcon = _iconFor(device.effectiveUiType);
    }

    final colors = MpColors.deviceColors(device.effectiveUiType, isOn);
    final accent = ref.watch(homeAccentColorProvider);
    // Dark card variant — only for "on" switchable devices (matches design)
    final dark = isOn && showToggle;

    final bgColor = dark ? MpColors.text : MpColors.surface;
    final textColor = dark ? MpColors.bg : MpColors.text;
    final subColor = dark
        ? const Color(0x8CFAFAF7) // ~55% white
        : MpColors.text3;
    // Accent color thay amber khi bật (nếu home có tông màu)
    final onColor = accent ?? MpColors.amber;
    final iconBgColor = dark
        ? onColor.withOpacity(0.18)
        : colors.tint;
    final iconFgColor = dark ? onColor : colors.fg;

    Future<void> toggle() async {
      try {
        await DeviceControlService()
            .sendOneWayRpc(device.id, 'setValue', {'onoff0': isOn ? 0 : 1});
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi điều khiển: $e')),
          );
        }
      }
    }

    return GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => DeviceDetailPage(device: device)),
      ),
      onLongPress: onAssignToRoom == null
          ? null
          : () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => _AssignSheet(onTap: onAssignToRoom!),
              ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: device.isOnline ? 1.0 : 0.5,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: dark
              ? null
              : Border.all(color: MpColors.border, width: 0.5),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon badge + toggle ────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconBadge(
                  profileImage: device.profileImage,
                  fallbackIcon: fallbackIcon,
                  tint: iconBgColor,
                  fg: iconFgColor,
                ),
                const Spacer(),
                if (showToggle)
                  _MiniSwitch(on: isOn, dark: dark, onTap: toggle)
                else
                  // Online dot for sensors
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: device.isOnline
                          ? MpColors.green
                          : MpColors.text3,
                    ),
                  ),
              ],
            ),

            const Spacer(),

            // ── Bottom: summary (trên) + name (dưới) ────────────────────
            if (meta != null && CardComposer.canCompose(meta))
              Builder(builder: (ctx) {
                final summary = CardComposer.buildSummaryRow(ctx, device, meta);
                if (summary == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(fontSize: 8, color: subColor),
                    child: summary,
                  ),
                );
              }),

            Text(
              device.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
                height: 1.25,
              ),
              maxLines: 2,
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
      'airConditioner' => Icons.ac_unit,
      'smartPlug' => Icons.electrical_services,
      'curtain' => Icons.blinds,
      'doorSensor' => Icons.sensor_door_outlined,
      'motionSensor' => Icons.motion_photos_on_outlined,
      'tempHumidity' => Icons.thermostat,
      'camera' => Icons.videocam_outlined,
      'gateway' => Icons.router_outlined,
      'switch' => Icons.toggle_on_outlined,
      'remote' || 'button' || 'sceneSwitch' => Icons.settings_remote_outlined,
      'lock' => Icons.lock_outline,
      'smokeSensor' => Icons.local_fire_department_outlined,
      'leakSensor' => Icons.water_drop_outlined,
      'airQuality' => Icons.air,
      'soilSensor' => Icons.grass,
      'electricalSwitch' => Icons.power_settings_new,
      _ => Icons.devices_other,
    };
  }
}

// ─── Icon badge (120×120, rounded 30) ────────────────────────────────────────

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.profileImage,
    required this.fallbackIcon,
    required this.tint,
    required this.fg,
  });
  final String? profileImage;
  final IconData fallbackIcon;
  final Color tint;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    Widget icon;
    if (profileImage != null && profileImage!.isNotEmpty) {
      final url =
          '${ThingsboardAppConstants.thingsBoardApiEndpoint}$profileImage';
      final token = getIt<ITbClientService>().client.getJwtToken();
      icon = CachedNetworkImage(
        imageUrl: url,
        width: 42,
        height: 42,
        fit: BoxFit.contain,
        httpHeaders: {
          if (token != null) 'X-Authorization': 'Bearer $token',
        },
        placeholder: (_, _) => const SizedBox(width: 42, height: 42),
        errorWidget: (_, _, _) => Icon(fallbackIcon, size: 32, color: fg),
      );
    } else {
      icon = Icon(fallbackIcon, size: 32, color: fg);
    }

    return icon;
  }
}

// ─── Mini switch (mPipe style) ────────────────────────────────────────────────

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({
    required this.on,
    required this.dark,
    required this.onTap,
  });
  final bool on;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trackOn = MpColors.green;
    final trackOff = dark
        ? const Color(0x40FFFFFF) // 25% white on dark bg
        : const Color(0x1F000000); // 12% black on light bg

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 32,
        height: 18,
        decoration: BoxDecoration(
          color: on ? trackOn : trackOff,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              top: 2,
              left: on ? 14 : 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: MpColors.bg,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Assign room sheet ────────────────────────────────────────────────────────

class _AssignSheet extends StatelessWidget {
  const _AssignSheet({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MpColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: MpColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.meeting_room_outlined,
                  color: MpColors.text2),
              title: const Text('Gán vào phòng',
                  style: TextStyle(color: MpColors.text)),
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Device grids ─────────────────────────────────────────────────────────────

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
            orElse: () =>
                SmarthomeDevice(id: deviceIds[i], name: '…', type: ''),
          );
          return DeviceCard(device: dev, roomName: roomName);
        },
        childCount: deviceIds.length,
      ),
      gridDelegate: _gridDelegate,
    );
  }
}

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
        if (list.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
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
        backgroundColor: MpColors.bg,
        title: Text(
          'Gán "${device.name}" vào phòng',
          style: const TextStyle(color: MpColors.text),
        ),
        children: rooms
            .map(
              (r) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, r),
                child: Text(r.name,
                    style: const TextStyle(color: MpColors.text2)),
              ),
            )
            .toList(),
      ),
    );
    if (room == null) return;

    try {
      await HomeService().assignDeviceToRoom(device.id, room.id, homeId);
      ref.invalidate(devicesInHomeProvider(homeId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Đã gán "${device.name}" vào "${room.name}"')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }
}

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 10,
  crossAxisSpacing: 10,
  childAspectRatio: 1.45,
);

// ─── Legacy DeviceGrid ────────────────────────────────────────────────────────

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
