import '../models/doctor_model.dart';
import '../models/appointment_model.dart';

/// Pure slot generation functions per Section 6.4 of the Cahier des charges.
///
/// Input: DoctorModel, target day (DateTime), set of already booked slot keys (yyyyMMddHHmm in UTC).
/// Output: List of available slot DateTime instances (in local/displayed time or UTC).
class SlotGenerator {
  /// Map day of week (DateTime.monday = 1 ... DateTime.sunday = 7) to schedule keys
  static String weekdayKey(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      default:
        return 'mon';
    }
  }

  /// Format date as YYYY-MM-DD string to check daysOff
  static String formatDayString(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Generates available slots for [doctor] on [day].
  ///
  /// - If [doctor.active] is false -> returns []
  /// - If [day] is in [doctor.daysOff] -> returns []
  /// - Iterates over doctor's schedule ranges for that weekday with step [doctor.slotDurationMin]
  /// - Filters out slots that are before [minLeadTime] (default: now + 1 hour)
  /// - Filters out slots whose slotKey (UTC yyyyMMddHHmm) is in [bookedSlotKeys]
  static List<DateTime> slotsFor({
    required DoctorModel doctor,
    required DateTime day,
    required Set<String> bookedSlotKeys,
    DateTime? currentTime,
    Duration minLeadTime = const Duration(hours: 1),
  }) {
    if (!doctor.active) return [];

    final dayStr = formatDayString(day);
    if (doctor.daysOff.contains(dayStr)) return [];

    final key = weekdayKey(day.weekday);
    final ranges = doctor.schedule[key] ?? [];
    if (ranges.isEmpty) return [];

    final now = currentTime ?? DateTime.now();
    final cutoff = now.add(minLeadTime);
    final stepMin = doctor.slotDurationMin > 0 ? doctor.slotDurationMin : 30;

    final List<DateTime> availableSlots = [];

    for (final range in ranges) {
      if (range.start.isEmpty || range.end.isEmpty) continue;

      final startParts = range.start.split(':');
      final endParts = range.end.split(':');
      if (startParts.length < 2 || endParts.length < 2) continue;

      final startHour = int.tryParse(startParts[0]);
      final startMinute = int.tryParse(startParts[1]);
      final endHour = int.tryParse(endParts[0]);
      final endMinute = int.tryParse(endParts[1]);

      if (startHour == null ||
          startMinute == null ||
          endHour == null ||
          endMinute == null) {
        continue;
      }

      var currentSlot = DateTime(
        day.year,
        day.month,
        day.day,
        startHour,
        startMinute,
      );

      final endSlot = DateTime(
        day.year,
        day.month,
        day.day,
        endHour,
        endMinute,
      );

      while (currentSlot.add(Duration(minutes: stepMin)).isBefore(endSlot) ||
          currentSlot.add(Duration(minutes: stepMin)).isAtSameMomentAs(endSlot)) {
        // Must be at least minLeadTime in the future
        if (currentSlot.isAfter(cutoff)) {
          final slotKey = AppointmentModel.formatSlotKey(currentSlot);
          if (!bookedSlotKeys.contains(slotKey)) {
            availableSlots.add(currentSlot);
          }
        }
        currentSlot = currentSlot.add(Duration(minutes: stepMin));
      }
    }

    availableSlots.sort((a, b) => a.compareTo(b));
    return availableSlots;
  }
}
