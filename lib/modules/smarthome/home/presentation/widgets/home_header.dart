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
///   [weather icon]    (right side, decorative)
///   Stats bar: Nhiệt độ · Độ ẩm · Điện
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homes = ref.watch(homesProvider);
    final selectedHome = ref.watch(selectedHomeProvider);
    final stats = ref.watch(homeStatsProvider);

    final hour = DateTime.now().hour;
    final gradient = _skyGradient(hour, stats.weatherCode);

    return Container(
      decoration: BoxDecoration(gradient: gradient),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: _greetingColor(hour),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    homes.when(
                      loading: () => Text(
                        'SmartHome',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                          color: _textColor(hour),
                        ),
                      ),
                      error: (_, _) => Text('SmartHome',
                          style: TextStyle(fontSize: 22, color: _textColor(hour))),
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
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.3,
                                    color: _textColor(hour),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasMany) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: _greetingColor(hour),
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

              // ── Right: weather icon + add button ─────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SmarthomeAddButton(),
                  if (stats.fromWeather || stats.weatherLoading) ...[
                    const SizedBox(height: 6),
                    Icon(
                      _weatherIcon(stats.weatherCode),
                      size: 28,
                      color: _weatherIconColor(hour, stats.weatherCode),
                    ),
                  ],
                ],
              ),
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

  Color _textColor(int hour) {
    if (hour >= 6 && hour < 21) return MpColors.text;
    return const Color(0xFFF0F0F8); // sáng hơn ban đêm
  }

  Color _greetingColor(int hour) {
    if (hour >= 6 && hour < 21) return MpColors.text3;
    return const Color(0xFFB0B8D0);
  }

  LinearGradient _skyGradient(int hour, int? code) {
    // Mưa / mây dày → xám xanh
    if (code != null && code >= 51) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFCDD3DE), Color(0xFFF5F5F7)],
      );
    }
    if (hour >= 6 && hour < 11) {
      // Buổi sáng — vàng nhạt ấm áp
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF0C8), Color(0xFFF5F5F7)],
      );
    }
    if (hour >= 11 && hour < 17) {
      // Buổi trưa / chiều — xanh trời
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFCCE8F8), Color(0xFFF5F5F7)],
      );
    }
    if (hour >= 17 && hour < 20) {
      // Hoàng hôn — cam hồng
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFD0A0), Color(0xFFF5F5F7)],
      );
    }
    // Ban đêm — xanh tím tối
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1E2A48), Color(0xFF2A2A3A)],
    );
  }

  IconData _weatherIcon(int? code) {
    if (code == null) return Icons.wb_sunny_outlined;
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code <= 3) return Icons.wb_cloudy_outlined;
    if (code <= 48) return Icons.cloud_outlined;
    if (code <= 67) return Icons.grain_outlined; // drizzle/rain
    if (code <= 77) return Icons.ac_unit_outlined; // snow
    if (code <= 82) return Icons.umbrella_outlined; // showers
    return Icons.thunderstorm_outlined; // storm
  }

  Color _weatherIconColor(int hour, int? code) {
    if (code != null && code >= 51) return const Color(0xFF7A90B0);
    if (hour >= 17 && hour < 20) return const Color(0xFFE87020);
    if (hour >= 6 && hour < 17) return const Color(0xFFF0A020);
    return const Color(0xFF8899CC); // night stars
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
