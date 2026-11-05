import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../models/log_entry.dart';
import '../models/room.dart';
import '../theme/eco_theme.dart';
import '../utils/format.dart';
import '../utils/stream_utils.dart';
import '../widgets/eco_icons.dart';
import '../widgets/eco_sheet.dart';
import '../widgets/eco_widgets.dart';
import '../widgets/glass_card.dart';

// ---- Add a room -------------------------------------------------------------

Future<void> showAddRoomSheet(
  BuildContext context, {
  required AppScope scope,
  required List<RoomInfo> rooms,
  required ValueChanged<String> onCreated,
}) {
  return showEcoSheet<void>(
    context,
    title: 'Add a room',
    subtitle: 'Each room gets its own hub, sensors and appliances.',
    builder: (_) => _AddRoomBody(scope: scope, rooms: rooms, onCreated: onCreated),
  );
}

class _AddRoomBody extends StatefulWidget {
  const _AddRoomBody({required this.scope, required this.rooms, required this.onCreated});

  final AppScope scope;
  final List<RoomInfo> rooms;
  final ValueChanged<String> onCreated;

  @override
  State<_AddRoomBody> createState() => _AddRoomBodyState();
}

class _AddRoomBodyState extends State<_AddRoomBody> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final name = _name.text.trim();
    final nav = Navigator.of(context);
    final messenger = context;
    try {
      final id = await widget.scope.repo.addRoom(name);
      nav.pop();
      widget.onCreated(id);
      if (messenger.mounted) showEcoToast(messenger, '$name added');
    } catch (err) {
      if (mounted) {
        setState(() => _busy = false);
        showEcoToast(context, 'Could not add the room: $err');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            autofocus: true,
            maxLength: 32,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
            decoration: ecoFieldDecoration(
              context,
              label: 'Room name',
              hint: 'e.g. Bedroom, Kitchen',
            ),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Enter a room name';
              if (widget.rooms.any((r) => r.name.toLowerCase() == t.toLowerCase())) {
                return 'A room with this name already exists';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          const HelpNote(
            'The room shows as offline until its hub is paired and starts reporting.',
          ),
          const SizedBox(height: 14),
          EcoButton(label: 'Add room', filled: true, loading: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

// ---- Add an appliance -------------------------------------------------------

Future<void> showAddDeviceSheet(
  BuildContext context, {
  required AppScope scope,
  required String roomId,
  required String roomName,
}) {
  return showEcoSheet<void>(
    context,
    title: 'Add an appliance',
    subtitle: roomName,
    builder: (_) => _AddDeviceBody(scope: scope, roomId: roomId),
  );
}

class _AddDeviceBody extends StatefulWidget {
  const _AddDeviceBody({required this.scope, required this.roomId});

  final AppScope scope;
  final String roomId;

  @override
  State<_AddDeviceBody> createState() => _AddDeviceBodyState();
}

class _AddDeviceBodyState extends State<_AddDeviceBody> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _watts = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _watts.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final name = _name.text.trim();
    final watts = double.parse(_watts.text.trim());
    final nav = Navigator.of(context);
    final ctx = context;
    try {
      await widget.scope.repo.addDevice(widget.roomId, name, watts);
      await widget.scope.repo.addLog(
        widget.roomId,
        type: 'manual',
        title: '$name added',
        detail: 'Appliance added by ${widget.scope.username}. Pair its smart plug to control it.',
      );
      nav.pop();
      if (ctx.mounted) showEcoToast(ctx, '$name added');
    } catch (err) {
      if (mounted) {
        setState(() => _busy = false);
        showEcoToast(context, 'Could not add the appliance: $err');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: ecoFieldDecoration(
              context,
              label: 'Appliance name',
              hint: 'e.g. Air conditioner',
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter an appliance name' : null,
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _watts,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}(\.\d{0,1})?$'))],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
            decoration: ecoFieldDecoration(
              context,
              label: 'Rated power (watts)',
              hint: 'Printed on the appliance label',
              suffix: const Padding(
                padding: EdgeInsets.only(right: 14),
                child: Text('W'),
              ),
            ),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n < 1 || n > 5000) return 'Enter a value from 1 to 5000 W';
              return null;
            },
          ),
          const SizedBox(height: 14),
          EcoButton(label: 'Add appliance', filled: true, loading: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

// ---- Choose room ------------------------------------------------------------

Future<void> showChooseRoomSheet(
  BuildContext context, {
  required AppScope scope,
  required List<RoomInfo> rooms,
  required String selectedId,
  required ValueChanged<String> onSelect,
  required ValueChanged<String> onCreated,
}) {
  return showEcoSheet<void>(
    context,
    title: 'Choose a room',
    subtitle: 'Switch which room you are viewing.',
    builder: (sheetContext) {
      final e = sheetContext.eco;
      return Column(
        children: [
          for (final r in rooms)
            GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              radius: 15,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              fill: r.id == selectedId ? e.accentSoft : null,
              borderColor: r.id == selectedId ? e.accent : null,
              onTap: () {
                Navigator.of(sheetContext).pop();
                onSelect(r.id);
              },
              child: Row(
                children: [
                  Icon(roomIconFor(r.name), size: 20, color: e.accentDeep),
                  const SizedBox(width: 12),
                  Expanded(child: Text(r.name, style: EcoText.strong(e, size: 14))),
                  if (r.id == selectedId) Icon(Icons.check_rounded, size: 18, color: e.accentDeep),
                ],
              ),
            ),
          const SizedBox(height: 4),
          EcoButton(
            label: 'Add a room',
            icon: Icons.add_rounded,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              showAddRoomSheet(context, scope: scope, rooms: rooms, onCreated: onCreated);
            },
          ),
        ],
      );
    },
  );
}

// ---- Notifications ----------------------------------------------------------

Future<void> showNotificationsSheet(
  BuildContext context, {
  required AppScope scope,
  required List<RoomInfo> rooms,
}) {
  scope.repo.markNotificationsRead(scope.uid);
  return showEcoSheet<void>(
    context,
    title: 'Notifications',
    subtitle: 'Important changes in your home',
    builder: (_) => _NotificationsBody(scope: scope, rooms: rooms),
  );
}

class _NotificationsBody extends StatefulWidget {
  const _NotificationsBody({required this.scope, required this.rooms});

  final AppScope scope;
  final List<RoomInfo> rooms;

  @override
  State<_NotificationsBody> createState() => _NotificationsBodyState();
}

class _NotificationsBodyState extends State<_NotificationsBody> {
  late final Stream<List<LogEntry>> _stream = mergedLogs(
    widget.scope.repo,
    widget.rooms.map((r) => r.id).toList(),
    limit: 20,
  );

  String _roomName(String id) {
    for (final r in widget.rooms) {
      if (r.id == id) return r.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    return StreamBuilder<List<LogEntry>>(
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final items = snap.data!;
        if (items.isEmpty) return const EmptyCard('Nothing new. Changes will appear here.');
        return Column(
          children: [
            for (final l in items)
              GlassCard(
                margin: const EdgeInsets.only(bottom: 8),
                radius: 15,
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      l.category == LogCategory.alert
                          ? Icons.warning_amber_rounded
                          : Icons.notifications_none_rounded,
                      size: 18,
                      color: l.category == LogCategory.alert ? e.amber : e.accentDeep,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.title, style: EcoText.strong(e, size: 13.5)),
                          if (l.detail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(l.detail, style: EcoText.small(e)),
                          ],
                          const SizedBox(height: 3),
                          Text(
                            '${_roomName(l.roomId)} · ${formatEventTime(l.timestamp)}',
                            style: EcoText.tiny(e),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
