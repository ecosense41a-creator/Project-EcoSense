import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// The prototype's translucent "glass" surface: soft fill, 1px light edge,
/// green-tinted shadow. (No backdrop blur: the background is a plain gradient,
/// so a blur would cost performance and show nothing.)
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 23,
    this.onTap,
    this.margin,
    this.fill,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final Color? fill;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final r = BorderRadius.circular(radius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(color: e.shadow, blurRadius: 28, offset: const Offset(0, 10)),
          const BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: fill ?? e.surface,
          borderRadius: r,
          border: Border.all(color: borderColor ?? e.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: r,
          child: InkWell(
            borderRadius: r,
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
