import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import '../models/doctor_model.dart';
import '../utils/app_utils.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore}) : _dbOverride = firestore;

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

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

  Future<void> setDoctorAvailability(String id, bool available) =>
      _db.collection('doctors').doc(id).update({'available': available});

  Future<void> deleteDoctor(String id) =>
      _db.collection('doctors').doc(id).delete();

  /// Books an appointment. Rejects past times and an exact duplicate of the
  /// user's own booking. (Preventing two *different* patients taking the same
  /// slot needs a server-side check, see README "Next steps".)
  Future<void> bookAppointment({
    required String userId,
    required String doctorId,
    String doctorName = '',
    required DateTime date,
  }) async {
    if (!date.isAfter(DateTime.now())) {
      throw const AppException('Please choose a time in the future.');
    }

    final mine =
        await _db.collection('appointments').where('userId', isEqualTo: userId).get();
    final duplicate = mine.docs.any((d) {
      final data = d.data();
      return data['doctorId'] == doctorId &&
          data['status'] != 'cancelled' &&
          AppointmentModel.parseDate(data['date']).isAtSameMomentAs(date);
    });
    if (duplicate) {
      throw const AppException(
          'You already have an appointment with this doctor at that time.');
    }

    final appt = AppointmentModel(
      id: '',
      userId: userId,
      doctorId: doctorId,
      doctorName: doctorName,
      date: date,
      status: 'booked',
      createdAt: DateTime.now(),
    );
    await _db.collection('appointments').add(appt.toMap());
  }

  Future<void> cancelAppointment(String appointmentId) => _db
      .collection('appointments')
      .doc(appointmentId)
      .update({'status': 'cancelled'});

  /// Newest first. Sorted on the client so no composite index is required.
  Stream<List<AppointmentModel>> getUserAppointments(String userId) => _db
      .collection('appointments')
      .where('userId', isEqualTo: userId)
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
