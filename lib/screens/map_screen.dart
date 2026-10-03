import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../db.dart';
import '../locator.dart' as app_locator;
import '../tracker.dart';
import 'leaderboard_screen.dart';

class MapScreen extends StatefulWidget {
  final String groupId;
  const MapScreen({super.key, required this.groupId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _map;
  PointAnnotationManager? _pins;
  PointAnnotationManager? _mePins;
  PointAnnotation? _mePin;
  StreamSubscription<QuerySnapshot<Object?>>? _pinSub;
  StreamSubscription<geo.Position>? _posSub;
  geo.Position? _me;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    if (!await app_locator.Locator.ensurePermissions()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Background location permission required')),
        );
      }
      return;
    }
    // Watch own GPS -> tracker + live pin
    final tracker = context.read<Tracker>();
    _posSub = app_locator.Locator.positions().listen((pos) async {
      final firstFix = _me == null;
      setState(() => _me = pos);
      if (firstFix && _map != null) {
        _centerOnMe(pos);
      }
      await tracker.onPosition(pos);
      await _updateMePin(pos);
    });
  }

  void _onMapCreated(MapboxMap map) async {
    _map = map;
    _pins = await map.annotations.createPointAnnotationManager();
    _mePins = await map.annotations.createPointAnnotationManager();
    if (_me != null) {
      await _centerOnMe(_me!);
      await _updateMePin(_me!);
    }
    _pinSub = context.read<Db>().livePins(widget.groupId).listen((snaps) {
      _renderPins(snaps.docs);
    });
  }

  Future<void> _updateMePin(geo.Position pos) async {
    if (_mePins == null) return;
    final geom = Point(coordinates: Position(pos.longitude, pos.latitude));
    if (_mePin == null) {
      _mePin = await _mePins!.create(PointAnnotationOptions(
        geometry: geom,
        iconImage: 'marker-15',
        iconColor: 0xFF1E88E5,
        textField: 'YOU',
        textColor: 0xFFFFFFFF,
        textSize: 12,
      ));
    } else {
      _mePin!.geometry = geom;
      await _mePins!.update(_mePin!);
    }
  }

  Future<void> _centerOnMe(geo.Position pos) async {
    await _map?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: 16,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  Future<void> _renderPins(List<QueryDocumentSnapshot<Object?>> docs) async {
    if (_pins == null || _map == null) return;
    await _pins!.deleteAll();
    final annotations = <PointAnnotationOptions>[];
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      final lat = (data['lat'] ?? 0) as double;
      final lng = (data['lng'] ?? 0) as double;
      if (lat == 0 && lng == 0) continue;

      // Grey out stale pins (>60s since update)
      final ts = (data['updatedAt'] as Timestamp?)?.toDate();
      final stale = ts == null ||
          DateTime.now().difference(ts).inSeconds > 60;

      annotations.add(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(lng, lat)),
          iconImage: 'marker-11',
          iconColor: stale ? 0xFF888888 : 0xFFFF5722,
          textField: (data['name'] as String?) ?? d.id,
          textColor: 0xFFFFFFFF,
          textSize: 12,
        ),
      );
    }
    await _pins!.createMulti(annotations);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _pinSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<Tracker>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stage Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            onPressed: tracker.sessionId == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LeaderboardScreen(sessionId: tracker.sessionId!),
                      ),
                    ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: MapboxStyles.OUTDOORS,
            textureView: true,
          ),
          if (_me != null)
            Positioned(
              right: 12,
              bottom: 96,
              child: FloatingActionButton.small(
                heroTag: 'recenter',
                onPressed: () => _centerOnMe(_me!),
                child: const Icon(Icons.navigation),
              ),
            ),
          if (_me != null)
            Positioned(
              top: 12,
              left: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(_me!.speed * 3.6).toStringAsFixed(0)} km/h',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${(tracker.distanceM / 1000).toStringAsFixed(2)} km',
                      ),
                      Text(tracker.elapsed.toString().split('.').first),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(tracker.running ? Icons.stop : Icons.play_arrow),
        label: Text(tracker.running ? 'End Stage' : 'Start Stage'),
        onPressed: () async {
          final tracker = context.read<Tracker>();
          if (tracker.running) {
            await tracker.stop();
          } else {
            await tracker.start(widget.groupId);
          }
        },
      ),
    );
  }
}
