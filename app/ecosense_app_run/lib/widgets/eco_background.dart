import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/eco_theme.dart';

/// The soft vertical gradient behind every screen.
class EcoBackground extends StatelessWidget {
  const EcoBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [e.bg1, e.bg2],
          ),
        ),
        child: child,
      ),
    );
  }
}
