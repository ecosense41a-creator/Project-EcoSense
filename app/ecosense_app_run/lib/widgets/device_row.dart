import 'package:flutter/material.dart';

import '../models/device.dart';
import '../theme/eco_theme.dart';
import 'eco_icons.dart';
import 'eco_switch.dart';
import 'glass_card.dart';

/// One appliance: icon, name, status line, switch (and optional settings button).
class DeviceRow extends StatelessWidget {
  const DeviceRow({
    super.key,
    required this.device,
    required this.hubOnline,
    required this.onToggle,
    required this.onRetry,
    this.onConfigure,
    this.detail = false,
  });

  final Device device;
  final bool hubOnline;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRetry;

  /// Shows the settings button and the "Auto cut-off allowed" suffix.
  final VoidCallback? onConfigure;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final phase = device.phase(now);
    final pending = phase == CommandPhase.pending;
    final unconfirmed = phase == CommandPhase.unconfirmed;
    final last = device.isOn ? 'on' : 'off';

    String status;
    if (pending) {
      status = 'Switching…';
    } else if (unconfirmed) {
      status = 'Power state unconfirmed · last known $last';
    } else if (!hubOnline) {
      status = 'Hub offline · last known $last';
    } else if (device.isOn) {
      status = '${device.watts.round()} W · On';
    } else {
      status = device.switchedOffByAutomation ? 'Off · automatic' : 'Off';
    }

    final canSwitch = hubOnline && !unconfirmed;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      onTap: onConfigure,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 53),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: device.isOn ? e.accentSoft : e.chip,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                deviceIconFor(device.name),
                size: 20,
                color: device.isOn ? e.accentDeep : e.ink2,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EcoText.strong(e, size: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: EcoText.tiny(e).copyWith(
                      fontSize: 13,
                      color: (unconfirmed || pending) ? e.warnInk : e.ink2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    device.eligible ? 'Auto shutoff enabled' : 'Manual only',
                    style: EcoText.small(e).copyWith(fontSize: 13),
                  ),
                  if (unconfirmed && hubOnline)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: GestureDetector(
                        onTap: onRetry,
                        child: Text(
                          'Retry command',
                          style: EcoText.button(e.accentDeep).copyWith(
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            EcoSwitch(
              value: device.isOn,
              pending: pending,
              semanticLabel: '${device.isOn ? 'Turn off' : 'Turn on'} ${device.name}',
              onChanged: canSwitch ? onToggle : null,
            ),
            if (onConfigure != null)
              IconButton(
                tooltip: 'Automation settings for ${device.name}',
                onPressed: onConfigure,
                icon: Icon(Icons.tune_rounded, size: 20, color: e.ink2),
              ),
          ],
        ),
      ),
    );
  }
}
