import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db.dart';

/// Post-drive leaderboard: distance, top speed, avg pace per member.
class LeaderboardScreen extends StatelessWidget {
  final String sessionId;
  const LeaderboardScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context.watch<Db>().sessionBoard(sessionId),
        builder: (context, snap) {
          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final medal = switch (i) {
                0 => '🥇',
                1 => '🥈',
                2 => '🥉',
                _ => '#${i + 1}',
              };
              return ListTile(
                leading: Text(medal),
                title: Text(r['uid'] as String),
                subtitle: Text(
                  'avg ${(r['avgSpeedKmh'] as num).toStringAsFixed(1)} km/h · '
                  'top ${(r['topSpeedKmh'] as num).toStringAsFixed(1)} km/h',
                ),
                trailing: Text(
                  '${((r['distanceM'] as num) / 1000).toStringAsFixed(2)} km',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
