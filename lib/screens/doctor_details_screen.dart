import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/doctor_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/realtime_db_service.dart';
import '../services/sql_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_utils.dart';

class DoctorDetailsScreen extends StatefulWidget {
  final DoctorModel doctor;
  const DoctorDetailsScreen({super.key, required this.doctor});

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _realtimeDb = RealtimeDbService();
  final _sqlService = SqlApiService();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  bool _isBooking = false;
  late final Stream<DatabaseEvent> _presenceStream =
      _realtimeDb.getDoctorLivePresence(widget.doctor.id);

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _bookAppointment() async {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to book.')),
      );
      return;
    }

    setState(() => _isBooking = true);
    final bookingDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      // 1. The booking itself (Cloud Firestore) is the only critical step.
      await _firestoreService.bookAppointment(
        userId: user.uid,
        doctorId: widget.doctor.id,
        doctorName: widget.doctor.name,
        date: bookingDateTime,
      );

      // 2. Best-effort extras: a failure here must never fail the booking.
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
      unawaited(_sqlService.syncAppointmentToSql({
        'userId': user.uid,
        'doctorId': widget.doctor.id,
        'doctorName': widget.doctor.name,
        'date': bookingDateTime.toIso8601String(),
        'status': 'confirmed',
      }));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Appointment booked for ${DateFormat.yMMMd().add_jm().format(bookingDateTime)}.'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor Banner Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
                      child: Text(
                        widget.doctor.name.isNotEmpty ? widget.doctor.name[0].toUpperCase() : 'D',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.doctor.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.doctor.specialty,
                            style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 14, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(widget.doctor.phone, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Live Realtime Database Status Badge
            Card(
              color: const Color(0xFFF0FDF4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppTheme.successGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StreamBuilder<DatabaseEvent>(
                        stream: _presenceStream,
                        builder: (context, snapshot) {
                          final value = snapshot.data?.snapshot.value;
                          final hasLive = value is Map && value['isOnline'] != null;
                          final online = value is Map && value['isOnline'] == true;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasLive
                                    ? (online ? 'Doctor is online now' : 'Doctor is currently offline')
                                    : 'Live status not available',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF166534)),
                              ),
                              const Text(
                                'You can book a slot regardless of live status',
                                style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Select Date & Time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(DateFormat.yMMMd().format(_selectedDate)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time_outlined, size: 18),
                    label: Text(_selectedTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (widget.doctor.available && !_isBooking) ? _bookAppointment : null,
                child: _isBooking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(widget.doctor.available ? 'Confirm Appointment' : 'Currently Unavailable'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
