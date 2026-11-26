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
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _presenceStream = _realtimeDb.getDoctorLivePresence(widget.doctor.id);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)), // Up to 60 days (F-20)
      selectableDayPredicate: (DateTime day) {
        // Gray out daysOff (F-20)
        final dayStr = SlotGenerator.formatDayString(day);
        if (widget.doctor.daysOff.contains(dayStr)) return false;
        final key = SlotGenerator.weekdayKey(day.weekday);
        final ranges = widget.doctor.schedule[key] ?? [];
        return ranges.isNotEmpty;
      },
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
        const SnackBar(content: Text('Veuillez sélectionner un créneau.')),
      );
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to book.')),
      );
      return;
    }

    // Modal Confirmation Dialog (F-22)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer le rendez-vous'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Médecin : ${widget.doctor.name}'),
            Text('Spécialité : ${widget.doctor.specialty}'),
            if (widget.doctor.clinicAddress.isNotEmpty)
              Text('Adresse : ${widget.doctor.clinicAddress}'),
            const SizedBox(height: 8),
            Text(
              'Date et heure : ${DateFormat.yMMMMEEEEd().add_jm().format(_selectedSlot!)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Motif de consultation (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer'),
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

      unawaited(_sqlService.syncAppointmentToSql({
        'id': apptId,
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
              'Rendez-vous confirmé pour ${DateFormat.yMMMd().add_jm().format(bookingDateTime)}.'),
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
                      backgroundColor:
                          AppTheme.primaryBlue.withValues(alpha: 0.12),
                      backgroundImage: widget.doctor.avatarUrl.isNotEmpty
                          ? NetworkImage(widget.doctor.avatarUrl)
                          : null,
                      child: widget.doctor.avatarUrl.isEmpty
                          ? Text(
                              widget.doctor.name.isNotEmpty
                                  ? widget.doctor.name[0].toUpperCase()
                                  : 'D',
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.doctor.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.doctor.specialty,
                            style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600),
                          ),
                          if (widget.doctor.clinicAddress.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 14, color: AppTheme.textMuted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.doctor.clinicAddress,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined,
                                  size: 14, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                widget.doctor.phone,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (widget.doctor.bio.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About Doctor',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.doctor.bio,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Live Realtime Database Status Badge
            Card(
              color: const Color(0xFFF0FDF4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: AppTheme.successGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StreamBuilder<DatabaseEvent>(
                        stream: _presenceStream,
                        builder: (context, snapshot) {
                          final value = snapshot.data?.snapshot.value;
                          final hasLive =
                              value is Map && value['isOnline'] != null;
                          final online =
                              value is Map && value['isOnline'] == true;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasLive
                                    ? (online
                                        ? 'Doctor is online now'
                                        : 'Doctor is currently offline')
                                    : 'Live status not available',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF166534)),
                              ),
                              const Text(
                                'You can book a slot regardless of live status',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF15803D)),
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

            // Date picker row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sélectionner la date',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(DateFormat.yMMMd().format(_selectedDate)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Real-time slot grid using bookedSlots subcollection
            Text(
              'Créneaux disponibles',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            StreamBuilder<Set<String>>(
              stream: _firestoreService.getDoctorBookedSlots(widget.doctor.id),
              builder: (context, snapshot) {
                final bookedKeys = snapshot.data ?? {};
                final slots = SlotGenerator.slotsFor(
                  doctor: widget.doctor,
                  day: _selectedDate,
                  bookedSlotKeys: bookedKeys,
                );

                if (slots.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Aucun créneau disponible pour cette date.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: slots.map((slot) {
                    final isSelected = _selectedSlot != null &&
                        _selectedSlot!.isAtSameMomentAs(slot);
                    final timeText = DateFormat.jm().format(slot);

                    return ChoiceChip(
                      label: Text(timeText),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryBlue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedSlot = selected ? slot : null;
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 36),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (widget.doctor.active &&
                        _selectedSlot != null &&
                        !_isBooking)
                    ? _bookAppointment
                    : null,
                child: _isBooking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(widget.doctor.active
                        ? 'Confirmer le créneau'
                        : 'Actuellement indisponible'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
