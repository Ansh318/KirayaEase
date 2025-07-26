import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedWavyPath extends StatefulWidget {
  const AnimatedWavyPath({super.key});

  @override
  State<AnimatedWavyPath> createState() => _AnimatedWavyPathState();
}

class _AnimatedWavyPathState extends State<AnimatedWavyPath>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(); // Loop the wave
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        size: const Size(double.infinity, 200),
        painter: SlickWavePainter(progress: _controller.value),
      ),
    );
  }
}

class SlickWavePainter extends CustomPainter {
  final double progress;

  SlickWavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    const waveHeight = 24.0;
    final waveLength = size.width / 6;

    path.moveTo(0, size.height / 2);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height / 2 -
          waveHeight * sin((x / waveLength * 2 * pi) + (progress * 2 * pi)) -
          (x * 0.05); // upward slope
      path.lineTo(x, y);
    }

    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4AC1EF), Color(0xFF2F80ED)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);

    // 🏠 Emoji Anchors
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final emojis = ["🏠", "😓", "✍️", "💳", "📲", "✅", "💬"];
    final points = emojis.length;

    for (int i = 0; i < points; i++) {
      final x = (i + 1) * size.width / (points + 1);
      final y = size.height / 2 -
          waveHeight * sin((x / waveLength * 2 * pi) + (progress * 2 * pi)) -
          (x * 0.05);

      textPainter.text = TextSpan(
        text: emojis[i],
        style: const TextStyle(fontSize: 22),
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - 40),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SlickWavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
