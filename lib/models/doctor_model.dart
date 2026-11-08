class DoctorModel {
  final String id;
  final String name;
  final String specialty;
  final String phone;
  final bool available;
  final String bio;
  final int experienceYears;
  final String avatarUrl;

  DoctorModel({
    required this.id,
    required this.name,
    required this.specialty,
    required this.phone,
    required this.available,
    this.bio = '',
    this.experienceYears = 0,
    this.avatarUrl = '',
  });

  factory DoctorModel.fromMap(Map<String, dynamic> map, String docId) {
    int parsedExp = 0;
    final rawExp = map['experienceYears'] ?? map['experience_years'];
    if (rawExp is int) {
      parsedExp = rawExp;
    } else if (rawExp is String) {
      parsedExp = int.tryParse(rawExp) ?? 0;
    }

    return DoctorModel(
      id: docId,
      name: map['name'] ?? '',
      specialty: map['specialty'] ?? '',
      phone: map['phone'] ?? '',
      available: map['available'] ?? true,
      bio: map['bio'] ?? '',
      experienceYears: parsedExp,
      avatarUrl: map['avatarUrl'] ?? map['avatar_url'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'specialty': specialty,
        'phone': phone,
        'available': available,
        'bio': bio,
        'experienceYears': experienceYears,
        'avatarUrl': avatarUrl,
      };
}
