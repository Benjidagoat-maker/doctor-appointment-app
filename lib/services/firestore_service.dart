import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import '../models/doctor_model.dart';
import '../models/user_model.dart';
import '../utils/app_utils.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore}) : _dbOverride = firestore;

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

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
    await _db.collection('users').doc(uid).update({'role': targetRole});
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

  /// Atomic booking implementation per Section 6.3 of the Cahier des charges.
  /// Uses a Firestore batch transaction locking doctors/{doctorId}/bookedSlots/{slotKey}
  /// and creating appointments/{apptId}.
  ///
  /// Prevents double bookings atomically at database level.
  Future<String> bookAppointment({
    required String userId,
    String patientName = '',
    String patientEmail = '',
    required String doctorId,
    String doctorName = '',
    String specialty = 'General',
    required DateTime date,
    int durationMin = 30,
    String reason = '',
  }) async {
    final now = DateTime.now();
    if (!date.isAfter(now)) {
      throw const AppException('Please choose a time in the future.');
    }

    // Check maximum 3 active upcoming appointments for patient (Exigence F-23)
    final mine = await _db
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .get();

    final activeUpcoming = mine.docs.where((d) {
      final data = d.data();
      final status = AppointmentModel.normalizeStatus(data['status']);
      if (status == 'cancelled' || status == 'completed') return false;
      final apptDate = AppointmentModel.parseDate(data['date']);
      return apptDate.isAfter(now);
    }).toList();

    if (activeUpcoming.length >= 3) {
      throw const AppException(
          'Maximum of 3 upcoming active appointments reached.');
    }

    // Check overlap for the same patient (Exigence F-23)
    final apptEnd = date.add(Duration(minutes: durationMin));
    final hasOverlap = activeUpcoming.any((d) {
      final data = d.data();
      final existingStart = AppointmentModel.parseDate(data['date']);
      final existingDur = (data['durationMin'] as num?)?.toInt() ?? 30;
      final existingEnd = existingStart.add(Duration(minutes: existingDur));
      return (date.isBefore(existingEnd) && apptEnd.isAfter(existingStart));
    });

    if (hasOverlap) {
      throw const AppException(
          'You already have an appointment during this time window.');
    }

    final slotKey = AppointmentModel.formatSlotKey(date);
    final apptRef = _db.collection('appointments').doc();
    final lockRef = _db
        .collection('doctors')
        .doc(doctorId)
        .collection('bookedSlots')
        .doc(slotKey);

    // Check if slot lock already exists before committing
    final existingLock = await lockRef.get();
    if (existingLock.exists) {
      throw const AppException('Ce créneau vient d\'être pris');
    }

    final batch = _db.batch();

    final appointment = AppointmentModel(
      id: apptRef.id,
      userId: userId,
      patientName: patientName,
      patientEmail: patientEmail,
      doctorId: doctorId,
      doctorName: doctorName,
      specialty: specialty,
      date: date,
      durationMin: durationMin,
      endAt: apptEnd,
      status: 'confirmed',
      reason: reason,
      createdAt: now,
    );

    batch.set(apptRef, appointment.toMap());
    batch.set(lockRef, {
      'appointmentId': apptRef.id,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
      return apptRef.id;
    } catch (e) {
      throw const AppException('Ce créneau vient d\'être pris');
    }
  }

  /// Admin manual appointment creation
  Future<void> addAppointment(AppointmentModel appt) =>
      _db.collection('appointments').add(appt.toMap());

  /// Cancels an appointment.
  /// If patient is cancelling, enforces the 48-hour cancellation rule (Section 6.7 / F-24).
  /// Releases doctors/{doctorId}/bookedSlots/{slotKey} atomically.
  Future<void> cancelAppointment({
    required String appointmentId,
    required String cancelledByUid,
    bool isAdminOrDoctor = false,
  }) async {
    final apptDoc =
        await _db.collection('appointments').doc(appointmentId).get();
    if (!apptDoc.exists) {
      throw const AppException('Appointment not found.');
    }

    final data = apptDoc.data()!;
    final appt = AppointmentModel.fromMap(data, apptDoc.id);

    if (appt.isCancelled) {
      return; // Already cancelled
    }

    final now = DateTime.now();

    // Patients can only cancel at least 48h before the appointment
    if (!isAdminOrDoctor) {
      if (appt.date.difference(now).inHours < 48) {
        throw const AppException(
            'Les rendez-vous ne peuvent être annulés que plus de 48 h à l\'avance.');
      }
    }

    final slotKey = AppointmentModel.formatSlotKey(appt.date);
    final lockRef = _db
        .collection('doctors')
        .doc(appt.doctorId)
        .collection('bookedSlots')
        .doc(slotKey);

    final batch = _db.batch();
    batch.update(_db.collection('appointments').doc(appointmentId), {
      'status': 'cancelled',
      'cancelledBy': cancelledByUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(lockRef);

    await batch.commit();
  }

  /// Admin / Doctor update appointment status (Confirm/Cancel/Completed/Pending/no_show)
  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String newStatus,
  }) async {
    final normalized = AppointmentModel.normalizeStatus(newStatus);
    await _db.collection('appointments').doc(appointmentId).update({
      'status': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin reschedule appointment date
  Future<void> rescheduleAppointment(
          String appointmentId, DateTime newDate) =>
      _db
          .collection('appointments')
          .doc(appointmentId)
          .update({'date': Timestamp.fromDate(newDate.toUtc())});

  /// Admin delete appointment record
  Future<void> deleteAppointment(String appointmentId) =>
      _db.collection('appointments').doc(appointmentId).delete();

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
    final list =
        s.docs.map((d) => AppointmentModel.fromMap(d.data(), d.id)).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}
