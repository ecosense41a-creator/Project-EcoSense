import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../config.dart';
import '../models/log_entry.dart';
import '../models/room.dart';
import '../theme/eco_theme.dart';
import '../utils/format.dart';
import '../utils/stream_utils.dart';
import '../widgets/common.dart';
import '../widgets/eco_widgets.dart';

/// Event history across rooms (replaces the old History tab).
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key, required this.rooms});

  final List<RoomInfo> rooms;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  String _roomFilter = ''; // '' = all rooms
  LogCategory? _category; // null = all
  Stream<List<LogEntry>>? _stream;
  String _key = '';
  Object? _repo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(ActivityPage old) {
    super.didUpdateWidget(old);
    _bind();
  }

  void _bind() {
    final repo = AppScope.of(context).repo;
    final exists = _roomFilter.isEmpty || widget.rooms.any((r) => r.id == _roomFilter);
    if (!exists) _roomFilter = '';
    final ids = _roomFilter.isEmpty ? widget.rooms.map((r) => r.id).toList() : [_roomFilter];
    final key = ids.join('|');
    if (_stream == null || key != _key || !identical(_repo, repo)) {
      _key = key;
      _repo = repo;
      _stream = mergedLogs(repo, ids);
    }
  }

  String _roomName(String id) {
    for (final r in widget.rooms) {
      if (r.id == id) return r.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final roomLabel = _roomFilter.isEmpty ? 'Activity across your rooms' : '${_roomName(_roomFilter)} activity';
    return ListView(
      padding: const EdgeInsets.fromLTRB(19, 4, 19, 128),
      children: [
        const SizedBox(height: 10),
        Text('Activity', style: EcoText.pageTitle(e)),
        const SizedBox(height: 6),
        Text('$roomLabel, with a reason and a time.', style: EcoText.pageSub(e)),
        const SizedBox(height: 19),
        if (widget.rooms.length > 1) ...[
          DropdownButtonFormField<String>(
            initialValue: _roomFilter,
            isExpanded: true,
            dropdownColor: e.solid,
            borderRadius: BorderRadius.circular(15),
            decoration: ecoFieldDecoration(context, label: 'Room'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All rooms')),
              for (final r in widget.rooms) DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged: (v) => setState(() {
              _roomFilter = v ?? '';
              _bind();
            }),
          ),
          const SizedBox(height: 12),
        ],
        FilterChips<LogCategory?>(
          options: const [
            (null, 'All'),
            (LogCategory.presence, 'Presence'),
            (LogCategory.appliance, 'Appliances'),
            (LogCategory.alert, 'Alerts'),
          ],
          value: _category,
          onChanged: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: 6),
        StreamBuilder<List<LogEntry>>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return MessageView(
                icon: Icons.cloud_off,
                isError: true,
                message: 'Could not load the event history.\n${snap.error}',
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final all = snap.data!;
            final shown = all.where((l) => _category == null || l.category == _category).toList();
            if (all.isEmpty) {
              return const EmptyCard('No events yet.\nChanges in room occupancy will appear here.');
            }
            if (shown.isEmpty) return const EmptyCard('No activity matches this filter.');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text(
                    'Latest ${shown.length} events (up to $kLogLimit per room)',
                    style: EcoText.tiny(e),
                  ),
                ),
                for (final l in shown) _EventTile(entry: l, roomName: _roomName(l.roomId)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.entry, required this.roomName});

  final LogEntry entry;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final isError = entry.type == 'error' || entry.severity == 'error';
    final isAlert = entry.category == LogCategory.alert;
    final (Color bg, Color fg) = isError
        ? (e.redSoft, e.red)
        : isAlert
            ? (e.amberSoft, e.amber)
            : (e.accentSoft, e.accentDeep);
    final IconData icon = switch (entry.category) {
      LogCategory.presence => entry.isVacantEvent ? Icons.person_off_outlined : Icons.radar,
      LogCategory.alert => isError ? Icons.close_rounded : Icons.warning_amber_rounded,
      LogCategory.appliance => Icons.bolt_rounded,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, size: 17, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 2, 0, 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: e.line))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: EcoText.strong(e, size: 13.5)),
                  if (entry.detail.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(entry.detail, style: EcoText.small(e)),
                  ],
                  const SizedBox(height: 5),
                  Text('$roomName · ${formatEventTime(entry.timestamp)}', style: EcoText.tiny(e)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
