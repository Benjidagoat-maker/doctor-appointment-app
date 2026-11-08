import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'user' or 'admin'
  final bool isOnline;
  final DateTime? lastLogin;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.isOnline = false,
    this.lastLogin,
    this.createdAt,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) => UserModel(
        uid: id,
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        role: map['role'] ?? 'user',
        isOnline: map['is_online'] ?? map['isOnline'] ?? false,
        lastLogin: parseDate(map['last_login'] ?? map['lastLogin']),
        createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role,
        'is_online': isOnline,
        if (lastLogin != null) 'last_login': Timestamp.fromDate(lastLogin!),
        if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      };
}
