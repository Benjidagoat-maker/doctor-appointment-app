import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_appointment_app/models/doctor_model.dart';
import 'package:doctor_appointment_app/models/appointment_model.dart';
import 'package:doctor_appointment_app/utils/slot_generator.dart';

void main() {
  group('SlotGenerator pure tests (Section 6.4 / Issue #8)', () {
    final baseDoctor = DoctorModel(
      id: 'doc1',
      name: 'Dr. Test',
      specialty: 'Cardiology',
      phone: '12345678',
      active: true,
      slotDurationMin: 30,
      daysOff: ['2026-12-25'], // Holiday
      schedule: {
        'mon': [
          const TimeRange(start: '09:00', end: '11:00'),
          const TimeRange(start: '14:00', end: '16:00'),
        ],
        'tue': [
          const TimeRange(start: '10:00', end: '12:00'),
        ],
        'wed': const [],
        'thu': [
          const TimeRange(start: '09:00', end: '10:00'),
        ],
        'fri': [
          const TimeRange(start: '23:00', end: '23:30'),
        ],
        'sat': const [],
        'sun': const [],
      },
    );

    // Monday 2026-11-23
    final testMonday = DateTime(2026, 11, 23);
    final mockCurrentTime = DateTime(2026, 11, 23, 7, 0); // 7:00 AM

    test('1. Generates correct slots for morning and afternoon ranges', () {
      final slots = SlotGenerator.slotsFor(
        doctor: baseDoctor,
        day: testMonday,
        bookedSlotKeys: {},
        currentTime: mockCurrentTime,
      );

      // Morning: 09:00, 09:30, 10:00, 10:30 (4 slots)
      // Afternoon: 14:00, 14:30, 15:00, 15:30 (4 slots)
      expect(slots.length, 8);
      expect(slots.first, DateTime(2026, 11, 23, 9, 0));
      expect(slots.last, DateTime(2026, 11, 23, 15, 30));
    });

    test('2. Returns empty list if doctor is inactive', () {
      final inactiveDoctor = DoctorModel(
        id: 'doc1',
        name: 'Dr. Inactive',
        specialty: 'General',
        phone: '123',
        active: false,
      );

      final slots = SlotGenerator.slotsFor(
        doctor: inactiveDoctor,
        day: testMonday,
        bookedSlotKeys: {},
        currentTime: mockCurrentTime,
      );

      expect(slots, isEmpty);
    });

    test('3. Returns empty list if day is in doctor.daysOff (e.g. holiday)', () {
      final christmas = DateTime(2026, 12, 25);
      final slots = SlotGenerator.slotsFor(
        doctor: baseDoctor,
        day: christmas,
        bookedSlotKeys: {},
        currentTime: DateTime(2026, 12, 24, 8, 0),
      );

      expect(slots, isEmpty);
    });

    test('4. Returns empty list if no schedule defined for the day', () {
      final wednesday = DateTime(2026, 11, 25); // Wednesday has empty schedule
      final slots = SlotGenerator.slotsFor(
        doctor: baseDoctor,
        day: wednesday,
        bookedSlotKeys: {},
        currentTime: mockCurrentTime,
      );

      expect(slots, isEmpty);
    });

    test('5. Excludes slots that are already booked in bookedSlots set', () {
      // Book 09:00 on Monday
      final bookedDateTime = DateTime(2026, 11, 23, 9, 0);
      final bookedKey = AppointmentModel.formatSlotKey(bookedDateTime);

      final slots = SlotGenerator.slotsFor(
        doctor: baseDoctor,
        day: testMonday,
        bookedSlotKeys: {bookedKey},
        currentTime: mockCurrentTime,
      );

      expect(slots.length, 7);
      expect(slots.any((s) => s.isAtSameMomentAs(bookedDateTime)), isFalse);
    });

    test('6. Filters out past slots and slots within the 1-hour lead time', () {
      // Current time is 09:15 AM
      // Min lead time cutoff is 10:15 AM
      final currentAtMorning = DateTime(2026, 11, 23, 9, 15);

      final slots = SlotGenerator.slotsFor(
        doctor: baseDoctor,
        day: testMonday,
        bookedSlotKeys: {},
        currentTime: currentAtMorning,
      );

      // Remaining morning slots: 10:30 (since 10:30 > 10:15)
      // + 4 afternoon slots = 5 total slots
      expect(slots.length, 5);
      expect(slots.first, DateTime(2026, 11, 23, 10, 30));
    });

    test('7. Respects custom slotDurationMin (e.g. 15 min slots)', () {
      final customDoctor = DoctorModel(
        id: 'doc2',
        name: 'Dr. Fast',
        specialty: 'Dermatology',
        phone: '123',
        slotDurationMin: 15,
        schedule: {
          'thu': [const TimeRange(start: '09:00', end: '10:00')],
        },
      );

      final thursday = DateTime(2026, 11, 26);
      final slots = SlotGenerator.slotsFor(
        doctor: customDoctor,
        day: thursday,
        bookedSlotKeys: {},
        currentTime: DateTime(2026, 11, 26, 7, 0),
      );

      // 09:00, 09:15, 09:30, 09:45 (4 slots)
      expect(slots.length, 4);
    });

    test('8. Handles single slot range matching exact duration', () {
      final friday = DateTime(2026, 11, 27);
      final slots = SlotGenerator.slotsFor(
        doctor: baseDoctor,
        day: friday,
        bookedSlotKeys: {},
        currentTime: DateTime(2026, 11, 27, 20, 0),
      );

      // 23:00 to 23:30 = 1 slot (23:00)
      expect(slots.length, 1);
      expect(slots.first, DateTime(2026, 11, 27, 23, 0));
    });

    test('9. Slot formatting produces deterministic UTC keys', () {
      final dt = DateTime.utc(2026, 11, 23, 9, 30);
      final key = AppointmentModel.formatSlotKey(dt);
      expect(key, '202611230930');
    });

    test('10. Status normalization conforms to Cahier des charges 6.2', () {
      expect(AppointmentModel.normalizeStatus('booked'), 'confirmed');
      expect(AppointmentModel.normalizeStatus('pending'), 'confirmed');
      expect(AppointmentModel.normalizeStatus('Cancelled'), 'cancelled');
      expect(AppointmentModel.normalizeStatus('completed'), 'completed');
      expect(AppointmentModel.normalizeStatus('no_show'), 'no_show');
    });
  });
}
