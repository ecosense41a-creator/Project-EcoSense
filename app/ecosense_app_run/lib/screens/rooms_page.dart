import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/device.dart';
import '../models/room.dart';
import '../models/room_view.dart';
import '../sheets/room_sheets.dart';
import '../theme/eco_theme.dart';
import '../utils/stream_utils.dart';
import '../widgets/common.dart';
import '../widgets/eco_icons.dart';
import '../widgets/eco_widgets.dart';
import '../widgets/glass_card.dart';
import 'dart:ui' show PathMetric;

/// Occupancy, connectivity and power per room.
class RoomsPage extends StatefulWidget {
  const RoomsPage({
    super.key,
    required this.rooms,
    required this.selectedId,
    required this.onSelectRoom,
  });

  final List<RoomInfo> rooms;
  final String selectedId;
  final ValueChanged<String> onSelectRoom;

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  Stream<Map<String, RoomLive>>? _stream;
  String _key = '';
  Object? _repo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(RoomsPage old) {
    super.didUpdateWidget(old);
    _bind();
  }

  void _bind() {
    final repo = AppScope.of(context).repo;
    final key = widget.rooms.map((r) => r.id).join('|');
    if (_stream == null || key != _key || !identical(_repo, repo)) {
      _key = key;
      _repo = repo;
      _stream = roomsLiveStream(repo, widget.rooms.map((r) => r.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final scope = AppScope.of(context);
    return StreamBuilder<Map<String, RoomLive>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return MessageView(
            icon: Icons.cloud_off,
            isError: true,
            message: 'Could not load rooms.\n${snap.error}',
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final live = snap.data!;
        return TickBuilder(
          builder: (context) {
            final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            final views = <String, RoomView>{
              for (final r in widget.rooms)
                r.id: roomViewOf(live[r.id]?.status, scope.serverOffsetMs),
            };
            bool settled(String id) =>
                !(live[id]?.devices.any((d) => d.phase(now) == CommandPhase.unconfirmed) ?? false);
            final occupied = views.values
                .where((v) => v.state == RoomState.occupied || v.state == RoomState.confirming)
                .length;
            final hubs = views.values.where((v) => v.online).length;
            final total = widget.rooms
                .where((r) => views[r.id]!.online && settled(r.id))
                .fold<double>(0, (a, r) => a + (live[r.id]?.totalWatts() ?? 0));
            final n = widget.rooms.length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(19, 4, 19, 128),
              children: [
                const SizedBox(height: 10),
                Text('Your rooms', style: EcoText.pageTitle(e)),
                const SizedBox(height: 6),
                Text('Occupancy, connectivity, and power by room.', style: EcoText.pageSub(e)),
                const SizedBox(height: 19),
                Row(
                  children: [
                    Expanded(child: _Summary('Occupied', '$occupied', '/$n')),
                    const SizedBox(width: 8),
                    Expanded(child: _Summary('Hubs online', '$hubs', '/$n')),
                    const SizedBox(width: 8),
                    Expanded(child: _Summary('Total draw*', '${total.round()}', ' W')),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
                  child: Text(
                    '*Includes online rooms with confirmed appliance states.',
                    style: EcoText.tiny(e),
                  ),
                ),
                for (final r in widget.rooms)
                  _roomCard(context, r, live[r.id], views[r.id]!, now),
                const SizedBox(height: 2),
                _DashedButton(
                  label: 'Add a room',
                  onTap: () => showAddRoomSheet(
                    context,
                    scope: scope,
                    rooms: widget.rooms,
                    onCreated: (_) {},
                  ),
                ),
                const SizedBox(height: 14),
                const HelpNote(
                  'Select a room to view controls. Appliances in an offline room cannot be switched remotely.',
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _roomCard(BuildContext context, RoomInfo r, RoomLive? live, RoomView v, int now) {
    final e = context.eco;
    final label = switch (v.state) {
      RoomState.occupied => 'Occupied',
      RoomState.confirming => 'Confirming vacancy',
      RoomState.vacant => 'Vacant',
      RoomState.offline => 'Offline',
    };
    final devices = live?.devices ?? const <Device>[];
    final power = v.online && !devices.any((d) => d.phase(now) == CommandPhase.unconfirmed)
        ? '${live!.totalWatts().round()} W'
        : '—';
    final selected = r.id == widget.selectedId;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      borderColor: selected ? e.accent : null,
      onTap: () => widget.onSelectRoom(r.id),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: e.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(roomIconFor(r.name), size: 21, color: e.accentDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoText.strong(e, size: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  '$label · ${v.online ? 'Hub online' : 'No connection'}',
                  style: EcoText.tiny(e).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(power, style: EcoText.strong(e, size: 15)),
              const SizedBox(height: 3),
              Text('${devices.length} appliances', style: EcoText.tiny(e)),
            ],
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, size: 16, color: e.ink2),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.label, this.value, this.suffix);

  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return GlassCard(
      radius: 17,
      padding: const EdgeInsets.fromLTRB(10, 13, 10, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: EcoText.tiny(e).copyWith(fontSize: 10.5)),
          const SizedBox(height: 7),
          Text.rich(
            TextSpan(
              text: value,
              style: EcoText.bigNumber(e, size: 20).copyWith(fontWeight: FontWeight.w600),
              children: [TextSpan(text: suffix, style: EcoText.tiny(e))],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedButton extends StatelessWidget {
  const _DashedButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedPainter(color: e.accent, fill: e.surface),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 17, color: e.accentDeep),
              const SizedBox(width: 8),
              Text(label, style: EcoText.button(e.accentDeep)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter({required this.color, required this.fill});

  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    canvas.drawRRect(rrect, Paint()..color = fill);
    final path = Path()..addRRect(rrect.deflate(0.5));
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final PathMetric m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 5), stroke);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color || old.fill != fill;
}
