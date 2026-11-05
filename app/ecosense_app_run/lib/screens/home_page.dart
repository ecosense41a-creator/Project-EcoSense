import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../config.dart';
import '../models/automation_mode.dart';
import '../models/device.dart';
import '../models/room.dart';
import '../models/room_view.dart';
import '../sheets/device_sheets.dart';
import '../sheets/room_sheets.dart';
import '../theme/eco_theme.dart';
import '../utils/device_actions.dart';
import '../utils/format.dart';
import '../utils/home_data.dart';
import '../widgets/common.dart';
import '../widgets/device_row.dart';
import '../widgets/eco_sheet.dart';
import '../widgets/eco_widgets.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_dial.dart';

/// The selected room: presence dial, sensors, appliances, savings.
/// (Replaces the old Status + Sensors tabs.)
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.roomId,
    required this.rooms,
    required this.onSelectRoom,
    required this.onOpenInsightsToday,
  });

  final String roomId;
  final List<RoomInfo> rooms;
  final ValueChanged<String> onSelectRoom;
  final VoidCallback onOpenInsightsToday;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Stream<HomeData>? _stream;
  String? _boundRoom;
  Object? _boundRepo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(HomePage old) {
    super.didUpdateWidget(old);
    _bind();
  }

  // One listener set per room. Creating streams inside build() would open new
  // database listeners on every rebuild.
  void _bind() {
    final repo = AppScope.of(context).repo;
    if (_stream == null || _boundRoom != widget.roomId || !identical(_boundRepo, repo)) {
      _boundRoom = widget.roomId;
      _boundRepo = repo;
      _stream = homeDataStream(repo, widget.roomId);
    }
  }

  RoomInfo get _room => widget.rooms.firstWhere(
        (r) => r.id == widget.roomId,
        orElse: () => RoomInfo(
          id: widget.roomId,
          name: widget.roomId == kPrimaryRoomId ? kPrimaryRoomName : widget.roomId,
          createdAt: 0,
          userAdded: false,
          pauseUntil: 0,
        ),
      );

  Future<void> _pause(AppScope s) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      await s.repo.setRoomPause(widget.roomId, now + kPauseMinutes * 60);
      await s.repo.addLog(
        widget.roomId,
        type: 'manual',
        title: 'Automatic cut-off paused',
        detail: '$kPauseMinutes-minute room override activated.',
      );
      if (mounted) showEcoToast(context, 'Automatic cut-off paused for $kPauseMinutes minutes');
    } catch (err) {
      if (mounted) showEcoToast(context, 'Could not pause: $err');
    }
  }

  Future<void> _resume(AppScope s) async {
    try {
      await s.repo.setRoomPause(widget.roomId, 0);
      await s.repo.addLog(
        widget.roomId,
        type: 'manual',
        title: 'Automation resumed',
        detail: 'Temporary pause removed.',
      );
    } catch (err) {
      if (mounted) showEcoToast(context, 'Could not resume: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return StreamBuilder<HomeData>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return MessageView(
            icon: Icons.cloud_off,
            isError: true,
            message: 'Could not load this room.\n${snap.error}',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        return TickBuilder(
          builder: (context) => ListView(
            padding: const EdgeInsets.fromLTRB(19, 4, 19, 128),
            children: [_content(context, scope, _room, data)],
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, AppScope scope, RoomInfo room, HomeData d) {
    final e = context.eco;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final view = roomViewOf(d.status, scope.serverOffsetMs);
    final online = view.online;
    final anyUnconfirmed = d.devices.any((x) => x.phase(now) == CommandPhase.unconfirmed);
    final statsOk = online && !anyUnconfirmed;
    final onCount = d.devices.where((x) => x.isOn).length;
    final power = d.devices.fold<double>(0, (a, x) => a + x.watts);
    final shown = d.devices.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 3),
        Text('YOUR SPACE', style: EcoText.kicker(e)),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showChooseRoomSheet(
            context,
            scope: scope,
            rooms: widget.rooms,
            selectedId: widget.roomId,
            onSelect: widget.onSelectRoom,
            onCreated: widget.onSelectRoom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EcoText.roomTitle(e),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: e.accentDeep, size: 26),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: online ? e.accent : e.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    online ? 'Hub online' : 'Hub offline',
                    style: EcoText.button(online ? e.greenInk : e.red).copyWith(fontSize: 12),
                  ),
                ],
              ),
              Text(
                d.status == null
                    ? 'No signal yet'
                    : '${online ? 'Updated' : 'Last signal'} ${formatAgeOfUnix(d.status!.timestamp)}',
                style: EcoText.small(e).copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
        _presenceCard(context, scope, room, d, view, now),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatBox(
                icon: Icons.bolt_rounded,
                label: 'Power draw',
                number: statsOk ? power.round().toString() : '—',
                unit: statsOk ? ' W' : '',
                foot: statsOk ? 'Current estimate' : 'Live value unavailable',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBox(
                icon: Icons.power_outlined,
                label: 'Appliances on',
                number: statsOk ? '$onCount' : '—',
                unit: statsOk ? ' of ${d.devices.length}' : '',
                foot: statsOk ? 'Controllable plugs' : 'Awaiting confirmed states',
              ),
            ),
          ],
        ),
        SectionHeader(
          'Your appliances',
          action: d.devices.length > 3 ? 'View all ${d.devices.length}' : 'Manage',
          onAction: () => showAllDevicesSheet(
            context,
            scope: scope,
            roomId: widget.roomId,
            roomName: room.name,
          ),
        ),
        if (shown.isEmpty)
          const EmptyCard('No appliances added to this room yet.')
        else
          for (final dev in shown)
            DeviceRow(
              device: dev,
              hubOnline: online,
              onConfigure: () => showDeviceSheet(
                context,
                scope: scope,
                roomId: widget.roomId,
                roomName: room.name,
                deviceId: dev.id,
              ),
              onToggle: (on) => requestDevice(context, scope.repo, widget.roomId, dev, on),
              onRetry: () =>
                  requestDevice(context, scope.repo, widget.roomId, dev, dev.requestedState == 'on'),
            ),
        const SizedBox(height: 6),
        _savingsBanner(context, room, d),
      ],
    );
  }

  // ---- presence card -------------------------------------------------------

  Widget _presenceCard(
    BuildContext context,
    AppScope scope,
    RoomInfo room,
    HomeData d,
    RoomView view,
    int now,
  ) {
    final e = context.eco;
    final (String label, Tone tone) = switch (view.state) {
      RoomState.occupied => ('Occupied', Tone.good),
      RoomState.confirming => ('Confirming', Tone.warn),
      RoomState.vacant => ('Vacant', Tone.neutral),
      RoomState.offline => ('Offline', Tone.bad),
    };
    final Color dialColor = switch (view.state) {
      RoomState.occupied => e.accent,
      RoomState.confirming => e.amber,
      RoomState.vacant => e.slate,
      RoomState.offline => e.red,
    };
    final double? percent = view.online ? view.confidence : null;

    String head;
    String desc;
    switch (view.state) {
      case RoomState.occupied:
        head = 'Presence detected';
        desc = 'Your sensors report presence in this room.';
      case RoomState.confirming:
        head = 'Checking for vacancy';
        desc = 'No presence detected recently.';
      case RoomState.vacant:
        head = 'Room is vacant';
        desc = 'No presence detected after the grace period.';
      case RoomState.offline:
        if (d.status == null) {
          head = 'Waiting for hub';
          desc = 'No data from this room yet. Pair a hub to start monitoring.';
        } else {
          head = 'No live signal';
          desc = view.hubAgeSeconds == null
              ? 'The hub has not reported in yet.'
              : 'Last heard from the hub ${formatAge(view.hubAgeSeconds!)}. '
                  'Last known: ${view.lastKnownVacant ? 'vacant' : 'occupied'}.';
        }
    }

    final mm = d.mmwave;
    final door = d.door;
    final sensors = <(IconData, String, String)>[
      (
        Icons.radar,
        'mmWave',
        !view.online || mm == null ? '—' : (mm.presence ? 'Presence detected' : 'Clear'),
      ),
      (
        Icons.sensor_door_outlined,
        'Door',
        !view.online || door == null
            ? '—'
            : (door.state.isEmpty ? 'Unknown' : (door.isOpen ? 'Open' : 'Closed')),
      ),
      (Icons.wifi_rounded, 'Hub', view.online ? 'Online' : 'Offline'),
    ];

    return GlassCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Room intelligence', style: EcoText.cardTitle(e)),
              StatusBadge(label: label, tone: tone),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
            child: Row(
              children: [
                StatusDial(percent: percent, color: dialColor, size: 130),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT STATUS',
                        style: EcoText.kicker(e).copyWith(fontSize: 11, letterSpacing: 0.9),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        head,
                        style: EcoText.roomTitle(e).copyWith(fontSize: 20, height: 1.12),
                      ),
                      const SizedBox(height: 6),
                      Text(desc, style: EcoText.small(e)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: e.line),
          const SizedBox(height: 13),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sensors.length; i++)
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 10, right: 6),
                      decoration: BoxDecoration(
                        border: i < sensors.length - 1
                            ? Border(right: BorderSide(color: e.line))
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(sensors[i].$1, size: 12, color: e.ink2),
                              const SizedBox(width: 4),
                              Text(sensors[i].$2, style: EcoText.tiny(e).copyWith(fontSize: 10.5)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(sensors[i].$3, style: EcoText.strong(e, size: 13)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (view.online && (d.status?.suspect ?? false))
            const StateBanner(
              tone: Tone.warn,
              icon: Icons.warning_amber_rounded,
              child: Text('Unconfirmed presence (suspect reading: seen right after a door event).'),
            ),
          if (view.online && (d.status?.doorGateHold ?? false))
            const StateBanner(
              tone: Tone.neutral,
              icon: Icons.lock_outline_rounded,
              child: Text('Holding: the door has not moved.'),
            ),
          _stateBanner(context, scope, room, d, view, now),
        ],
      ),
    );
  }

  Widget _stateBanner(
    BuildContext context,
    AppScope scope,
    RoomInfo room,
    HomeData d,
    RoomView view,
    int now,
  ) {
    final e = context.eco;
    // Offline wins over everything.
    if (!view.online) {
      return StateBanner(
        tone: Tone.bad,
        icon: Icons.error_outline_rounded,
        child: Text(
          view.hubAgeSeconds == null
              ? 'Hub is offline. Switching is disabled until it reconnects.'
              : 'Hub is offline. Last update ${formatAge(view.hubAgeSeconds!)}. '
                  'Switching is disabled until it reconnects.',
        ),
      );
    }
    // Temporary "keep power on" override.
    if (room.isPausedAt(now)) {
      final until = DateTime.fromMillisecondsSinceEpoch(room.pauseUntil * 1000);
      return StateBanner(
        tone: Tone.warn,
        icon: Icons.info_outline_rounded,
        actions: [SmallButton(label: 'Resume automation', onPressed: () => _resume(scope))],
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Automatic shutoff paused until '),
              TextSpan(
                text: formatClock(until),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
      );
    }

    final eligibleOn = d.devices
        .where((x) => x.eligible && x.isOn && x.phase(now) == CommandPhase.idle)
        .toList();

    switch (view.state) {
      case RoomState.confirming:
        final remaining = (view.confidence / 100 * d.graceSeconds).ceil();
        final String next;
        if (d.mode == AutomationMode.manual) {
          next = 'Manual mode keeps all appliances powered as they are.';
        } else if (eligibleOn.isEmpty) {
          next = 'No confirmed-on appliances are eligible for shutoff.';
        } else {
          next = 'EcoSense will switch off ${eligibleOn.map((x) => x.name).join(', ')} '
              'if the room stays empty.';
        }
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 15),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: e.amberSoft,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: e.amber),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estimated time remaining', style: EcoText.strong(e, size: 14)),
              const SizedBox(height: 4),
              Text(formatCountdown(remaining),
                  style: EcoText.bigNumber(e, size: 30).copyWith(color: e.warnInk)),
              const SizedBox(height: 6),
              Text(next, style: EcoText.body(e).copyWith(fontSize: 14)),
              if (eligibleOn.isNotEmpty && d.mode == AutomationMode.auto) ...[
                const SizedBox(height: 10),
                SmallButton(
                  label: 'Keep power on for $kPauseMinutes min',
                  dark: true,
                  onPressed: () => _pause(scope),
                ),
              ],
            ],
          ),
        );
      case RoomState.vacant:
        final off = d.devices.where((x) => x.eligible && x.switchedOffByAutomation).toList();
        return StateBanner(
          tone: Tone.good,
          icon: Icons.shield_outlined,
          actions: [
            if (off.isNotEmpty)
              SmallButton(
                label: 'Restore ${off.length}',
                onPressed: () => showRestoreSheet(
                  context,
                  scope: scope,
                  roomId: widget.roomId,
                  roomName: room.name,
                  devices: off,
                ),
              ),
          ],
          child: Text(
            off.isNotEmpty
                ? '${off.length} opted-in appliance${off.length == 1 ? ' was' : 's were'} '
                    'switched off after vacancy confirmation.'
                : (d.mode == AutomationMode.manual
                    ? 'Manual mode: no appliances are switched automatically.'
                    : 'The room is vacant. No appliances needed switching off.'),
          ),
        );
      default:
        return StateBanner(
          tone: Tone.good,
          icon: Icons.shield_outlined,
          child: Text(
            'Live monitoring is active. Automation will only control opted-in appliances.',
            style: TextStyle(color: e.greenInk),
          ),
        );
    }
  }

  // ---- savings + details ---------------------------------------------------

  Widget _savingsBanner(BuildContext context, RoomInfo room, HomeData d) {
    final saved = d.today.savedKwh;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F7A4D), Color(0xFF3DAE70)],
        ),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${room.name.toUpperCase()} SAVINGS TODAY',
                  style: EcoText.kicker(context.eco).copyWith(
                    color: const Color(0xFFD8F4E4),
                    fontSize: 10,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  peso(saved * d.rate),
                  style: EcoText.bigNumber(context.eco, size: 28).copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatKwh(saved)} kWh · estimate for ${room.name}',
                  style: EcoText.tiny(context.eco).copyWith(color: const Color(0xFFD8F4E4)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'See today’s energy insights',
            onPressed: widget.onOpenInsightsToday,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.19),
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
              ),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 19),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.number,
    required this.unit,
    required this.foot,
  });

  final IconData icon;
  final String label;
  final String number;
  final String unit;
  final String foot;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: e.ink2),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label, style: EcoText.label(e), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text.rich(
            TextSpan(
              text: number,
              style: EcoText.bigNumber(e, size: 26),
              children: [
                TextSpan(text: unit, style: EcoText.small(e).copyWith(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(foot, style: EcoText.tiny(e)),
        ],
      ),
    );
  }
}
