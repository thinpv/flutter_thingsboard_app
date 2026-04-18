import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';

/// mPipe login header: target logo icon + "mPipe" wordmark.
class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MpipeLogo(size: 42),
            const SizedBox(width: 12),
            const Text(
              'mPipe',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.6,
                color: MpColors.text,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Vẽ logo mPipe: vòng tròn + chấm trung tâm + 4 nét ra ngoài (target/radar).
class _MpipeLogo extends StatelessWidget {
  const _MpipeLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LogoPainter(color: MpColors.text),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.3125; // 11.25/36 of original
    final dotR = size.width * 0.0833; // 3/36
    final lineLen = size.width * 0.104; // ~3.75/36 from edge of circle to end
    final strokeW = size.width * 0.042; // ~1.5/36

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Outer ring
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // Center dot
    canvas.drawCircle(
      Offset(cx, cy),
      dotR,
      Paint()..color = color..isAntiAlias = true,
    );

    // 4 spokes: top, bottom, left, right
    final outerEdge = r + strokeW / 2;
    final tipLen = lineLen;

    // Top
    canvas.drawLine(
      Offset(cx, cy - outerEdge),
      Offset(cx, cy - outerEdge - tipLen),
      paint,
    );
    // Bottom
    canvas.drawLine(
      Offset(cx, cy + outerEdge),
      Offset(cx, cy + outerEdge + tipLen),
      paint,
    );
    // Left
    canvas.drawLine(
      Offset(cx - outerEdge, cy),
      Offset(cx - outerEdge - tipLen, cy),
      paint,
    );
    // Right
    canvas.drawLine(
      Offset(cx + outerEdge, cy),
      Offset(cx + outerEdge + tipLen, cy),
      paint,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color;
}
