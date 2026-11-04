class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'user' or 'admin'

  UserModel({required this.uid, required this.name, required this.email, required this.role});

  factory UserModel.fromMap(Map<String, dynamic> map, String id) => UserModel(
        uid: id,
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        role: map['role'] ?? 'user',
      );

  Map<String, dynamic> toMap() => {'name': name, 'email': email, 'role': role};
}
