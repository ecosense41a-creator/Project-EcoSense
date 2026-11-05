import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// The 41-tick, 270-degree confidence dial from the prototype.
class StatusDial extends StatelessWidget {
  const StatusDial({
    super.key,
    required this.percent,
    required this.color,
    this.size = 130,
  });

  /// 0..100, or null when there is no signal.
  final double? percent;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final inner = size * (1 - 2 * 23 / 130);
    return Semantics(
      label: percent == null
          ? 'Presence confidence unavailable'
          : '${percent!.round()} percent presence confidence',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _DialPainter(percent: percent, lit: color, unlit: e.line),
            ),
            Container(
              width: inner,
              height: inner,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(0, -0.36),
                  radius: 0.95,
                  colors: [e.solid, e.chip],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    percent == null ? '—' : '${percent!.round()}%',
                    style: EcoText.bigNumber(e, size: size * 0.23).copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -size * 0.23 * 0.06,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    percent == null ? 'No signal' : 'Confidence',
                    style: EcoText.tiny(e).copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.percent, required this.lit, required this.unlit});

  final double? percent;
  final Color lit;
  final Color unlit;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 41;
    final k = size.width / 200;
    final c = Offset(size.width / 2, size.height / 2);
    final litCount = percent == null ? 0 : (count * percent! / 100).round();
    final paint = Paint()
      ..strokeWidth = 3.8 * k
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final a = (135 + i * 270 / (count - 1)) * math.pi / 180;
      final dir = Offset(math.cos(a), math.sin(a));
      paint.color = i < litCount ? lit : unlit;
      canvas.drawLine(c + dir * (78 * k), c + dir * (90 * k), paint);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.percent != percent || old.lit != lit || old.unlit != unlit;
}
