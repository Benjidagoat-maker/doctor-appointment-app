import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String userId;
  final String doctorId;
  final String doctorName; // denormalised so lists don't need a second query
  final String patientName;
  final String patientEmail;
  final String specialty;
  final DateTime date;
  final String status; // 'booked', 'pending', 'confirmed', 'completed', 'cancelled'
  final DateTime createdAt;

  AppointmentModel({
    required this.id,
    required this.userId,
    required this.doctorId,
    this.doctorName = '',
    this.patientName = '',
    this.patientEmail = '',
    this.specialty = 'General',
    required this.date,
    required this.status,
    required this.createdAt,
  });

  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isConfirmed => status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'booked';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isCompleted => status.toLowerCase() == 'completed';

  /// Accepts a Firestore [Timestamp], a [DateTime], or a String without throwing.
  static DateTime parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> map, String docId) =>
      AppointmentModel(
        id: docId,
        userId: map['userId'] ?? map['user_id'] ?? '',
        doctorId: map['doctorId'] ?? map['doctor_id'] ?? '',
        doctorName: map['doctorName'] ?? map['doctor_name'] ?? '',
        patientName: map['patientName'] ?? map['patient_name'] ?? '',
        patientEmail: map['patientEmail'] ?? map['patient_email'] ?? '',
        specialty: map['specialty'] ?? map['specialty_name'] ?? 'General',
        date: parseDate(map['date'] ?? map['appointment_date']),
        status: map['status'] ?? 'booked',
        createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'patientName': patientName,
        'patientEmail': patientEmail,
        'specialty': specialty,
        'date': Timestamp.fromDate(date),
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
