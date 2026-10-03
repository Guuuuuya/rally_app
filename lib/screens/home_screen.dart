import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db.dart';
import 'join_screen.dart';
import 'map_screen.dart';

/// Personal dashboard: the user's stats first, group access secondary.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<Db>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RallyTrack'),
        actions: [
          StreamBuilder<String?>(
            stream: db.myGroupId(),
            builder: (context, snap) {
              final groupId = snap.data;
              return IconButton(
                tooltip: groupId == null ? 'Create or join group' : 'Stage map',
                icon: const Icon(Icons.group),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => groupId == null
                          ? const JoinScreen()
                          : MapScreen(groupId: groupId),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.myTracks(),
        builder: (context, snap) {
          final tracks = snap.data ?? const [];
          final totalKm = tracks.fold<double>(
              0, (s, t) => s + ((t['distanceM'] as num?)?.toDouble() ?? 0)) / 1000;
          final topKmh = tracks.fold<double>(
              0, (m, t) => ((t['topSpeedKmh'] as num?)?.toDouble() ?? 0) > m
                  ? (t['topSpeedKmh'] as num).toDouble()
                  : m);
          final totalSec = tracks.fold<int>(
              0, (s, t) => s + ((t['durationSec'] as num?)?.toInt() ?? 0));
          double avgKmh = 0;
          if (totalSec > 0) {
            avgKmh = tracks.fold<double>(
                    0, (s, t) => s + ((t['distanceM'] as num?)?.toDouble() ?? 0)) /
                1000 /
                (totalSec / 3600);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StreamBuilder<DocumentSnapshot<Object?>>(
                stream: db.myProfile(),
                builder: (context, p) {
                  final name = (p.data?.data() as Map?)?['displayName']
                          as String? ??
                      'Driver';
                  return Text(
                    'Hey, $name 👋',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                tracks.isEmpty
                    ? 'No stages logged yet — hit the road!'
                    : 'Your lifetime stats',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatCard(
                    icon: Icons.route,
                    value: totalKm.toStringAsFixed(1),
                    unit: 'km total',
                  ),
                  _StatCard(
                    icon: Icons.speed,
                    value: topKmh.toStringAsFixed(0),
                    unit: 'km/h top speed',
                  ),
                  _StatCard(
                    icon: Icons.timer_outlined,
                    value: tracks.length.toString(),
                    unit: 'stages',
                  ),
                  _StatCard(
                    icon: Icons.show_chart,
                    value: avgKmh.toStringAsFixed(1),
                    unit: 'km/h average',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Recent drives',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  StreamBuilder<String?>(
                    stream: db.myGroupId(),
                    builder: (context, snap) {
                      final groupId = snap.data;
                      return TextButton.icon(
                        icon: Icon(
                            groupId == null ? Icons.group_add : Icons.map),
                        label: Text(
                            groupId == null ? 'Create group' : 'Open stage map'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => groupId == null
                                ? const JoinScreen()
                                : MapScreen(groupId: groupId),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (tracks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.flag_outlined,
                          size: 56, color: cs.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(
                        'Start your first stage from the stage map.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              else
                ...tracks.map((t) {
                  final ts = (t['updatedAt'] as Timestamp?)?.toDate();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.flag)),
                      title: Text(
                        '${(((t['distanceM'] as num?)?.toDouble() ?? 0) / 1000).toStringAsFixed(2)} km',
                      ),
                      subtitle: Text(
                        'top ${((t['topSpeedKmh'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} km/h · '
                        'avg ${((t['avgSpeedKmh'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} km/h',
                      ),
                      trailing: Text(
                        ts == null
                            ? ''
                            : '${ts.day}/${ts.month} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              unit,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
