import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db.dart';
import '../theme.dart';
import 'map_screen.dart';


/// Personal dashboard styled like the Figma design: brand topbar, hero greeting,
/// stat grid, stage CTA, recent drives.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<Db>();
    final theme = context.watch<ThemeNotifier>();

    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.myTracks(),
        builder: (context, snap) {
          final tracks = snap.data ?? const [];
          final totalKm = tracks.fold<double>(
                  0, (s, t) => s + ((t['distanceM'] as num?)?.toDouble() ?? 0)) /
              1000;
          final topKmh = tracks.fold<double>(
              0,
              (m, t) =>
                  ((t['topSpeedKmh'] as num?)?.toDouble() ?? 0) > m
                      ? (t['topSpeedKmh'] as num).toDouble()
                      : m);
          final totalSec = tracks.fold<int>(
              0, (s, t) => s + ((t['durationSec'] as num?)?.toInt() ?? 0));
          final avgKmh = totalSec > 0
              ? (totalKm / (totalSec / 3600))
              : 0.0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 56, 22, 24),
            children: [
              Row(
                children: [
                  const _Brand(),
                  const Spacer(),
                  IconButton(
                    onPressed: theme.toggle,
                    icon: Icon(theme.isLight
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined),
                  ),
                  const SizedBox(width: 4),
                  StreamBuilder<DocumentSnapshot<Object?>>(
                    stream: db.myProfile(),
                    builder: (context, p) {
                      final name = (p.data?.data() as Map?)?['displayName']
                              as String? ??
                          'Driver';
                      final initials = name
                          .trim()
                          .split(RegExp(r'\s+'))
                          .take(2)
                          .map((w) => w[0].toUpperCase())
                          .join();
                      return CircleAvatar(
                        radius: 17,
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                DateTime.now().toString().substring(0, 10),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 2,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 6),
              StreamBuilder<DocumentSnapshot<Object?>>(
                stream: db.myProfile(),
                builder: (context, p) {
                  final name = (p.data?.data() as Map?)?['displayName']
                          as String? ??
                      'Driver';
                  return Text('Ready to chase\nthe next split, $name.',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1));
                },
              ),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _StatCard(icon: Icons.route_outlined, label: 'TOTAL DISTANCE', value: totalKm.toStringAsFixed(0), unit: 'km'),
                  _StatCard(icon: Icons.speed_outlined, label: 'TOP SPEED', value: topKmh.toStringAsFixed(0), unit: 'km/h'),
                  _StatCard(icon: Icons.flag_outlined, label: 'STAGES', value: tracks.length.toString(), unit: ''),
                  _StatCard(icon: Icons.bolt_outlined, label: 'AVERAGE SPEED', value: avgKmh.toStringAsFixed(0), unit: 'km/h'),
                ],
              ),
              const SizedBox(height: 20),
              StreamBuilder<String?>(
                stream: db.myGroupId(),
                builder: (context, g) {
                  final groupId = g.data;
                  return Card(
                    color: Theme.of(context).colorScheme.primary,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: groupId == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        MapScreen(groupId: groupId)),
                              ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const Icon(Icons.map_outlined,
                                color: Colors.white, size: 30),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                groupId == null
                                    ? 'No group yet — create or join one'
                                    : 'Open live stage map',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              Text('YOUR ACTIVITY',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 2,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      )),
              const SizedBox(height: 4),
              Text('Recent drives',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              if (tracks.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Icon(Icons.flag_outlined,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('Your next drive starts here',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(
                          'Start a stage and your distance, speed and splits will show up here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...tracks.asMap().entries.map((e) {
                  final t = e.value;
                  final ts = (t['updatedAt'] as Timestamp?)?.toDate();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                  '0${e.key + 1}'.substring(
                                      '0${e.key + 1}'.length - 2),
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  ts == null
                                      ? 'Stage'
                                      : '${ts.day}/${ts.month} · ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: [
                              _Metric('${(((t['distanceM'] as num?)?.toDouble() ?? 0) / 1000).toStringAsFixed(1)}', 'KM'),
                              _Metric('${((t['topSpeedKmh'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}', 'TOP'),
                              _Metric('${((t['avgSpeedKmh'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}', 'AVG'),
                              _Metric('${(((t['durationSec'] as num?)?.toInt() ?? 0) ~/ 60)}:${(((t['durationSec'] as num?)?.toInt() ?? 0) % 60).toString().padLeft(2, '0')}', 'MIN'),
                            ],
                          ),
                        ],
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

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.route, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Text('RALLYTRACK',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800, letterSpacing: 1.6)),
        ],
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  const _StatCard({required this.icon, required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(height: 10),
            Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const Spacer(),
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface),
                children: [
                  TextSpan(text: value),
                  if (unit.isNotEmpty)
                    TextSpan(
                        text: ' $unit',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  const _Metric(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}
