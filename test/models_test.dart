import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:doctor_appointment_app/models/appointment_model.dart';
import 'package:doctor_appointment_app/models/doctor_model.dart';
import 'package:doctor_appointment_app/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DoctorModel', () {
    test('fromMap applies safe defaults', () {
      final d = DoctorModel.fromMap({}, 'id1');
      expect(d.id, 'id1');
      expect(d.name, '');
      expect(d.available, isTrue);
      expect(d.experienceYears, 0);
      expect(d.bio, '');
    });

    test('toMap/fromMap round-trip with specialty and bio', () {
      final d = DoctorModel(
        id: 'x',
        name: 'Dr A',
        specialty: 'Cardiology',
        phone: '123',
        available: false,
        bio: 'Senior Cardiologist',
        experienceYears: 10,
        avatarUrl: 'https://img.example/avatar.png',
      );
      final back = DoctorModel.fromMap(d.toMap(), 'x');
      expect(back.name, 'Dr A');
      expect(back.specialty, 'Cardiology');
      expect(back.available, isFalse);
      expect(back.bio, 'Senior Cardiologist');
      expect(back.experienceYears, 10);
      expect(back.avatarUrl, 'https://img.example/avatar.png');
    });
  });

  group('UserModel', () {
    test('role defaults to user', () {
      expect(UserModel.fromMap({'name': 'N', 'email': 'e@x.com'}, 'u').role, 'user');
      expect(UserModel.fromMap({'name': 'N', 'email': 'e@x.com'}, 'u').isAdmin, isFalse);
    });

    test('isAdmin is true when role is admin (case-insensitive)', () {
      final admin = UserModel.fromMap({'name': 'Admin', 'email': 'kenjirobenji@gmail.com', 'role': 'admin'}, 'u1');
      expect(admin.isAdmin, isTrue);
      expect(admin.role, 'admin');

      final upperAdmin = UserModel.fromMap({'name': 'Admin', 'email': 'a@b.com', 'role': 'ADMIN'}, 'u2');
      expect(upperAdmin.isAdmin, isTrue);
    });

    test('parses isOnline and timestamps', () {
      final now = DateTime.now();
      final u = UserModel.fromMap({
        'name': 'Live User',
        'email': 'live@test.com',
        'is_online': true,
        'last_login': Timestamp.fromDate(now),
      }, 'u3');
      expect(u.isOnline, isTrue);
      expect(u.lastLogin, isNotNull);
    });
  });

  group('AppointmentModel', () {
    test('round-trips through toMap/fromMap', () {
      final date = DateTime(2030, 1, 2, 10, 30);
      final a = AppointmentModel(
        id: '',
        userId: 'u1',
        doctorId: 'd1',
        doctorName: 'Dr A',
        patientName: 'John Patient',
        patientEmail: 'john@example.com',
        specialty: 'Cardiology',
        date: date,
        status: 'booked',
        createdAt: DateTime(2029, 12, 1),
      );
      final back = AppointmentModel.fromMap(a.toMap(), 'a1');
      expect(back.id, 'a1');
      expect(back.doctorName, 'Dr A');
      expect(back.patientName, 'John Patient');
      expect(back.specialty, 'Cardiology');
      expect(back.date.isAtSameMomentAs(date), isTrue);
      expect(back.isCancelled, isFalse);
      expect(back.isConfirmed, isTrue);
    });

    test('does not crash on legacy docs without createdAt / doctorName', () {
      final a = AppointmentModel.fromMap({
        'userId': 'u',
        'doctorId': 'd',
        'date': Timestamp.fromDate(DateTime(2030)),
        'status': 'Cancelled',
      }, 'a');
      expect(a.doctorName, '');
      expect(a.isCancelled, isTrue); // case-insensitive
    });
  });
}
