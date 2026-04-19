import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_stats_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/add_popup_button.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';

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

              // ── Right: add popup button ───────────────────────────────
              const SmarthomeAddButton(),
            ],
          ),

          // ── Stats bar (manages its own top spacing) ───────────────
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

}



// ─── Stats bar ────────────────────────────────────────────────────────────────

class _StatsBar extends ConsumerWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeStatsProvider);

    final cells = <Widget>[];

    if (stats.temp != null) {
      cells.add(_StatCell(
        label: 'Nhiệt độ',
        value: '${stats.temp!.toStringAsFixed(1)}°C',
        icon: stats.fromWeather ? Icons.cloud_outlined : Icons.thermostat_outlined,
      ));
    } else if (stats.weatherLoading) {
      cells.add(const _StatCell(
        label: 'Nhiệt độ',
        value: '…',
        icon: Icons.cloud_outlined,
        muted: true,
      ));
    }

    if (stats.hum != null) {
      cells.add(_StatCell(
        label: 'Độ ẩm',
        value: '${stats.hum!.toStringAsFixed(0)}%',
        icon: stats.fromWeather ? Icons.cloud_outlined : Icons.water_drop_outlined,
      ));
    } else if (stats.weatherLoading) {
      cells.add(const _StatCell(
        label: 'Độ ẩm',
        value: '…',
        icon: Icons.cloud_outlined,
        muted: true,
      ));
    }

    if (stats.totalPowerKw != null) {
      cells.add(_StatCell(
        label: 'Điện',
        value: '${stats.totalPowerKw!.toStringAsFixed(1)}kW',
        icon: Icons.bolt_outlined,
      ));
    }

    if (cells.isEmpty) return const SizedBox.shrink();

    final rowChildren = <Widget>[];
    for (int i = 0; i < cells.length; i++) {
      rowChildren.add(Expanded(child: cells[i]));
      if (i < cells.length - 1) rowChildren.add(_Divider());
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          color: MpColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MpColors.border, width: 0.5),
        ),
        child: IntrinsicHeight(
          child: Row(children: rowChildren),
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
    this.muted = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool muted;

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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: muted ? MpColors.text3 : MpColors.text,
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
