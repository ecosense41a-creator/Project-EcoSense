import 'package:flutter/material.dart';

import '../models/device.dart';
import '../services/data_repository.dart';
import '../widgets/eco_sheet.dart';

/// Sends a switch request. The hub applies it and updates the device; the UI
/// shows "Switching…" until then and "unconfirmed + Retry" after a timeout.
Future<void> requestDevice(
  BuildContext context,
  DataRepository repo,
  String roomId,
  Device d,
  bool on,
) async {
  try {
    await repo.requestDeviceState(roomId, d.id, on ? 'on' : 'off');
  } catch (e) {
    if (context.mounted) showEcoToast(context, 'Command not sent: $e');
  }
}
