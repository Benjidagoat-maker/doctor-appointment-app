import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_model.dart';
import '../models/appointment_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<DoctorModel>> getDoctors() => _db.collection('doctors').snapshots().map(
      (s) => s.docs.map((d) => DoctorModel.fromMap(d.data(), d.id)).toList());

  Future<void> addDoctor(DoctorModel doctor) => _db.collection('doctors').add(doctor.toMap());

  Future<void> deleteDoctor(String id) => _db.collection('doctors').doc(id).delete();

  Future<void> bookAppointment(String userId, String doctorId, DateTime date) {
    final appt = AppointmentModel(id: '', userId: userId, doctorId: doctorId, date: date, status: 'booked', createdAt: DateTime.now());
    return _db.collection('appointments').add(appt.toMap());
  }

  Future<void> cancelAppointment(String appointmentId) =>
      _db.collection('appointments').doc(appointmentId).update({'status': 'cancelled'});

  Stream<List<AppointmentModel>> getUserAppointments(String userId) => _db
      .collection('appointments')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.map((d) => AppointmentModel.fromMap(d.data(), d.id)).toList());

  Stream<List<AppointmentModel>> getAllAppointments() => _db.collection('appointments').snapshots().map(
      (s) => s.docs.map((d) => AppointmentModel.fromMap(d.data(), d.id)).toList());
}
