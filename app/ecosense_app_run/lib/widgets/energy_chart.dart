import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// Line + gradient-fill chart with a selectable point (prototype "Energy
/// insights"). Tap or drag to select a bucket.
class EnergyChart extends StatelessWidget {
  const EnergyChart({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelect,
    this.height = 150,
  });

  final List<double> values;
  final int selected;
  final ValueChanged<int> onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return LayoutBuilder(
      builder: (context, c) {
        void pick(double dx) {
          if (values.isEmpty) return;
          final w = c.maxWidth - 20;
          final i = values.length == 1
              ? 0
              : (((dx - 10) / w) * (values.length - 1)).round().clamp(0, values.length - 1);
          onSelect(i);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => pick(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
          child: CustomPaint(
            size: Size(c.maxWidth, height),
            painter: _ChartPainter(
              values: values,
              selected: selected,
              line: e.accent,
              guide: e.ink3,
              dotFill: e.solid,
            ),
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.values,
    required this.selected,
    required this.line,
    required this.guide,
    required this.dotFill,
  });

  final List<double> values;
  final int selected;
  final Color line;
  final Color guide;
  final Color dotFill;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 10.0, right = 10.0, top = 12.0, bottom = 8.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final n = values.length;
    if (n == 0) return;
    final maxV = math.max(values.reduce(math.max), 0.0001);
    Offset pt(int i) => Offset(
          left + (n == 1 ? w / 2 : w * i / (n - 1)),
          top + h * (1 - values[i] / maxV),
        );

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < n; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final fill = Path.from(path)
      ..lineTo(pt(n - 1).dx, size.height - bottom)
      ..lineTo(pt(0).dx, size.height - bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.34), line.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final s = selected.clamp(0, n - 1);
    final p = pt(s);
    final guidePaint = Paint()
      ..color = guide.withValues(alpha: 0.48)
      ..strokeWidth = 1;
    for (double y = top - 2; y < size.height - bottom; y += 8) {
      canvas.drawLine(Offset(p.dx, y), Offset(p.dx, math.min(y + 3, size.height - bottom)), guidePaint);
    }
    canvas.drawCircle(p, 6, Paint()..color = dotFill);
    canvas.drawCircle(
      p,
      6,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.values != values || old.selected != selected || old.line != line;
}
