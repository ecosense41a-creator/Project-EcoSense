import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/data_repository.dart';
import 'logs_tab.dart';
import 'sensors_tab.dart';
import 'status_tab.dart';

/// The signed-in screen: three tabs plus logout and settings.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.auth,
    required this.repo,
    required this.username,
  });

  final AuthService auth;
  final DataRepository repo;
  final String username;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _titles = ['Presence status', 'Sensor data', 'Event history'];
  int _index = 0;

  Future<void> _openSettings(BuildContext context) async {
    final currentVal = await widget.repo.sustainedThresholdSeconds().first ?? 30;
    final controller = TextEditingController(text: currentVal.toString());

    if (!context.mounted) return;
    final ok = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin Config'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sustained threshold (grace period) in seconds (10 - 3600):'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Seconds',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text);
              if (parsed != null && parsed >= 10 && parsed <= 3600) {
                Navigator.pop(ctx, parsed);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a value between 10 and 3600')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != null) {
      await widget.repo.setSustainedThresholdSeconds(ok);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sustained threshold updated to $ok s')),
        );
      }
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          Center(
            child: Text(
              widget.username,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            tooltip: 'Admin config',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      // IndexedStack keeps every tab alive, so streams stay connected and
      // switching tabs is instant.
      body: IndexedStack(
        index: _index,
        children: [
          StatusTab(repo: widget.repo),
          SensorsTab(repo: widget.repo),
          LogsTab(repo: widget.repo),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Status',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors),
            label: 'Sensors',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
