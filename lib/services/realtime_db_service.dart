import 'package:firebase_database/firebase_database.dart';

/// Service managing real-time data using Firebase Realtime Database
/// Used for real-time doctor live presence, instant queue counter, and real-time alerts.
class RealtimeDbService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Stream of a doctor's live status / online presence
  Stream<DatabaseEvent> getDoctorLivePresence(String doctorId) {
    return _db.ref('doctors_presence/$doctorId').onValue;
  }

  /// Update doctor's live status (online/in consultation/offline)
  Future<void> updateDoctorPresence(String doctorId, {required bool isOnline, String status = 'Available'}) async {
    await _db.ref('doctors_presence/$doctorId').set({
      'isOnline': isOnline,
      'status': status,
      'lastActive': ServerValue.timestamp,
    });
  }

  /// Stream queue position or live waiting room count
  Stream<DatabaseEvent> getLiveQueueCount(String doctorId) {
    return _db.ref('waiting_room/$doctorId/count').onValue;
  }

  /// Push an instant real-time notification
  Future<void> sendRealtimeNotification({
    required String recipientUid,
    required String title,
    required String message,
  }) async {
    await _db.ref('notifications/$recipientUid').push().set({
      'title': title,
      'message': message,
      'timestamp': ServerValue.timestamp,
      'read': false,
    });
  }

  /// Listen to real-time notifications for a user
  Stream<DatabaseEvent> getUserNotifications(String uid) {
    return _db.ref('notifications/$uid').orderByChild('timestamp').limitToLast(10).onValue;
  }
}

