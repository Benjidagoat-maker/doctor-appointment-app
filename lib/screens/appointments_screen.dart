import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_utils.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _cancelAppointment(AppointmentModel appt) async {
    final now = DateTime.now();
    final hoursDiff = appt.date.difference(now).inHours;
    if (hoursDiff < 48) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Appointments can only be cancelled at least 48 hours in advance.',
          ),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text(
          'Cancel your appointment with ${appt.doctorName.isNotEmpty ? appt.doctorName : "this doctor"}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep appointment'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final user = _authService.currentUser;
      await _firestoreService.cancelAppointment(
        appointmentId: appt.id,
        cancelledByUid: user?.uid ?? appt.userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment cancelled.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(e)),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Appointments')),
        body: const Center(child: Text('Please sign in to view appointments.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          indicatorColor: AppTheme.primaryBlue,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: StreamBuilder<List<AppointmentModel>>(
            stream: _firestoreService.getUserAppointments(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      describeError(snapshot.error ?? 'Unknown error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.dangerRed),
                    ),
                  ),
                );
              }

              final appts = snapshot.data ?? [];
              final now = DateTime.now();

              // Categorize into the 3 tabs per F-25
              final upcoming =
                  appts
                      .where((a) => !a.isCancelled && a.date.isAfter(now))
                      .toList()
                    ..sort((a, b) => a.date.compareTo(b.date)); // chronological

              final past =
                  appts
                      .where(
                        (a) =>
                            !a.isCancelled &&
                            (a.date.isBefore(now) ||
                                a.isCompleted ||
                                a.isNoShow),
                      )
                      .toList()
                    ..sort(
                      (a, b) => b.date.compareTo(a.date),
                    ); // reverse chronological

              final cancelled = appts.where((a) => a.isCancelled).toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildAppointmentList(upcoming, isUpcoming: true),
                  _buildAppointmentList(past),
                  _buildAppointmentList(cancelled),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentList(
    List<AppointmentModel> items, {
    bool isUpcoming = false,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'No appointments in this section yet.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final appt = items[index];
        final canCancel = isUpcoming && appt.date.difference(now).inHours >= 48;
        final title = appt.doctorName.isNotEmpty ? appt.doctorName : 'Docteur';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          (appt.isCancelled
                                  ? AppTheme.dangerRed
                                  : AppTheme.primaryBlue)
                              .withValues(alpha: 0.1),
                      child: Icon(
                        appt.isCancelled
                            ? Icons.event_busy_outlined
                            : Icons.calendar_today_rounded,
                        color: appt.isCancelled
                            ? AppTheme.dangerRed
                            : AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          if (appt.specialty.isNotEmpty &&
                              appt.specialty != 'General')
                            Text(
                              appt.specialty,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateFormat.yMMMMEEEEd().add_jm().format(appt.date),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (appt.reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Reason: ${appt.reason}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
                if (canCancel) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _cancelAppointment(appt),
                      icon: const Icon(Icons.event_busy_outlined, size: 18),
                      label: const Text('Cancel appointment'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.dangerRed,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
