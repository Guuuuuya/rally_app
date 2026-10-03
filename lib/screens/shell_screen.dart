import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db.dart';
import '../tracker.dart';
import 'home_screen.dart';
import 'join_screen.dart';
import 'leaderboard_screen.dart';
import 'map_screen.dart';

/// Bottom-nav shell: Home (stats) / Group / Stage / Ranks — like the Figma design.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          _GroupTab(),
          _StageTab(),
          _RanksTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Group'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Stage'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Ranks'),
        ],
      ),
    );
  }
}

class _GroupTab extends StatelessWidget {
  const _GroupTab();

  @override
  Widget build(BuildContext context) => const JoinScreen();
}

class _StageTab extends StatelessWidget {
  const _StageTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: context.watch<Db>().myGroupId(),
      builder: (context, snap) {
        final groupId = snap.data;
        if (groupId == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Stage')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Join or create a group first, then the live stage map appears here.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return MapScreen(groupId: groupId);
      },
    );
  }
}

class _RanksTab extends StatelessWidget {
  const _RanksTab();

  @override
  Widget build(BuildContext context) {
    final sessionId = context.watch<Tracker>().sessionId;
    if (sessionId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leaderboard')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Start a stage and the live leaderboard will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    return LeaderboardScreen(sessionId: sessionId);
  }
}
