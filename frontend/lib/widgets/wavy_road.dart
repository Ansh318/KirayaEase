// import 'package:flutter/material.dart';
// import 'dart:math';

// class WavyRoad extends StatelessWidget {
//   const WavyRoad({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 250,
//       child: CustomPaint(
//         painter: _WavyRoadPainter(),
//         child: const Stack(
//           children: [
//             StepLabel(
//                 index: 1,
//                 title: "Faces Big Deposit",
//                 desc: "Tenant encounters upfront financial burden.",
//                 alignTop: true),
//             StepLabel(
//                 index: 2,
//                 title: "Lease Agreement Ready",
//                 desc: "Contract terms are finalized and signed.",
//                 alignTop: false),
//             StepLabel(
//                 index: 3,
//                 title: "Credit Line Approved",
//                 desc: "KirayaEase enables structured rent via credit.",
//                 alignTop: true),
//             StepLabel(
//                 index: 4,
//                 title: "Rent Payment Structured",
//                 desc: "Payments are scheduled across the month.",
//                 alignTop: false),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class StepLabel extends StatelessWidget {
//   final int index;
//   final String title;
//   final String desc;
//   final bool alignTop;

//   const StepLabel({
//     super.key,
//     required this.index,
//     required this.title,
//     required this.desc,
//     required this.alignTop,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     const totalSteps = 4; // total number of steps in the journey
//     final stepSpacing = width / (totalSteps + 1);
//     final xPos = stepSpacing * index;

//     return Positioned(
//       top: alignTop ? 20 : null,
//       bottom: alignTop ? null : 20,
//       left: xPos - 75,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(
//                 colors: [Color(0xFF4AC1EF), Color(0xFF2F80ED)],
//               ),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Text(
//               "$index",
//               style: const TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 14,
//                 color: Colors.white,
//               ),
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             title,
//             style: const TextStyle(fontWeight: FontWeight.bold),
//           ),
//           SizedBox(
//             width: 150,
//             child: Text(
//               desc,
//               style: const TextStyle(fontSize: 12, color: Colors.black54),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _WavyRoadPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final path = Path();
//     const waveHeight = 20.0;
//     final waveLength = size.width / 2;

//     path.moveTo(0, size.height / 2);
//     for (double x = 0; x <= size.width; x++) {
//       final y = size.height / 2 -
//           waveHeight * sin((x / waveLength) * 2 * pi) -
//           (x * 0.03); // upward slope
//       path.lineTo(x, y);
//     }

//     final roadPaint = Paint()
//       ..color = const Color(0xFF2F80ED)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 10
//       ..strokeCap = StrokeCap.round;

//     canvas.drawPath(path, roadPaint);

//     final dashPaint = Paint()
//       ..color = Colors.white
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2;

//     _drawDashedPath(canvas, path, dashPaint, dashLength: 12, gap: 6);
//   }

//   void _drawDashedPath(Canvas canvas, Path path, Paint paint,
//       {required double dashLength, required double gap}) {
//     final pathMetrics = path.computeMetrics();
//     for (final metric in pathMetrics) {
//       double distance = 0.0;
//       while (distance < metric.length) {
//         final next = distance + dashLength;
//         final extracted = metric.extractPath(
//           distance,
//           next.clamp(0.0, metric.length),
//         );
//         canvas.drawPath(extracted, paint);
//         distance += dashLength + gap;
//       }
//     }
//   }

//   @override
//   bool shouldRepaint(CustomPainter oldDelegate) => false;
// }

import 'package:flutter/material.dart';
import 'dart:math';

class WavyRoad extends StatelessWidget {
  const WavyRoad({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: CustomPaint(
        painter: _WavyRoadPainter(),
        child: const Stack(
          children: [
            StepLabel(
              index: 1,
              title: "Faces Big Deposit",
              desc: "Tenant encounters upfront financial burden.",
              alignTop: true,
            ),
            StepLabel(
              index: 2,
              title: "Lease Agreement Ready",
              desc: "Contract terms are finalized and signed.",
              alignTop: false,
            ),
            StepLabel(
              index: 3,
              title: "Credit Line Approved",
              desc: "KirayaEase enables structured rent via credit.",
              alignTop: true,
            ),
            StepLabel(
              index: 4,
              title: "Rent Payment Structured",
              desc: "Payments are scheduled across the month.",
              alignTop: false,
            ),
          ],
        ),
      ),
    );
  }
}

class StepLabel extends StatelessWidget {
  final int index;
  final String title;
  final String desc;
  final bool alignTop;

  const StepLabel({
    super.key,
    required this.index,
    required this.title,
    required this.desc,
    required this.alignTop,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    const totalSteps = 4;
    const labelWidth = 160.0;

    final stepSpacing = width / (totalSteps + 1);
    final xPos = stepSpacing * index;

    return Positioned(
      top: alignTop ? 20 : null,
      bottom: alignTop ? null : 20,
      left: xPos - (labelWidth / 2),
      child: SizedBox(
        width: labelWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4AC1EF), Color(0xFF2F80ED)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "$index",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              desc,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _WavyRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    const waveHeight = 20.0;
    final waveLength = size.width / 2;

    path.moveTo(0, size.height / 2);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height / 2 -
          waveHeight * sin((x / waveLength) * 2 * pi) -
          (x * 0.03); // upward slope
      path.lineTo(x, y);
    }

    final roadPaint = Paint()
      ..color = const Color(0xFF2F80ED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, roadPaint);

    final dashPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    _drawDashedPath(canvas, path, dashPaint, dashLength: 12, gap: 6);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {required double dashLength, required double gap}) {
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        final extracted = metric.extractPath(
          distance,
          next.clamp(0.0, metric.length),
        );
        canvas.drawPath(extracted, paint);
        distance += dashLength + gap;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
