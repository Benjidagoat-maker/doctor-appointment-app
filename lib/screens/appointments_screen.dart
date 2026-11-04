import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_utils.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  Stream<List<AppointmentModel>>? _stream;

  @override
  void initState() {
    super.initState();
    final user = _authService.currentUser;
    if (user != null) _stream = _firestoreService.getUserAppointments(user.uid);
  }

  Future<void> _cancel(AppointmentModel appt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel this visit?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _firestoreService.cancelAppointment(appt.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(describeError(e)),
            backgroundColor: AppTheme.dangerRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Appointments')),
      body: _stream == null
          ? const Center(child: Text('Please log in to view appointments.'))
          : StreamBuilder<List<AppointmentModel>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text(describeError(snapshot.error!),
                          textAlign: TextAlign.center));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final appts = snapshot.data!;
                if (appts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_rounded,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No appointments booked yet.',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                final now = DateTime.now();
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: appts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final appt = appts[index];
                    final isCancelled = appt.isCancelled;
                    final isPast = !isCancelled && appt.date.isBefore(now);
                    final title =
                        appt.doctorName.isNotEmpty ? appt.doctorName : 'Doctor';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: (isCancelled
                                      ? AppTheme.dangerRed
                                      : AppTheme.primaryBlue)
                                  .withValues(alpha: 0.1),
                              child: Icon(
                                isCancelled
                                    ? Icons.cancel_outlined
                                    : Icons.calendar_today_rounded,
                                color: isCancelled
                                    ? AppTheme.dangerRed
                                    : AppTheme.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat.yMMMd().add_jm().format(appt.date),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            if (isCancelled || isPast)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isCancelled
                                          ? AppTheme.dangerRed
                                          : AppTheme.textMuted)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isCancelled ? 'Cancelled' : 'Past',
                                  style: TextStyle(
                                    color: isCancelled
                                        ? AppTheme.dangerRed
                                        : AppTheme.textMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              TextButton(
                                onPressed: () => _cancel(appt),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                      color: AppTheme.dangerRed,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
