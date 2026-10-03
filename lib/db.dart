import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class Db {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;

  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
  }

  Future<void> setProfile(String displayName) async {
    await _fs.collection('users').doc(uid).set({
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Create a private group; returns the 4-digit join code.
  Future<String> createGroup(String name) async {
    final code = _randomCode();
    final doc = _fs.collection('groups').doc();
    await doc.set({
      'name': name,
      'code': code,
      'createdBy': uid,
      'memberUids': [uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    // lookup doc so join-by-code is a single cheap read
    await _fs.collection('codes').doc(code).set({'groupId': doc.id});
    return code;
  }

  /// Join by 4-digit pin. Returns groupId or null if code invalid.
  Future<String?> joinByCode(String code) async {
    final snap = await _fs.collection('codes').doc(code).get();
    final groupId = snap.data()?['groupId'] as String?;
    if (groupId == null) return null;
    await _fs.collection('groups').doc(groupId).update({
      'memberUids': FieldValue.arrayUnion([uid]),
    });
    return groupId;
  }

  String _randomCode() {
    final r = Random();
    return (1000 + r.nextInt(9000)).toString();
  }

  Stream<QuerySnapshot<Object?>> livePins(String groupId) =>
      _fs.collection('groups').doc(groupId).collection('live').snapshots();

  /// Upsert own live pin. Firestore queues this automatically while offline.
  Future<void> updateLive(String groupId, Map<String, dynamic> data) =>
      _fs
          .collection('groups')
          .doc(groupId)
          .collection('live')
          .doc(uid)
          .set({...data, 'updatedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));

  Future<void> removeLive(String groupId) =>
      _fs.collection('groups').doc(groupId).collection('live').doc(uid).delete();

  Future<String> startSession(String groupId) async {
    final doc = _fs.collection('sessions').doc();
    await doc.set({
      'groupId': groupId,
      'startedAt': FieldValue.serverTimestamp(),
      'endedAt': null,
      'status': 'live',
    });
    return doc.id;
  }

  /// Write buffered track points (batched) + update own summary doc.
  Future<void> flushTrack({
    required String sessionId,
    required List<Map<String, dynamic>> points,
    required double distanceM,
    required double topKmh,
    required double avgKmh,
    required int durationSec,
  }) async {
    final batch = _fs.batch();
    final coll = _fs.collection('sessions/$sessionId/tracks/$uid/points');
    for (final p in points) {
      batch.set(coll.doc(), p);
    }
    batch.set(
      _fs.collection('sessions').doc(sessionId).collection('tracks').doc(uid),
      {
        'uid': uid,
        'distanceM': distanceM,
        'topSpeedKmh': topKmh,
        'avgSpeedKmh': avgKmh,
        'durationSec': durationSec,
        'pointCount': FieldValue.increment(points.length),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> endSession(String sessionId) =>
      _fs.collection('sessions').doc(sessionId).update({
        'endedAt': FieldValue.serverTimestamp(),
        'status': 'done',
      });

  /// Leaderboard: top distance, top speed, best avg pace for a session.
  Stream<List<Map<String, dynamic>>> sessionBoard(String sessionId) =>
      _fs
          .collection('sessions')
          .doc(sessionId)
          .collection('tracks')
          .orderBy('distanceM', descending: true)
          .snapshots()
          .map((snaps) => snaps.docs
              .map((d) => {...d.data(), 'uid': d.id})
              .toList());

  Stream<QuerySnapshot<Object?>> sessionsFor(String groupId) => _fs
      .collection('sessions')
      .where('groupId', isEqualTo: groupId)
      .orderBy('startedAt', descending: true)
      .snapshots();

  /// All of the current user's track summaries across every group/session.
  Stream<List<Map<String, dynamic>>> myTracks() => _fs
      .collectionGroup('tracks')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((snaps) => snaps.docs
          .map((d) => {...d.data(), 'sessionId': d.reference.parent.parent?.id})
          .toList()
        ..sort((a, b) {
          final ta = a['updatedAt'] as Timestamp?;
          final tb = b['updatedAt'] as Timestamp?;
          if (ta == null || tb == null) return 0;
          return tb.compareTo(ta);
        }));

  Stream<DocumentSnapshot<Object?>> myProfile() =>
      _fs.collection('users').doc(uid).snapshots();

  Stream<String?> myGroupId() => _fs
      .collection('groups')
      .where('memberUids', arrayContains: uid)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : s.docs.first.id);
}
