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
    });

    test('toMap/fromMap round-trip', () {
      final d = DoctorModel(
          id: 'x', name: 'Dr A', specialty: 'Cardio', phone: '123', available: false);
      final back = DoctorModel.fromMap(d.toMap(), 'x');
      expect(back.name, 'Dr A');
      expect(back.specialty, 'Cardio');
      expect(back.available, isFalse);
    });
  });

  group('UserModel', () {
    test('role defaults to user', () {
      expect(UserModel.fromMap({'name': 'N', 'email': 'e@x.com'}, 'u').role, 'user');
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
        date: date,
        status: 'booked',
        createdAt: DateTime(2029, 12, 1),
      );
      final back = AppointmentModel.fromMap(a.toMap(), 'a1');
      expect(back.id, 'a1');
      expect(back.doctorName, 'Dr A');
      expect(back.date.isAtSameMomentAs(date), isTrue);
      expect(back.isCancelled, isFalse);
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
