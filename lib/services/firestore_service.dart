import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import '../models/doctor_model.dart';
import '../models/user_model.dart';
import '../utils/app_utils.dart';

class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _dbOverride = firestore,
        _functionsOverride = functions;

  final FirebaseFirestore? _dbOverride;
  final FirebaseFunctions? _functionsOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  // ============================================================
  // USERS MANAGEMENT (Admin-Only Live Monitor & Role Toggling)
  // ============================================================
  Stream<List<UserModel>> getAllUsers() {
    return _db.collection('users').snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
      // Sort online users first, then alphabetically by name
      list.sort((a, b) {
        if (a.isOnline != b.isOnline) {
          return a.isOnline ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    });
  }

  Future<void> toggleUserRole(String uid, String currentRole) async {
    final targetRole =
        UserModel.normalizeRole(currentRole) == 'admin' ? 'user' : 'admin';
    try {
      await _functions.httpsCallable('setUserRole').call({
        'uid': uid,
        'role': targetRole,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AppException(e.message ?? 'Unable to update user role.');
    }
  }

  // ============================================================
  // DOCTORS & SPECIALTIES MANAGEMENT
  // ============================================================
  Stream<List<DoctorModel>> getDoctors() =>
      _db.collection('doctors').snapshots().map((s) {
        final list =
            s.docs.map((d) => DoctorModel.fromMap(d.data(), d.id)).toList();
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  Future<void> addDoctor(DoctorModel doctor) =>
      _db.collection('doctors').add(doctor.toMap());

  Future<void> updateDoctor(DoctorModel doctor) =>
      _db.collection('doctors').doc(doctor.id).update(doctor.toMap());

  Future<void> setDoctorAvailability(String id, bool available) =>
      _db.collection('doctors').doc(id).update({
        'active': available,
        'available': available,
      });

  Future<void> deleteDoctor(String id) =>
      _db.collection('doctors').doc(id).delete();

  /// Stream of booked slots for a specific doctor to support real-time UI updates
  Stream<Set<String>> getDoctorBookedSlots(String doctorId) => _db
      .collection('doctors')
      .doc(doctorId)
      .collection('bookedSlots')
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toSet());

  // ============================================================
  // APPOINTMENTS MANAGEMENT
  // ============================================================

  /// Asks the trusted server to validate the slot and atomically reserve it.
  Future<String> bookAppointment({
    required String doctorId,
    required DateTime date,
    String reason = '',
  }) async {
    try {
      final result = await _functions.httpsCallable('bookAppointment').call({
        'doctorId': doctorId,
        'date': date.toUtc().toIso8601String(),
        'reason': reason,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['appointmentId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw AppException(e.message ?? 'Unable to book this appointment.');
    }
  }

  /// Admin appointment creation is performed by a trusted server transaction.
  Future<void> addAppointment(AppointmentModel appt) async {
    try {
      await _functions.httpsCallable('createAdminAppointment').call({
        'doctorId': appt.doctorId,
        'patientEmail': appt.patientEmail,
        'date': appt.date.toUtc().toIso8601String(),
        'reason': appt.reason,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AppException(e.message ?? 'Unable to create this appointment.');
    }
  }

  /// Cancels an appointment through the server-authorized booking workflow.
  Future<void> cancelAppointment({
    required String appointmentId,
  }) async {
    try {
      await _functions
          .httpsCallable('cancelAppointment')
          .call({'appointmentId': appointmentId});
    } on FirebaseFunctionsException catch (e) {
      throw AppException(e.message ?? 'Unable to cancel this appointment.');
    }
  }

  /// Admin / Doctor update appointment status (Confirm/Cancel/Completed/Pending/no_show)
  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String newStatus,
  }) async {
    final normalized = AppointmentModel.normalizeStatus(newStatus);
    try {
      await _functions.httpsCallable('setAppointmentStatus').call({
        'appointmentId': appointmentId,
        'status': normalized,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AppException(e.message ?? 'Unable to update appointment status.');
    }
  }

  /// Admin reschedule appointment date
  Future<void> rescheduleAppointment(String appointmentId, DateTime newDate) async {
    try {
      await _functions.httpsCallable('rescheduleAppointment').call({
        'appointmentId': appointmentId,
        'date': newDate.toUtc().toIso8601String(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw AppException(e.message ?? 'Unable to reschedule this appointment.');
    }
  }

  /// Admin delete appointment record
  Future<void> deleteAppointment(String appointmentId) async {
    try {
      await _functions
          .httpsCallable('deleteAppointment')
          .call({'appointmentId': appointmentId});
    } on FirebaseFunctionsException catch (e) {
      throw AppException(e.message ?? 'Unable to delete this appointment.');
    }
  }

  /// Newest first. Sorted on client side.
  Stream<List<AppointmentModel>> getUserAppointments(String userId) => _db
      .collection('appointments')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map(_toSortedAppointments);

  /// Get appointments for a specific doctor (Doctor agenda)
  Stream<List<AppointmentModel>> getDoctorAppointments(String doctorId) => _db
      .collection('appointments')
      .where('doctorId', isEqualTo: doctorId)
      .snapshots()
      .map(_toSortedAppointments);

  Stream<List<AppointmentModel>> getAllAppointments() =>
      _db.collection('appointments').snapshots().map(_toSortedAppointments);

  List<AppointmentModel> _toSortedAppointments(
      QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs
        .map((d) => AppointmentModel.fromMap(d.data(), d.id))
        .where((appointment) {
          if (appointment.hasValidDate) return true;
          debugPrint('Ignoring appointment ${appointment.id} with an invalid date.');
          return false;
        })
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}
