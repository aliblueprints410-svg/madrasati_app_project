import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiCelebrationOverlay extends StatefulWidget {
  final Widget child;
  const ConfettiCelebrationOverlay({Key? key, required this.child}) : super(key: key);

  static void trigger(BuildContext context) {
    final state = context.findAncestorStateOfType<_ConfettiCelebrationOverlayState>();
    state?.celebrate();
  }

  @override
  State<ConfettiCelebrationOverlay> createState() => _ConfettiCelebrationOverlayState();
}

class _ConfettiCelebrationOverlayState extends State<ConfettiCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void celebrate() {
    _particles.clear();
    final colors = [
      Colors.amber,
      Colors.greenAccent,
      Colors.deepOrangeAccent,
      Colors.pinkAccent,
      Colors.lightBlueAccent,
      Colors.purpleAccent,
      Colors.yellowAccent,
    ];

    for (int i = 0; i < 70; i++) {
      _particles.add(
        _Particle(
          x: 0.5 + (_random.nextDouble() - 0.5) * 0.4,
          y: 0.4,
          vx: (_random.nextDouble() - 0.5) * 800,
          vy: -_random.nextDouble() * 700 - 200,
          color: colors[_random.nextInt(colors.length)],
          size: _random.nextDouble() * 8 + 4,
          rotation: _random.nextDouble() * 2 * pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 10,
          isStar: _random.nextBool(),
        ),
      );
    }

    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_controller.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _controller.value,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double rotation;
  double rotationSpeed;
  bool isStar;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.isStar,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final gravity = 900.0;
    final t = progress * 2.5;

    for (final p in particles) {
      final currentX = p.x * size.width + p.vx * (progress * 1.5);
      final currentY = p.y * size.height + p.vy * t + 0.5 * gravity * t * t;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(p.rotation + p.rotationSpeed * progress);

      if (p.isStar) {
        _drawStar(canvas, p.size, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size * 1.4, height: p.size * 0.8),
            const Radius.circular(2),
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, double radius, Paint paint) {
    final path = Path();
    final double innerRadius = radius * 0.45;
    for (int i = 0; i < 5; i++) {
      final double outerAngle = -pi / 2 + i * 2 * pi / 5;
      final double innerAngle = outerAngle + pi / 5;
      final x1 = radius * cos(outerAngle);
      final y1 = radius * sin(outerAngle);
      final x2 = innerRadius * cos(innerAngle);
      final y2 = innerRadius * sin(innerAngle);

      if (i == 0) {
        path.moveTo(x1, y1);
      } else {
        path.lineTo(x1, y1);
      }
      path.lineTo(x2, y2);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
