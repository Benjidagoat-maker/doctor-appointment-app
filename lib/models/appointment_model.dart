import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String userId;
  final String doctorId;
  final String doctorName; // denormalised so lists don't need a second query
  final DateTime date;
  final String status; // 'booked', 'cancelled'
  final DateTime createdAt;

  AppointmentModel({
    required this.id,
    required this.userId,
    required this.doctorId,
    this.doctorName = '',
    required this.date,
    required this.status,
    required this.createdAt,
  });

  bool get isCancelled => status.toLowerCase() == 'cancelled';

  /// Accepts a Firestore [Timestamp], a [DateTime], or null (server timestamp
  /// not resolved yet) without throwing.
  static DateTime parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> map, String docId) =>
      AppointmentModel(
        id: docId,
        userId: map['userId'] ?? '',
        doctorId: map['doctorId'] ?? '',
        doctorName: map['doctorName'] ?? '',
        date: parseDate(map['date']),
        status: map['status'] ?? 'booked',
        createdAt: parseDate(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'date': Timestamp.fromDate(date),
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
