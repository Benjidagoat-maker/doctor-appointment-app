class TimeRange {
  final String start; // e.g. "09:00"
  final String end; // e.g. "12:00"

  const TimeRange({required this.start, required this.end});

  factory TimeRange.fromMap(Map<String, dynamic> map) => TimeRange(
        start: map['start'] ?? '',
        end: map['end'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'start': start,
        'end': end,
      };
}

class DoctorModel {
  final String id;
  final String name;
  final String specialty;
  final String phone;
  final String bio;
  final int experienceYears;
  final String avatarUrl;
  final String clinicAddress;
  final bool active;
  final int slotDurationMin;
  final Map<String, List<TimeRange>> schedule;
  final List<String> daysOff;
  final String timezone;
  final String? ownerUid;

  DoctorModel({
    required this.id,
    required this.name,
    required this.specialty,
    required this.phone,
    this.bio = '',
    this.experienceYears = 0,
    this.avatarUrl = '',
    this.clinicAddress = '',
    bool? available,
    bool active = true,
    this.slotDurationMin = 30,
    Map<String, List<TimeRange>>? schedule,
    List<String>? daysOff,
    this.timezone = 'Africa/Tunis',
    this.ownerUid,
  })  : active = available ?? active,
        schedule = schedule ?? _defaultSchedule(),
        daysOff = daysOff ?? const [];

  /// Backward-compatibility getter for 'available'
  bool get available => active;

  static Map<String, List<TimeRange>> _defaultSchedule() {
    return {
      'mon': [
        const TimeRange(start: '09:00', end: '12:00'),
        const TimeRange(start: '14:00', end: '17:00'),
      ],
      'tue': [
        const TimeRange(start: '09:00', end: '12:00'),
        const TimeRange(start: '14:00', end: '17:00'),
      ],
      'wed': [
        const TimeRange(start: '09:00', end: '12:00'),
        const TimeRange(start: '14:00', end: '17:00'),
      ],
      'thu': [
        const TimeRange(start: '09:00', end: '12:00'),
        const TimeRange(start: '14:00', end: '17:00'),
      ],
      'fri': [
        const TimeRange(start: '09:00', end: '12:00'),
        const TimeRange(start: '14:00', end: '17:00'),
      ],
      'sat': [
        const TimeRange(start: '09:00', end: '12:00'),
      ],
      'sun': const [],
    };
  }

  factory DoctorModel.fromMap(Map<String, dynamic> map, String docId) {
    Map<String, List<TimeRange>> scheduleMap = {};
    if (map['schedule'] is Map) {
      final rawSched = map['schedule'] as Map<dynamic, dynamic>;
      rawSched.forEach((key, val) {
        if (val is List) {
          scheduleMap[key.toString()] = val
              .whereType<Map>()
              .map((e) => TimeRange.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        }
      });
    } else {
      scheduleMap = _defaultSchedule();
    }

    List<String> parsedDaysOff = [];
    if (map['daysOff'] is List) {
      parsedDaysOff =
          (map['daysOff'] as List).map((e) => e.toString()).toList();
    }

    final dynamic rawActive = map['active'] ?? map['available'];
    final bool isActive = rawActive is bool ? rawActive : true;

    return DoctorModel(
      id: docId,
      name: map['name'] ?? '',
      specialty: map['specialty'] ?? '',
      phone: map['phone'] ?? '',
      bio: map['bio'] ?? '',
      experienceYears: (map['experienceYears'] as num?)?.toInt() ?? 0,
      avatarUrl: map['avatarUrl'] ?? '',
      clinicAddress: map['clinicAddress'] ?? '',
      active: isActive,
      slotDurationMin: (map['slotDurationMin'] as num?)?.toInt() ?? 30,
      schedule: scheduleMap,
      daysOff: parsedDaysOff,
      timezone: map['timezone'] ?? 'Africa/Tunis',
      ownerUid: map['ownerUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final schedMap = <String, dynamic>{};
    schedule.forEach((k, v) {
      schedMap[k] = v.map((r) => r.toMap()).toList();
    });

    return {
      'name': name,
      'specialty': specialty,
      'phone': phone,
      'bio': bio,
      'experienceYears': experienceYears,
      'avatarUrl': avatarUrl,
      'clinicAddress': clinicAddress,
      'active': active,
      'available': active, // keep available for backwards compatibility
      'slotDurationMin': slotDurationMin,
      'schedule': schedMap,
      'daysOff': daysOff,
      'timezone': timezone,
      if (ownerUid != null) 'ownerUid': ownerUid,
    };
  }
}
