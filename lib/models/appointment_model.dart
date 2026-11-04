import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String userId;
  final String doctorId;
  final DateTime date;
  final String status; // 'booked', 'cancelled'
  final DateTime createdAt;

  AppointmentModel({required this.id, required this.userId, required this.doctorId, required this.date, required this.status, required this.createdAt});

  factory AppointmentModel.fromMap(Map<String, dynamic> map, String docId) => AppointmentModel(
        id: docId,
        userId: map['userId'] ?? '',
        doctorId: map['doctorId'] ?? '',
        date: (map['date'] as Timestamp).toDate(),
        status: map['status'] ?? 'booked',
        createdAt: (map['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'doctorId': doctorId,
        'date': Timestamp.fromDate(date),
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
