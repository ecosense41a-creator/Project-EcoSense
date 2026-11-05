import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// The prototype's 51x32 switch, with an amber "pending" state while a command
/// is waiting for the hub.
class EcoSwitch extends StatelessWidget {
  const EcoSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.pending = false,
    this.semanticLabel,
  });

  final bool value;
  final bool pending;

  /// null = disabled.
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final enabled = onChanged != null && !pending;
    final track = pending ? e.amber : (value ? e.accent : e.line);
    final left = pending ? 13.0 : (value ? 22.0 : 3.0);
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: (onChanged == null && !pending) ? 0.5 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              width: 51,
              height: 32,
              decoration: BoxDecoration(
                color: track,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 170),
                    left: left,
                    top: 3,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x24000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
