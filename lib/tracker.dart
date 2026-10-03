import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'db.dart';

/// Offline-first tracker: timer + distance run locally (works with zero signal),
/// points buffered in SQLite and flushed to Firestore when a connection returns.
class Tracker extends ChangeNotifier {
  final Db db;
  Tracker(this.db);

  static const _bufferLimit = 20;

  Database? _local;
  final _watch = Stopwatch();
  final _buffer = <Map<String, dynamic>>[];

  Position? _lastPos;
  double _distanceM = 0;
  double _topKmh = 0;
  double _speedSum = 0;
  int _speedSamples = 0;

  String? _sessionId;
  String? _groupId;
  bool _running = false;
  Timer? _flushTimer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  bool get running => _running;
  String? get sessionId => _sessionId;
  String? get groupId => _groupId;

  double get distanceM => _distanceM;
  double get topKmh => _topKmh;
  double get avgKmh =>
      _speedSamples == 0 ? 0 : _speedSum / _speedSamples;
  Duration get elapsed => _watch.elapsed;

  Future<void> init() async {
    final dir = await getDatabasesPath();
    _local = await openDatabase(
      p.join(dir, 'rally.db'),
      version: 1,
      onCreate: (d, v) => d.execute(
        'CREATE TABLE points(id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'sessionId TEXT, lat REAL, lng REAL, speed REAL, ts INTEGER)',
      ),
    );
    _connSub = Connectivity().onConnectivityChanged.listen((_) => flush());
  }

  int _countdown = 0;
  int get countdown => _countdown;

  Future<void> start(String groupId,
      {String? name,
      String? type,
      int countdownSec = 0,
      double? startLat,
      double? startLng}) async {
    _groupId = groupId;
    _sessionId = await db.startSession(groupId,
        name: name, type: type, countdownSec: countdownSec,
        startLat: startLat, startLng: startLng);
    _countdown = countdownSec;
    notifyListeners();
    for (var i = countdownSec; i > 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      _countdown = i - 1;
      notifyListeners();
    }
    _watch
      ..reset()
      ..start();
    _running = true;
    notifyListeners();
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
  }

  Future<void> stop() async {
    if (!_running) return;
    _watch.stop();
    _running = false;
    _flushTimer?.cancel();
    await flush();
    await db.endSession(_sessionId!,
        endLat: _lastPos?.latitude, endLng: _lastPos?.longitude);
    notifyListeners();
  }

  /// Called on every GPS fix. Updates timer-derived stats and pins live doc.
  Future<void> onPosition(Position pos) async {
    if (!_running) return;
    final kmh = pos.speed * 3.6;

    if (_lastPos != null) {
      _distanceM += Geolocator.distanceBetween(
        _lastPos!.latitude,
        _lastPos!.longitude,
        pos.latitude,
        pos.longitude,
      );
    }
    _lastPos = pos;
    if (kmh > _topKmh) _topKmh = kmh;
    _speedSum += kmh;
    _speedSamples++;

    _buffer.add({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'speed': kmh,
      'ts': pos.timestamp.millisecondsSinceEpoch,
    });
    if (_buffer.length >= _bufferLimit) await flush();

    // Live pin — Firestore queues automatically while offline
    await db.updateLive(_groupId!, {
      'lat': pos.latitude,
      'lng': pos.longitude,
      'speed': kmh,
      'heading': pos.heading,
      'timerRunning': true,
    });
    notifyListeners();
  }

  /// Flush buffered points to Firestore; retries next tick if still offline.
  Future<void> flush() async {
    if (_sessionId == null) return;
    // in-memory buffer + any points persisted in SQLite earlier
    final stored = await _local!.query('points');
    final pending = <Map<String, dynamic>>[
      ..._buffer,
      ...stored.map((r) => {
            'lat': r['lat'],
            'lng': r['lng'],
            'speed': r['speed'],
            'ts': r['ts'],
          }),
    ];
    if (pending.isEmpty) return;
    try {
      await db.flushTrack(
        sessionId: _sessionId!,
        points: pending,
        distanceM: _distanceM,
        topKmh: _topKmh,
        avgKmh: avgKmh,
        durationSec: _watch.elapsed.inSeconds,
      );
      _buffer.clear();
      await _local!.delete('points');
    } catch (e) {
      // offline — persist in-memory points to SQLite; stored rows are
      // already on disk, so no re-insert. Retried on next tick/reconnect.
      for (final pt in _buffer) {
        await _local!.insert('points', {...pt, 'sessionId': _sessionId});
      }
      _buffer.clear();
    }
  }

  @override
  void dispose() {
    _watch.stop();
    _flushTimer?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}
