import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/appointment_model.dart';
import '../theme/app_theme.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final authService = AuthService();
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
      ),
      body: user == null
          ? const Center(child: Text('Please log in to view appointments.'))
          : StreamBuilder<List<AppointmentModel>>(
              stream: firestoreService.getUserAppointments(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final appts = snapshot.data ?? [];
                if (appts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No appointments booked yet.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: appts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final appt = appts[index];
                    final isCancelled = appt.status.toLowerCase() == 'cancelled';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isCancelled
                                  ? AppTheme.dangerRed.withOpacity(0.1)
                                  : AppTheme.primaryBlue.withOpacity(0.1),
                              child: Icon(
                                isCancelled ? Icons.cancel_outlined : Icons.calendar_today_rounded,
                                color: isCancelled ? AppTheme.dangerRed : AppTheme.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat.yMMMd().add_jm().format(appt.date),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Doctor ID: ${appt.doctorId}',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            if (isCancelled)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.dangerRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Cancelled',
                                  style: TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              )
                            else
                              TextButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Cancel Appointment'),
                                      content: const Text('Are you sure you want to cancel this visit?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Yes, Cancel'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await firestoreService.cancelAppointment(appt.id);
                                  }
                                },
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.w600),
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
