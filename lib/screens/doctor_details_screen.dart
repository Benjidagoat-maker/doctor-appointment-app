import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/doctor_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/realtime_db_service.dart';
import '../services/sql_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_utils.dart';
import '../utils/slot_generator.dart';

class DoctorDetailsScreen extends StatefulWidget {
  final DoctorModel doctor;

  const DoctorDetailsScreen({super.key, required this.doctor});

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final RealtimeDbService _realtimeDb = RealtimeDbService();
  final SqlApiService _sqlService = SqlApiService();

  late DateTime _selectedDate;
  DateTime? _selectedSlot;
  final TextEditingController _reasonController = TextEditingController();
  bool _isBooking = false;
  Stream<DatabaseEvent>? _presenceStream;

  @override
  void initState() {
    super.initState();
    _selectedDate = _firstSelectableDate();
    _presenceStream = _realtimeDb.getDoctorLivePresence(widget.doctor.id);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool _isSelectableDay(DateTime day) {
    final dayString = SlotGenerator.formatDayString(day);
    if (widget.doctor.daysOff.contains(dayString)) return false;
    final weekday = SlotGenerator.weekdayKey(day.weekday);
    return (widget.doctor.schedule[weekday] ?? []).isNotEmpty;
  }

  DateTime _firstSelectableDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var offset = 0; offset <= 60; offset++) {
      final date = today.add(Duration(days: offset));
      if (_isSelectableDay(date)) return date;
    }
    return today;
  }

  List<DateTime> _availableDates() {
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dates = <DateTime>[];
    for (var offset = 0; offset <= 60 && dates.length < 7; offset++) {
      final date = start.add(Duration(days: offset));
      if (_isSelectableDay(date)) dates.add(date);
    }
    return dates;
  }

  void _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      selectableDayPredicate: _isSelectableDay,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedSlot = null; // reset slot selection
      });
    }
  }

  void _bookAppointment() async {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an appointment time first.')),
      );
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in to book.')));
      return;
    }

    // Modal Confirmation Dialog (F-22)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doctor: ${widget.doctor.name}'),
            Text('Specialty: ${widget.doctor.specialty}'),
            if (widget.doctor.clinicAddress.isNotEmpty)
              Text('Address: ${widget.doctor.clinicAddress}'),
            const SizedBox(height: 8),
            Text(
              'Date and time: ${DateFormat.yMMMMEEEEd().add_jm().format(_selectedSlot!)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for visit (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isBooking = true);
    final bookingDateTime = _selectedSlot!;

    try {
      final apptId = await _firestoreService.bookAppointment(
        doctorId: widget.doctor.id,
        date: bookingDateTime,
        reason: _reasonController.text.trim(),
      );

      // Best-effort RTDB & SQL sync
      try {
        await _realtimeDb.sendRealtimeNotification(
          recipientUid: user.uid,
          title: 'Appointment Booked',
          message:
              'Your visit with ${widget.doctor.name} is confirmed for ${DateFormat.yMMMd().add_jm().format(bookingDateTime)}',
        );
      } catch (e) {
        debugPrint('Realtime notification skipped: $e');
      }

      unawaited(
        _sqlService.syncAppointmentToSql({
          'id': apptId,
          'userId': user.uid,
          'doctorId': widget.doctor.id,
          'doctorName': widget.doctor.name,
          'date': bookingDateTime.toIso8601String(),
          'status': 'confirmed',
        }),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Appointment confirmed for ${DateFormat.yMMMd().add_jm().format(bookingDateTime)}.',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(e)),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableDates = _availableDates();

    return Scaffold(
      backgroundColor: AppTheme.patientBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              tooltip: 'Back',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: AppTheme.patientBorder,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Book appointment',
                              style: TextStyle(
                                color: AppTheme.patientInk,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppTheme.patientBorder),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: AppTheme.patientTint,
                                backgroundImage:
                                    widget.doctor.avatarUrl.isNotEmpty
                                    ? NetworkImage(widget.doctor.avatarUrl)
                                    : null,
                                child: widget.doctor.avatarUrl.isEmpty
                                    ? Text(
                                        widget.doctor.name.isNotEmpty
                                            ? widget.doctor.name[0]
                                                  .toUpperCase()
                                            : 'D',
                                        style: const TextStyle(
                                          color: AppTheme.patientPrimary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.doctor.name,
                                      style: const TextStyle(
                                        color: AppTheme.patientInk,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.doctor.specialty,
                                      style: const TextStyle(
                                        color: AppTheme.patientMuted,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (widget.doctor.clinicAddress.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 5),
                                        child: Text(
                                          widget.doctor.clinicAddress,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.patientMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              StreamBuilder<DatabaseEvent>(
                                stream: _presenceStream,
                                builder: (context, snapshot) {
                                  final value = snapshot.data?.snapshot.value;
                                  final online = value is Map
                                      ? value['isOnline'] == true
                                      : widget.doctor.active;
                                  return Tooltip(
                                    message: online
                                        ? 'Doctor online'
                                        : 'Doctor offline',
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: online
                                            ? AppTheme.patientPrimary
                                            : AppTheme.patientMuted,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        if (widget.doctor.bio.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            widget.doctor.bio,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.patientMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Date',
                                style: TextStyle(
                                  color: AppTheme.patientInk,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: availableDates.isEmpty
                                  ? null
                                  : _pickDate,
                              icon: const Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                              ),
                              label: Text(
                                DateFormat('MMM d').format(_selectedDate),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.patientPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 64,
                          child: availableDates.isEmpty
                              ? const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'No dates available for this doctor.',
                                    style: TextStyle(
                                      color: AppTheme.patientMuted,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: availableDates.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 6),
                                  itemBuilder: (context, index) {
                                    final date = availableDates[index];
                                    final selected = date.isAtSameMomentAs(
                                      _selectedDate,
                                    );
                                    return SizedBox(
                                      width: 44,
                                      child: Material(
                                        color: selected
                                            ? AppTheme.patientPrimary
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          side: BorderSide(
                                            color: selected
                                                ? AppTheme.patientPrimary
                                                : AppTheme.patientBorder,
                                          ),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () => setState(() {
                                            _selectedDate = date;
                                            _selectedSlot = null;
                                          }),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                DateFormat('E').format(date),
                                                style: TextStyle(
                                                  color: selected
                                                      ? Colors.white
                                                      : AppTheme.patientMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                DateFormat('d').format(date),
                                                style: TextStyle(
                                                  color: selected
                                                      ? Colors.white
                                                      : AppTheme.patientInk,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Time',
                          style: TextStyle(
                            color: AppTheme.patientInk,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        StreamBuilder<Set<String>>(
                          stream: _firestoreService.getDoctorBookedSlots(
                            widget.doctor.id,
                          ),
                          builder: (context, snapshot) {
                            final slots = SlotGenerator.slotsFor(
                              doctor: widget.doctor,
                              day: _selectedDate,
                              bookedSlotKeys: snapshot.data ?? {},
                            );

                            if (slots.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: AppTheme.patientBorder,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'No available times for this date.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.patientMuted,
                                  ),
                                ),
                              );
                            }

                            return GridView.count(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 2.1,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: slots.map((slot) {
                                final selected =
                                    _selectedSlot != null &&
                                    _selectedSlot!.isAtSameMomentAs(slot);
                                return OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _selectedSlot = slot),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: selected
                                        ? AppTheme.patientPrimary
                                        : Colors.white,
                                    foregroundColor: selected
                                        ? Colors.white
                                        : AppTheme.patientInk,
                                    side: BorderSide(
                                      color: selected
                                          ? AppTheme.patientPrimary
                                          : AppTheme.patientBorder,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(DateFormat('HH:mm').format(slot)),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.patientTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Instantly confirmed. Free cancellation up to 48 hours before.',
                            style: TextStyle(
                              color: Color(0xFF0B3F3B),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: AppTheme.patientBorder),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed:
                          widget.doctor.active &&
                              _selectedSlot != null &&
                              !_isBooking
                          ? _bookAppointment
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.patientPrimary,
                        disabledBackgroundColor: AppTheme.patientDisabled,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: AppTheme.patientMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isBooking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.doctor.active
                                  ? 'Confirm appointment'
                                  : 'Unavailable right now',
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
