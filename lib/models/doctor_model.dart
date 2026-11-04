class DoctorModel {
  final String id;
  final String name;
  final String specialty;
  final String phone;
  final bool available;

  DoctorModel({required this.id, required this.name, required this.specialty, required this.phone, required this.available});

  factory DoctorModel.fromMap(Map<String, dynamic> map, String docId) => DoctorModel(
        id: docId,
        name: map['name'] ?? '',
        specialty: map['specialty'] ?? '',
        phone: map['phone'] ?? '',
        available: map['available'] ?? true,
      );

  Map<String, dynamic> toMap() => {'name': name, 'specialty': specialty, 'phone': phone, 'available': available};
}
