import 'dart:async';

import '../models/device.dart';
import '../models/log_entry.dart';
import '../models/presence_status.dart';
import '../models/room_view.dart';
import '../services/data_repository.dart';

/// Emits whenever [a] or [b] emits, once both have emitted at least once.
/// Built with Stream.multi, so it can be listened to again (a widget that is
/// rebuilt or re-attached no longer throws "Stream has already been listened to").
Stream<R> combine2<A, B, R>(Stream<A> a, Stream<B> b, R Function(A, B) f) =>
    Stream<R>.multi((ctrl) {
      A? la;
      B? lb;
      var ha = false;
      var hb = false;
      void emit() {
        if (ha && hb) ctrl.add(f(la as A, lb as B));
      }

      final sa = a.listen((v) {
        la = v;
        ha = true;
        emit();
      }, onError: ctrl.addError);
      final sb = b.listen((v) {
        lb = v;
        hb = true;
        emit();
      }, onError: ctrl.addError);
      ctrl.onCancel = () async {
        await sa.cancel();
        await sb.cancel();
      };
    });

/// Emits the latest value of every stream, once each has emitted.
/// Re-listenable, like [combine2].
Stream<List<T>> combineList<T>(List<Stream<T>> streams) {
  if (streams.isEmpty) return Stream<List<T>>.value(<T>[]);
  return Stream<List<T>>.multi((ctrl) {
    final values = List<T?>.filled(streams.length, null);
    final has = List<bool>.filled(streams.length, false);
    final subs = <StreamSubscription<T>>[];
    for (var i = 0; i < streams.length; i++) {
      subs.add(streams[i].listen((v) {
        values[i] = v;
        has[i] = true;
        if (has.every((h) => h)) {
          ctrl.add(List<T>.generate(values.length, (j) => values[j] as T));
        }
      }, onError: ctrl.addError));
    }
    ctrl.onCancel = () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    };
  });
}

/// Status + devices of one room.
Stream<RoomLive> roomLiveStream(DataRepository repo, String roomId) =>
    combine2<PresenceStatus?, List<Device>, RoomLive>(
      repo.presenceStatus(roomId),
      repo.devices(roomId),
      (s, d) => RoomLive(status: s, devices: d),
    );

/// Status + devices of several rooms, keyed by room id.
Stream<Map<String, RoomLive>> roomsLiveStream(DataRepository repo, List<String> ids) =>
    combineList<RoomLive>(ids.map((id) => roomLiveStream(repo, id)).toList())
        .map((list) => {for (var i = 0; i < ids.length; i++) ids[i]: list[i]});

/// Newest-first logs of several rooms merged into one list.
Stream<List<LogEntry>> mergedLogs(DataRepository repo, List<String> ids, {int? limit}) =>
    combineList<List<LogEntry>>(ids.map(repo.recentLogs).toList()).map((lists) {
      final all = <LogEntry>[for (final l in lists) ...l]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return limit != null && all.length > limit ? all.sublist(0, limit) : all;
    });

