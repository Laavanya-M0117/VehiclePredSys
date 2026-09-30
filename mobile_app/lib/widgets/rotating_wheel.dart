import 'dart:math' as math;
import 'package:flutter/material.dart';

class RotatingWheelWidget extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const RotatingWheelWidget({
    super.key,
    this.size = 36.0,
    this.color = const Color(0xFF6C5CE7),
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<RotatingWheelWidget> createState() => _RotatingWheelWidgetState();
}

class _RotatingWheelWidgetState extends State<RotatingWheelWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
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
      builder: (context, child) {
        return Transform.rotate(
          angle: _ctrl.value * 2 * math.pi,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _WheelPainter(color: widget.color),
          ),
        );
      },
    );
  }
}

class _WheelPainter extends CustomPainter {
  final Color color;
  _WheelPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer tire
    final tirePaint = Paint()
      ..color = const Color(0xFF232736)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12;
    canvas.drawCircle(center, radius - size.width * 0.06, tirePaint);

    // Rim ring
    final rimPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06;
    canvas.drawCircle(center, radius - size.width * 0.16, rimPaint);

    // Center hub
    final hubPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.14, hubPaint);

    // 5 Alloy Spokes
    final spokePaint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - (math.pi / 2);
      final spokeEnd = Offset(
        center.dx + (radius - size.width * 0.16) * math.cos(angle),
        center.dy + (radius - size.width * 0.16) * math.sin(angle),
      );
      canvas.drawLine(center, spokeEnd, spokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => oldDelegate.color != color;
}
