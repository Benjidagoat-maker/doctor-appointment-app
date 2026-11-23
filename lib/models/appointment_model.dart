import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String userId;
  final String patientName;
  final String patientEmail;
  final String doctorId;
  final String doctorName;
  final String specialty;
  final DateTime date; // start time (UTC)
  final int durationMin;
  final DateTime? endAt;
  final String status; // 'confirmed', 'completed', 'cancelled', 'no_show'
  final String reason;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? cancelledBy;

  AppointmentModel({
    required this.id,
    required this.userId,
    this.patientName = '',
    this.patientEmail = '',
    required this.doctorId,
    this.doctorName = '',
    this.specialty = 'General',
    required this.date,
    this.durationMin = 30,
    DateTime? endAt,
    required this.status,
    this.reason = '',
    required this.createdAt,
    this.updatedAt,
    this.cancelledBy,
  }) : endAt = endAt ?? date.add(Duration(minutes: durationMin));

  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isConfirmed => status.toLowerCase() == 'confirmed';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isNoShow => status.toLowerCase() == 'no_show';

  /// Deterministic slot key for the slot lock document: yyyyMMddHHmm in UTC
  static String formatSlotKey(DateTime dateTime) {
    final utc = dateTime.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final min = utc.minute.toString().padLeft(2, '0');
    return '$y$m$d$h$min';
  }

  String get slotKey => formatSlotKey(date);

  static DateTime parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  /// Normalizes legacy statuses ('booked', 'pending', 'Cancelled') to v1 specification:
  /// 'confirmed', 'completed', 'cancelled', 'no_show'
  static String normalizeStatus(String? raw) {
    if (raw == null) return 'confirmed';
    final s = raw.toLowerCase().trim();
    if (s == 'booked' || s == 'pending') return 'confirmed';
    if (s == 'cancelled' || s == 'canceled') return 'cancelled';
    if (s == 'completed') return 'completed';
    if (s == 'no_show') return 'no_show';
    return s;
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> map, String docId) {
    final parsedDate = parseDate(map['date']);
    final int dur = (map['durationMin'] as num?)?.toInt() ?? 30;
    final parsedEndAt = map['endAt'] != null
        ? parseDate(map['endAt'])
        : parsedDate.add(Duration(minutes: dur));

    return AppointmentModel(
      id: docId,
      userId: map['userId'] ?? '',
      patientName: map['patientName'] ?? '',
      patientEmail: map['patientEmail'] ?? '',
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      specialty: map['specialty'] ?? 'General',
      date: parsedDate,
      durationMin: dur,
      endAt: parsedEndAt,
      status: normalizeStatus(map['status']),
      reason: map['reason'] ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
      cancelledBy: map['cancelledBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'patientName': patientName,
        'patientEmail': patientEmail,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'specialty': specialty,
        'date': Timestamp.fromDate(date.toUtc()),
        'durationMin': durationMin,
        'endAt': Timestamp.fromDate(endAt ?? date.add(Duration(minutes: durationMin)).toUtc()),
        'status': status,
        'reason': reason,
        'createdAt': Timestamp.fromDate(createdAt.toUtc()),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!.toUtc()),
        if (cancelledBy != null) 'cancelledBy': cancelledBy,
      };
}
