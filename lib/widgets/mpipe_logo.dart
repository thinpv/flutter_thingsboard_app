import 'dart:math';

import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';

/// Static mPipe logo: vòng tròn + chấm trung tâm + 4 nét tia.
class MpipeLogo extends StatelessWidget {
  const MpipeLogo({this.size = 36, this.color, super.key});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: MpipeLogoPainter(color: color ?? MpColors.text),
    );
  }
}

/// Animated mPipe spinner — logo quay tròn liên tục.
/// Drop-in replacement cho TbProgressIndicator.
class MpipeSpinner extends StatefulWidget {
  const MpipeSpinner({this.size = 36, this.color, super.key});
  final double size;
  final Color? color;

  @override
  State<MpipeSpinner> createState() => _MpipeSpinnerState();
}

class _MpipeSpinnerState extends State<MpipeSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? MpColors.text;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.rotate(
        angle: _ctrl.value * pi * 2,
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: MpipeLogoPainter(color: color),
        ),
      ),
    );
  }
}

/// CustomPainter vẽ logo mPipe.
class MpipeLogoPainter extends CustomPainter {
  const MpipeLogoPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.3125;
    final dotR = size.width * 0.0833;
    final lineLen = size.width * 0.104;
    final strokeW = size.width * 0.042;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawCircle(Offset(cx, cy), r, paint);

    canvas.drawCircle(
      Offset(cx, cy),
      dotR,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );

    final outerEdge = r + strokeW / 2;
    canvas.drawLine(Offset(cx, cy - outerEdge), Offset(cx, cy - outerEdge - lineLen), paint);
    canvas.drawLine(Offset(cx, cy + outerEdge), Offset(cx, cy + outerEdge + lineLen), paint);
    canvas.drawLine(Offset(cx - outerEdge, cy), Offset(cx - outerEdge - lineLen, cy), paint);
    canvas.drawLine(Offset(cx + outerEdge, cy), Offset(cx + outerEdge + lineLen, cy), paint);
  }

  @override
  bool shouldRepaint(MpipeLogoPainter old) => old.color != color;
}
