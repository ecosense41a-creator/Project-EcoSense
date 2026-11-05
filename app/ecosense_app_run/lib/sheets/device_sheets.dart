import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/device.dart';
import '../models/room_view.dart';
import '../theme/eco_theme.dart';
import '../utils/device_actions.dart';
import '../utils/format.dart';
import '../utils/stream_utils.dart';
import '../widgets/common.dart';
import '../widgets/device_row.dart';
import '../widgets/eco_icons.dart';
import '../widgets/eco_sheet.dart';
import '../widgets/eco_switch.dart';
import '../widgets/eco_widgets.dart';
import '../widgets/glass_card.dart';
import 'room_sheets.dart';

// ---- All appliances ---------------------------------------------------------

Future<void> showAllDevicesSheet(
  BuildContext context, {
  required AppScope scope,
  required String roomId,
  required String roomName,
}) {
  return showEcoSheet<void>(
    context,
    title: 'All appliances',
    subtitle: roomName,
    builder: (_) => _AllDevicesBody(scope: scope, roomId: roomId, roomName: roomName),
  );
}

class _AllDevicesBody extends StatefulWidget {
  const _AllDevicesBody({required this.scope, required this.roomId, required this.roomName});

  final AppScope scope;
  final String roomId;
  final String roomName;

  @override
  State<_AllDevicesBody> createState() => _AllDevicesBodyState();
}

class _AllDevicesBodyState extends State<_AllDevicesBody> {
  late final Stream<RoomLive> _stream = roomLiveStream(widget.scope.repo, widget.roomId);

  @override
  Widget build(BuildContext context) {
    final repo = widget.scope.repo;
    return StreamBuilder<RoomLive>(
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final live = snap.data!;
        return TickBuilder(
          builder: (context) {
            final view = roomViewOf(live.status, widget.scope.serverOffsetMs);
            return Column(
              children: [
                if (live.devices.isEmpty)
                  const EmptyCard('No appliances added to this room yet.')
                else
                  for (final d in live.devices)
                    DeviceRow(
                      device: d,
                      detail: true,
                      hubOnline: view.online,
                      onToggle: (on) => requestDevice(context, repo, widget.roomId, d, on),
                      onRetry: () =>
                          requestDevice(context, repo, widget.roomId, d, d.requestedState == 'on'),
                      onConfigure: () => showDeviceSheet(
                        context,
                        scope: widget.scope,
                        roomId: widget.roomId,
                        roomName: widget.roomName,
                        deviceId: d.id,
                      ),
                    ),
                const SizedBox(height: 4),
                EcoButton(
                  label: 'Add an appliance',
                  icon: Icons.add_rounded,
                  onPressed: () => showAddDeviceSheet(
                    context,
                    scope: widget.scope,
                    roomId: widget.roomId,
                    roomName: widget.roomName,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---- One appliance: safety + details ---------------------------------------

Future<void> showDeviceSheet(
  BuildContext context, {
  required AppScope scope,
  required String roomId,
  required String roomName,
  required String deviceId,
}) {
  return showEcoSheet<void>(
    context,
    title: 'Appliance safety',
    subtitle: roomName,
    builder: (_) => _DeviceBody(scope: scope, roomId: roomId, deviceId: deviceId),
  );
}

class _DeviceBody extends StatefulWidget {
  const _DeviceBody({required this.scope, required this.roomId, required this.deviceId});

  final AppScope scope;
  final String roomId;
  final String deviceId;

  @override
  State<_DeviceBody> createState() => _DeviceBodyState();
}

class _DeviceBodyState extends State<_DeviceBody> {
  late final Stream<List<Device>> _stream = widget.scope.repo.devices(widget.roomId);

  Future<void> _setEligible(Device d, bool value) async {
    final repo = widget.scope.repo;
    try {
      await repo.setDeviceCutoffAllowed(widget.roomId, d.id, value);
      await repo.addLog(
        widget.roomId,
        type: 'manual',
        title: '${d.name}${value ? ' allowed for auto cut-off' : ' excluded from auto cut-off'}',
        detail: 'Appliance permission updated by ${widget.scope.username}.',
      );
    } catch (e) {
      if (mounted) showEcoToast(context, 'Could not save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return StreamBuilder<List<Device>>(
      stream: _stream,
      builder: (context, snap) {
        final list = snap.data;
        if (list == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final matches = list.where((d) => d.id == widget.deviceId);
        if (matches.isEmpty) return const EmptyCard('This appliance no longer exists.');
        final d = matches.first;
        return TickBuilder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: d.isOn ? e.accentSoft : e.chip,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(deviceIconFor(d.name), color: d.isOn ? e.accentDeep : e.ink2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(d.name, style: EcoText.strong(e, size: 17))),
                  StatusBadge(
                    label: d.isOn ? 'On' : 'Off',
                    tone: d.isOn ? Tone.good : Tone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Allow automatic cut-off', style: EcoText.strong(e, size: 14)),
                          const SizedBox(height: 4),
                          Text(
                            'Only after confirmed vacancy, and only in Auto mode.',
                            style: EcoText.small(e),
                          ),
                        ],
                      ),
                    ),
                    EcoSwitch(
                      value: d.eligible,
                      semanticLabel: 'Allow automatic cut-off for ${d.name}',
                      onChanged: (v) => _setEligible(d, v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const HelpNote(
                'Never enable automatic cut-off for essential or unsafe-to-interrupt '
                'equipment (medical devices, refrigerators, servers, routers).',
                icon: Icons.warning_amber_rounded,
                tone: Tone.warn,
              ),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    InfoRow(label: 'Power now', value: d.isOn ? '${d.watts.toStringAsFixed(1)} W' : '0 W'),
                    if (d.ratedWatts > 0)
                      InfoRow(label: 'Rated power', value: '${d.ratedWatts.round()} W'),
                    InfoRow(label: 'Energy consumed', value: '${d.energyWh.toStringAsFixed(1)} Wh'),
                    InfoRow(
                      label: 'Estimated energy saved',
                      value: '${d.savedWhEstimate.toStringAsFixed(1)} Wh',
                    ),
                    InfoRow(label: 'Last trigger', value: humanTrigger(d.triggerType)),
                    InfoRow(label: 'Last changed', value: formatAgeOfUnix(d.lastChanged)),
                    InfoRow(label: 'Smart plug', value: d.plugIp.isEmpty ? 'Not paired yet' : d.plugIp),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---- Restore appliances switched off by EcoSense ----------------------------

Future<void> showRestoreSheet(
  BuildContext context, {
  required AppScope scope,
  required String roomId,
  required String roomName,
  required List<Device> devices,
}) {
  return showEcoSheet<void>(
    context,
    title: 'Restore appliances',
    subtitle: 'Review before sending any power-on commands.',
    builder: (sheetContext) {
      final e = sheetContext.eco;
      return Column(
        children: [
          for (final d in devices)
            GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              radius: 15,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(deviceIconFor(d.name), size: 18, color: e.accentDeep),
                  const SizedBox(width: 10),
                  Expanded(child: Text(d.name, style: EcoText.strong(e, size: 14))),
                  Text('${d.ratedWatts.round()} W', style: EcoText.tiny(e)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: EcoButton(label: 'Cancel', onPressed: () => Navigator.of(sheetContext).pop()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: EcoButton(
                  label: 'Turn on ${devices.length}',
                  filled: true,
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    for (final d in devices) {
                      await requestDevice(context, scope.repo, roomId, d, true);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
