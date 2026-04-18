import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: pos (0-100%), onoff0 (open/close state)
class CurtainControl extends StatefulWidget {
  const CurtainControl({required this.telemetry, required this.onRpc, super.key});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String, Map<String, dynamic>) onRpc;

  @override
  State<CurtainControl> createState() => _CurtainControlState();
}

class _CurtainControlState extends State<CurtainControl>
    with SingleTickerProviderStateMixin {
  late double _pos;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _pos = (doubleVal(widget.telemetry['pos']) ?? 0).clamp(0, 100);
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void didUpdateWidget(CurtainControl old) {
    super.didUpdateWidget(old);
    final p = doubleVal(widget.telemetry['pos']);
    if (p != null) setState(() => _pos = p.clamp(0, 100));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 16),

        // Curtain visual
        Center(
          child: SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: _CurtainPainter(position: _pos / 100, color: MpColors.text),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '${_pos.round()}%',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: MpColors.text),
          ),
        ),
        Center(
          child: Text(
            _pos >= 100
                ? 'Mở hoàn toàn'
                : _pos <= 0
                    ? 'Đóng hoàn toàn'
                    : 'Mở ${_pos.round()}%',
            style: const TextStyle(fontSize: 14, color: MpColors.text3),
          ),
        ),
        const SizedBox(height: 24),

        // Position slider
        SliderTheme(
          data: const SliderThemeData(
            trackHeight: 8,
            activeTrackColor: MpColors.text,
            thumbColor: MpColors.text,
          ),
          child: Slider(
            value: _pos,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${_pos.round()}%',
            onChanged: (v) => setState(() => _pos = v),
            onChangeEnd: (v) => widget.onRpc('setPosition', {'pos': v.round()}),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Đóng', style: TextStyle(fontSize: 12, color: MpColors.text3)),
            Text('Mở', style: TextStyle(fontSize: 12, color: MpColors.text3)),
          ],
        ),
        const SizedBox(height: 24),

        // Control buttons
        Row(
          children: [
            Expanded(
              child: _CurtainActionButton(
                icon: Icons.keyboard_double_arrow_up,
                label: 'Mở',
                color: MpColors.green,
                bgColor: MpColors.greenSoft,
                onTap: () => widget.onRpc('open', {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CurtainActionButton(
                icon: Icons.stop_rounded,
                label: 'Dừng',
                color: MpColors.amber,
                bgColor: MpColors.amberSoft,
                onTap: () => widget.onRpc('stop', {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CurtainActionButton(
                icon: Icons.keyboard_double_arrow_down,
                label: 'Đóng',
                color: MpColors.text2,
                bgColor: MpColors.surfaceAlt,
                onTap: () => widget.onRpc('close', {}),
              ),
            ),
          ],
        ),

        // Preset positions
        const SizedBox(height: 20),
        const Text('Vị trí nhanh',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: MpColors.text2, letterSpacing: 0.4)),
        const SizedBox(height: 10),
        Row(
          children: [25, 50, 75, 100].map((pct) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _pos = pct.toDouble());
                    widget.onRpc('setPosition', {'pos': pct});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: MpColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MpColors.border, width: 0.5),
                    ),
                    alignment: Alignment.center,
                    child: Text('$pct%',
                        style: const TextStyle(fontSize: 13,
                            color: MpColors.text2, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CurtainActionButton extends StatelessWidget {
  const _CurtainActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MpColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _CurtainPainter extends CustomPainter {
  const _CurtainPainter({required this.position, required this.color});
  final double position;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Rod
    canvas.drawLine(
      const Offset(10, 10),
      Offset(size.width - 10, 10),
      Paint()
        ..color = const Color(0xFFB0AFA8)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Ring hooks
    for (int i = 0; i < 7; i++) {
      final x = 16.0 + (size.width - 32) * i / 6;
      canvas.drawCircle(Offset(x, 10), 4, Paint()..color = const Color(0xFFCCCAC2));
    }

    final curtainPaint = Paint()..color = color.withValues(alpha: 0.25);
    final curtainBorder = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final openW = size.width * 0.5 * position;
    final leftRect = Rect.fromLTWH(0, 18, size.width * 0.5 - openW, size.height - 18);
    final rightRect = Rect.fromLTWH(size.width * 0.5 + openW, 18, size.width * 0.5 - openW, size.height - 18);

    const rr = Radius.circular(4);
    if (leftRect.width > 0) {
      final rrect = RRect.fromRectAndRadius(leftRect, rr);
      canvas.drawRRect(rrect, curtainPaint);
      canvas.drawRRect(rrect, curtainBorder);
      for (int i = 1; i <= 4; i++) {
        final y = 18.0 + (size.height - 18) * i / 5;
        canvas.drawLine(Offset(leftRect.left + 4, y), Offset(leftRect.right - 4, y),
            Paint()..color = color.withValues(alpha: 0.15)..strokeWidth = 1);
      }
    }
    if (rightRect.width > 0) {
      final rrect = RRect.fromRectAndRadius(rightRect, rr);
      canvas.drawRRect(rrect, curtainPaint);
      canvas.drawRRect(rrect, curtainBorder);
      for (int i = 1; i <= 4; i++) {
        final y = 18.0 + (size.height - 18) * i / 5;
        canvas.drawLine(Offset(rightRect.left + 4, y), Offset(rightRect.right - 4, y),
            Paint()..color = color.withValues(alpha: 0.15)..strokeWidth = 1);
      }
    }

    // Window light effect
    if (position > 0.05) {
      canvas.drawRect(
        Rect.fromLTWH(size.width * 0.5 - openW, 18, openW * 2, size.height - 18),
        Paint()..color = const Color(0xFFFFD080).withValues(alpha: 0.15 * position),
      );
    }
  }

  @override
  bool shouldRepaint(_CurtainPainter old) => old.position != position;
}
