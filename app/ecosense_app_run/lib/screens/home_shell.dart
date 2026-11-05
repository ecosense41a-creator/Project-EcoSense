import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../config.dart';
import '../models/device.dart';
import '../models/energy.dart';
import '../models/log_entry.dart';
import '../models/room.dart';
import '../services/auth_service.dart';
import '../services/data_repository.dart';
import '../sheets/room_sheets.dart';
import '../theme/eco_theme.dart';
import '../theme/theme_controller.dart';
import '../utils/stream_utils.dart';
import '../widgets/eco_background.dart';
import '../widgets/eco_nav_bar.dart';
import '../widgets/eco_widgets.dart';
import 'activity_page.dart';
import 'home_page.dart';
import 'insights_page.dart';
import 'rooms_page.dart';
import 'settings_page.dart';

/// The signed-in screen: header + 5 pages + floating navigation.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.auth,
    required this.repo,
    required this.username,
    required this.theme,
  });

  final AuthService auth;
  final DataRepository repo;
  final String username;
  final ThemeController theme;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _items = [
    EcoNavItem(Icons.home_outlined, 'Home'),
    EcoNavItem(Icons.grid_view_rounded, 'Rooms'),
    EcoNavItem(Icons.bar_chart_rounded, 'Insights'),
    EcoNavItem(Icons.schedule_rounded, 'Activity'),
    EcoNavItem(Icons.settings_outlined, 'Settings'),
  ];

  int _tab = 0;
  String _roomId = kPrimaryRoomId;
  EnergyRange _range = EnergyRange.week;
  List<RoomInfo> _rooms = [RoomInfo.primaryDefault()];
  int _serverOffsetMs = 0;

  StreamSubscription<List<RoomInfo>>? _roomsSub;
  StreamSubscription<String?>? _themeSub;

  // One listener per room that feeds the appliances' energy counters into the
  // /energy history (see kEnergySyncInApp).
  final Map<String, StreamSubscription<List<Device>>> _energySubs = {};

  // Bell dot: any log newer than the last time notifications were opened.
  Stream<bool>? _unread;
  String _unreadKey = '';

  final GlobalKey _rateKey = GlobalKey();
  final ValueNotifier<bool> _rateEmphasis = ValueNotifier<bool>(false);

  String get _uid => widget.auth.currentUid ?? widget.username;

  @override
  void initState() {
    super.initState();
    widget.repo.serverTimeOffsetMs().then((o) {
      if (mounted) setState(() => _serverOffsetMs = o);
    });
    _roomsSub = widget.repo.rooms().listen((rooms) {
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        if (!rooms.any((r) => r.id == _roomId)) _roomId = kPrimaryRoomId;
        _bindUnread();
      });
      _bindEnergySync(rooms);
    });
    _bindUnread();
    // Theme saved on the account wins over the phone's cached value.
    _themeSub = widget.repo.themePreference(_uid).listen((v) {
      if (v != null) widget.theme.set(v);
    });
  }

  void _bindEnergySync(List<RoomInfo> rooms) {
    if (!kEnergySyncInApp) return;
    final ids = rooms.map((r) => r.id).toSet();
    for (final id in _energySubs.keys.where((k) => !ids.contains(k)).toList()) {
      _energySubs.remove(id)?.cancel();
    }
    for (final id in ids) {
      _energySubs.putIfAbsent(
        id,
        () => widget.repo.devices(id).listen(
              (list) => widget.repo.syncEnergy(id, list),
              onError: (Object _) {},
            ),
      );
    }
  }

  void _bindUnread() {
    final ids = _rooms.map((r) => r.id).toList();
    final key = ids.join('|');
    if (_unread != null && key == _unreadKey) return;
    _unreadKey = key;
    _unread = combine2<List<LogEntry>, int, bool>(
      mergedLogs(widget.repo, ids, limit: 20),
      widget.repo.notificationsLastRead(_uid),
      (logs, lastRead) => logs.any((l) => l.timestamp > lastRead),
    );
  }

  @override
  void dispose() {
    _roomsSub?.cancel();
    _themeSub?.cancel();
    for (final sub in _energySubs.values) {
      sub.cancel();
    }
    _rateEmphasis.dispose();
    super.dispose();
  }

  void _selectRoom(String id) => setState(() {
        _roomId = id;
        _tab = 0;
      });

  void _editRate() {
    setState(() => _tab = 4);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _rateKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.05,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
      _rateEmphasis.value = true;
      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) _rateEmphasis.value = false;
      });
    });
  }

  String get _roomName => _rooms
      .firstWhere(
        (r) => r.id == _roomId,
        orElse: () => RoomInfo.primaryDefault(),
      )
      .name;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return AppScope(
      auth: widget.auth,
      repo: widget.repo,
      username: widget.username,
      uid: _uid,
      serverOffsetMs: _serverOffsetMs,
      theme: widget.theme,
      child: Builder(
        builder: (context) {
          final scope = AppScope.of(context);
          return EcoBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _header(context, scope),
                        Expanded(
                          // IndexedStack keeps every page alive, so streams stay
                          // connected and switching pages is instant.
                          child: IndexedStack(
                            index: _tab,
                            children: [
                              HomePage(
                                roomId: _roomId,
                                rooms: _rooms,
                                onSelectRoom: _selectRoom,
                                onOpenInsightsToday: () => setState(() {
                                  _range = EnergyRange.day;
                                  _tab = 2;
                                }),
                              ),
                              RoomsPage(
                                rooms: _rooms,
                                selectedId: _roomId,
                                onSelectRoom: _selectRoom,
                              ),
                              InsightsPage(
                                roomId: _roomId,
                                roomName: _roomName,
                                range: _range,
                                onRangeChanged: (r) => setState(() => _range = r),
                                onEditRate: _editRate,
                              ),
                              ActivityPage(rooms: _rooms),
                              SettingsPage(
                                rateSectionKey: _rateKey,
                                rateEmphasis: _rateEmphasis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 14 + bottom,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: EcoNavBar(
                              items: _items,
                              selected: _tab,
                              onSelected: (i) => setState(() => _tab = i),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, AppScope scope) {
    final e = context.eco;
    return Padding(
      padding: const EdgeInsets.fromLTRB(19, 8, 19, 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.asset('assets/icon/ecosense_logo.png', width: 34, height: 34),
          ),
          const SizedBox(width: 9),
          Text('EcoSense', style: EcoText.section(e).copyWith(fontSize: 21, letterSpacing: -0.5)),
          const Spacer(),
          StreamBuilder<bool>(
            stream: _unread,
            builder: (context, snap) => EcoIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              dot: snap.data ?? false,
              onPressed: () => showNotificationsSheet(context, scope: scope, rooms: _rooms),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _tab = 4),
            child: Tooltip(
              message: 'Settings',
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: e.accent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  initialsOf(scope.username),
                  style: EcoText.button(e.onAccent).copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
