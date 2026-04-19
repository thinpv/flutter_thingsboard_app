import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_stats_provider.dart';
import 'package:thingsboard_app/modules/smarthome/smart/presentation/automation_edit_page.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/add_device_page.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/claim_device_page.dart';

/// mPipe-style home header:
///   "Chào buổi sáng"  (greeting, muted)
///   "Nhà của Minh ▾"  (home name + dropdown caret)
///   [avatar circle]   (right side)
///   Stats bar: Nhiệt độ · Độ ẩm · Điện
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homes = ref.watch(homesProvider);
    final selectedHome = ref.watch(selectedHomeProvider);

    return Container(
      color: MpColors.bg,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: greeting + home name ───────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: MpColors.text3,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    homes.when(
                      loading: () => const Text(
                        'SmartHome',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                          color: MpColors.text,
                        ),
                      ),
                      error: (_, _) => const Text('SmartHome',
                          style:
                              TextStyle(fontSize: 22, color: MpColors.text)),
                      data: (list) {
                        final current = selectedHome.valueOrNull;
                        final name = current?.name ?? 'SmartHome';
                        final hasMany = list.length > 1;

                        return GestureDetector(
                          onTap: hasMany
                              ? () => _showHomePicker(
                                  context, ref, list, current?.id ?? '')
                              : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.3,
                                    color: MpColors.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasMany) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: MpColors.text3,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ── Right: add button + avatar ────────────────────────────
              Row(
                children: [
                  _AddButton(onTap: () => _showAddMenu(context, ref)),
                  const SizedBox(width: 10),
                  _AvatarCircle(
                    name: (selectedHome.valueOrNull?.name ?? 'S').toString(),
                  ),
                ],
              ),
            ],
          ),

          // ── Stats bar ─────────────────────────────────────────────────
          const SizedBox(height: 12),
          const _StatsBar(),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Chào buổi sáng';
    if (h < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  void _showHomePicker(
    BuildContext context,
    WidgetRef ref,
    List<SmarthomeHome> homes,
    String currentId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MpBottomSheet(
        title: 'Chọn nhà',
        children: homes
            .map(
              (h) => _MpListTile(
                title: h.name,
                trailing: h.id == currentId
                    ? const Icon(Icons.check, color: MpColors.green, size: 18)
                    : null,
                onTap: () {
                  ref.read(selectedHomeIdProvider.notifier).state = h.id;
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  void _showAddMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MpBottomSheet(
        title: 'Thêm mới',
        children: [
          _MpListTile(
            icon: Icons.devices_other_outlined,
            iconTint: MpColors.blueSoft,
            iconColor: MpColors.blue,
            title: 'Thêm thiết bị',
            subtitle: 'Ghép nối thiết bị mới',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddDevicePage()),
              ).then((_) {
                final home = ref.read(selectedHomeProvider).valueOrNull;
                if (home != null) {
                  ref.invalidate(devicesInHomeProvider(home.id));
                  for (final r
                      in ref.read(roomsProvider).valueOrNull ?? <SmarthomeRoom>[]) {
                    ref.invalidate(devicesInRoomProvider(r.id));
                  }
                }
              });
            },
          ),
          _MpListTile(
            icon: Icons.qr_code_scanner,
            iconTint: MpColors.greenSoft,
            iconColor: MpColors.green,
            title: 'Quét mã thiết bị',
            subtitle: 'Thêm bằng mã QR',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClaimDevicePage()),
              );
            },
          ),
          _MpListTile(
            icon: Icons.auto_awesome_outlined,
            iconTint: MpColors.amberSoft,
            iconColor: MpColors.amber,
            title: 'Tạo kịch bản',
            subtitle: 'Thêm scene mới',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const AutomationEditPage(isTapToRun: true)),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Stats bar ────────────────────────────────────────────────────────────────

class _StatsBar extends ConsumerWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeStatsProvider);

    final tempStr = stats.temp != null
        ? '${stats.temp!.toStringAsFixed(1)}°C'
        : '—';
    final humStr = stats.hum != null
        ? '${stats.hum!.toStringAsFixed(0)}%'
        : '—';
    final powerStr = stats.totalPowerKw != null
        ? '${stats.totalPowerKw!.toStringAsFixed(1)}kW'
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatCell(
                label: 'Nhiệt độ',
                value: tempStr,
                icon: stats.fromWeather && stats.temp != null
                    ? Icons.cloud_outlined
                    : Icons.thermostat_outlined,
              ),
            ),
            _Divider(),
            Expanded(
              child: _StatCell(
                label: 'Độ ẩm',
                value: humStr,
                icon: stats.fromWeather && stats.hum != null
                    ? Icons.cloud_outlined
                    : Icons.water_drop_outlined,
              ),
            ),
            _Divider(),
            Expanded(
              child: _StatCell(
                label: 'Điện',
                value: powerStr,
                icon: Icons.bolt_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: MpColors.text3),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: MpColors.text3,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MpColors.text,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      color: MpColors.border,
    );
  }
}

// ─── Avatar circle ────────────────────────────────────────────────────────────

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'S';
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: MpColors.violetSoft,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: MpColors.violet,
        ),
      ),
    );
  }
}

// ─── Add button ───────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MpColors.surface,
          border: Border.all(color: MpColors.border),
        ),
        child: const Icon(Icons.add, size: 18, color: MpColors.text2),
      ),
    );
  }
}

// ─── Reusable bottom sheet ────────────────────────────────────────────────────

class _MpBottomSheet extends StatelessWidget {
  const _MpBottomSheet({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MpColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: MpColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: MpColors.text,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _MpListTile extends StatelessWidget {
  const _MpListTile({
    this.icon,
    this.iconTint,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });
  final IconData? icon;
  final Color? iconTint;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconTint ?? MpColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: iconColor ?? MpColors.text2),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MpColors.text,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MpColors.text3,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
