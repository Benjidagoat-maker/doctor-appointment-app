import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Real-time data (doctor presence, notifications) via Firebase Realtime
/// Database. Everything here is optional sugar on top of Firestore, so the
/// service degrades gracefully when the database isn't configured
/// (e.g. `databaseURL` missing from firebase_options.dart on web).
class RealtimeDbService {
  RealtimeDbService({FirebaseDatabase? database}) : _dbOverride = database;

  final FirebaseDatabase? _dbOverride;

  FirebaseDatabase? get _db {
    try {
      return _dbOverride ?? FirebaseDatabase.instance;
    } catch (e) {
      debugPrint('Realtime Database unavailable: $e');
      return null;
    }
  }

  /// Stream of a doctor's live status / online presence.
  /// Empty (never errors) when Realtime Database is unavailable.
  Stream<DatabaseEvent> getDoctorLivePresence(String doctorId) {
    final db = _db;
    if (db == null) return const Stream<DatabaseEvent>.empty();
    return db
        .ref('doctors_presence/$doctorId')
        .onValue
        .handleError((Object e) => debugPrint('Presence stream error: $e'));
  }

  Future<void> updateDoctorPresence(String doctorId,
      {required bool isOnline, String status = 'Available'}) async {
    await _db?.ref('doctors_presence/$doctorId').set({
      'isOnline': isOnline,
      'status': status,
      'lastActive': ServerValue.timestamp,
    });
  }

  Stream<DatabaseEvent> getLiveQueueCount(String doctorId) {
    final db = _db;
    if (db == null) return const Stream<DatabaseEvent>.empty();
    return db.ref('waiting_room/$doctorId/count').onValue;
  }

  Future<void> sendRealtimeNotification({
    required String recipientUid,
    required String title,
    required String message,
  }) async {
    await _db?.ref('notifications/$recipientUid').push().set({
      'title': title,
      'message': message,
      'timestamp': ServerValue.timestamp,
      'read': false,
    });
  }

  Stream<DatabaseEvent> getUserNotifications(String uid) {
    final db = _db;
    if (db == null) return const Stream<DatabaseEvent>.empty();
    return db
        .ref('notifications/$uid')
        .orderByChild('timestamp')
        .limitToLast(10)
        .onValue;
  }
}
