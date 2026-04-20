import 'dart:math' as math;
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
      final t = stats.temp!;
      cells.add(_StatCell(
        metricKey: 'temp',
        label: 'Nhiệt độ',
        value: '${t.toStringAsFixed(1)}°C',
        icon: Icons.device_thermostat,
        accentColor: t < 18
            ? const Color(0xFF42A5F5)
            : t < 26
                ? const Color(0xFF66BB6A)
                : t < 32
                    ? const Color(0xFFFFA726)
                    : const Color(0xFFEF5350),
        fraction: (t.clamp(0, 50) / 50),
        pulse: t > 38,
      ));
    } else if (stats.weatherLoading) {
      cells.add(const _StatCell(
        metricKey: '',
        label: 'Nhiệt độ',
        value: '…',
        icon: Icons.device_thermostat,
        muted: true,
      ));
    }

    if (stats.hum != null) {
      final h = stats.hum!;
      cells.add(_StatCell(
        metricKey: 'hum',
        label: 'Độ ẩm',
        value: '${h.toStringAsFixed(0)}%',
        icon: Icons.water_drop,
        accentColor: h < 30
            ? const Color(0xFFFFA726)
            : h < 70
                ? const Color(0xFF42A5F5)
                : const Color(0xFF1565C0),
        fraction: h / 100,
        pulse: false,
      ));
    } else if (stats.weatherLoading) {
      cells.add(const _StatCell(
        metricKey: '',
        label: 'Độ ẩm',
        value: '…',
        icon: Icons.water_drop,
        muted: true,
      ));
    }

    if (stats.totalPowerKw != null) {
      final p = stats.totalPowerKw!;
      cells.add(_StatCell(
        metricKey: 'power',
        label: 'Điện',
        value: '${p.toStringAsFixed(1)} kW',
        icon: Icons.bolt,
        accentColor: p < 0.5
            ? const Color(0xFF66BB6A)
            : p < 2
                ? const Color(0xFFFFA726)
                : const Color(0xFFEF5350),
        fraction: (p.clamp(0, 5) / 5),
        pulse: p > 3,
      ));
    }

    if (cells.isEmpty) return const SizedBox.shrink();

    final rowChildren = <Widget>[];
    for (int i = 0; i < cells.length; i++) {
      rowChildren.add(Expanded(child: cells[i]));
      if (i < cells.length - 1) {
        rowChildren.add(Container(width: 0.5, color: MpColors.border));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          color: MpColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MpColors.border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(child: Row(children: rowChildren)),
      ),
    );
  }
}

// ─── Individual stat cell ─────────────────────────────────────────────────────

class _StatCell extends StatefulWidget {
  const _StatCell({
    required this.metricKey,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.fraction,
    this.pulse = false,
    this.muted = false,
  });

  final String metricKey;
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final double? fraction;
  final bool pulse;
  final bool muted;

  @override
  State<_StatCell> createState() => _StatCellState();
}

class _StatCellState extends State<_StatCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.pulse) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatCell old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.pulse && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.muted
        ? MpColors.text3
        : (widget.accentColor ?? MpColors.text3);

    Widget visual;
    if (!widget.muted && widget.fraction != null) {
      if (widget.metricKey == 'temp') {
        visual = _AnimatedThermometer(fraction: widget.fraction!, color: color);
      } else if (widget.metricKey == 'hum') {
        visual = _AnimatedWave(fraction: widget.fraction!, color: color);
      } else {
        // power: bolt with optional pulse
        final bolt = Icon(widget.icon, size: 28, color: color);
        visual = widget.pulse
            ? AnimatedBuilder(
                animation: _opacity,
                builder: (_, __) =>
                    Opacity(opacity: _opacity.value, child: bolt),
              )
            : bolt;
      }
    } else {
      visual = Icon(widget.icon, size: 28, color: color);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              visual,
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 11,
                  color: MpColors.text3,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: widget.muted ? MpColors.text3 : MpColors.text,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        if (widget.fraction != null && !widget.muted)
          _LevelBar(fraction: widget.fraction!, color: color),
      ],
    );
  }
}

// ─── Animated thermometer ─────────────────────────────────────────────────────

class _AnimatedThermometer extends StatefulWidget {
  const _AnimatedThermometer({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  State<_AnimatedThermometer> createState() => _AnimatedThermometerState();
}

class _AnimatedThermometerState extends State<_AnimatedThermometer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _frac;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _frac = Tween<double>(begin: 0, end: widget.fraction)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedThermometer old) {
    super.didUpdateWidget(old);
    if (old.fraction != widget.fraction) {
      _frac = Tween<double>(begin: old.fraction, end: widget.fraction)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: const Size(28, 52),
        painter: _ThermoPainter(fraction: _frac.value, color: widget.color),
      ),
    );
  }
}

class _ThermoPainter extends CustomPainter {
  const _ThermoPainter({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final tubeW = w * 0.28;
    final bulbR = w * 0.38;
    final tubeLeft = cx - tubeW / 2;
    final tubeTop = 2.0;
    final bulbCy = h - bulbR;
    final tubeBottom = bulbCy;

    final bgPaint = Paint()..color = color.withOpacity(0.15);
    final fillPaint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final tubeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tubeLeft, tubeTop, tubeW, tubeBottom - tubeTop),
      const Radius.circular(3),
    );
    final bulbRect =
        Rect.fromCircle(center: Offset(cx, bulbCy), radius: bulbR);

    // Clip to thermometer shape
    final clip = Path()
      ..addRRect(tubeRect)
      ..addOval(bulbRect);
    canvas.save();
    canvas.clipPath(clip);

    // Background
    canvas.drawPath(clip, bgPaint);

    // Fill from bulb up
    final fillH = (tubeBottom - tubeTop) * fraction;
    canvas.drawRect(
      Rect.fromLTWH(0, tubeBottom - fillH, w, h),
      fillPaint,
    );
    canvas.restore();

    // Border outline
    canvas.drawRRect(tubeRect, borderPaint);
    canvas.drawCircle(Offset(cx, bulbCy), bulbR, borderPaint);

    // Tick marks
    final tickPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final ty = tubeTop + (tubeBottom - tubeTop) * i / 4;
      canvas.drawLine(
        Offset(tubeLeft - 1, ty),
        Offset(tubeLeft - 4, ty),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ThermoPainter old) =>
      old.fraction != fraction || old.color != color;
}

// ─── Animated wave (humidity) ─────────────────────────────────────────────────

class _AnimatedWave extends StatefulWidget {
  const _AnimatedWave({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  State<_AnimatedWave> createState() => _AnimatedWaveState();
}

class _AnimatedWaveState extends State<_AnimatedWave>
    with TickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  late final AnimationController _fillCtrl;
  late Animation<double> _fillAnim;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _fillCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fillAnim = Tween<double>(begin: 0, end: widget.fraction)
        .animate(CurvedAnimation(parent: _fillCtrl, curve: Curves.easeOut));
    _fillCtrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedWave old) {
    super.didUpdateWidget(old);
    if (old.fraction != widget.fraction) {
      _fillAnim = Tween<double>(begin: old.fraction, end: widget.fraction)
          .animate(CurvedAnimation(parent: _fillCtrl, curve: Curves.easeOut));
      _fillCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _fillCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_waveCtrl, _fillCtrl]),
      builder: (_, __) => CustomPaint(
        size: const Size(44, 44),
        painter: _WavePainter(
          phase: _waveCtrl.value,
          fraction: _fillAnim.value,
          color: widget.color,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter(
      {required this.phase, required this.fraction, required this.color});
  final double phase;
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;

    // Circular clip
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, w, h)));

    // BG tint
    canvas.drawCircle(
        Offset(r, r), r, Paint()..color = color.withOpacity(0.12));

    // Wave
    final fillY = h * (1 - fraction.clamp(0.0, 1.0));
    final path = Path();
    const amp = 3.5;
    for (double x = 0; x <= w + 1; x++) {
      final y = fillY +
          amp * math.sin((x / w * 2 * math.pi) + phase * 2 * math.pi);
      x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withOpacity(0.75));

    // Second wave (offset phase, lighter)
    final path2 = Path();
    for (double x = 0; x <= w + 1; x++) {
      final y = fillY +
          amp *
              math.sin(
                  (x / w * 2 * math.pi) + (phase + 0.5) * 2 * math.pi) +
          2;
      x == 0 ? path2.moveTo(x, y) : path2.lineTo(x, y);
    }
    path2
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path2, Paint()..color = color.withOpacity(0.35));

    canvas.restore();

    // Circle border
    canvas.drawCircle(
      Offset(r, r),
      r - 0.5,
      Paint()
        ..color = color.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.phase != phase || old.fraction != fraction || old.color != color;
}

// ─── Thin level bar ───────────────────────────────────────────────────────────

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: MpColors.border),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction.clamp(0.0, 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
            ),
          ),
        ],
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
