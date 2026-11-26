import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_utils.dart';
import '../widgets/patient_bottom_navigation.dart';
import 'login_screen.dart';

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
            'Appointments can only be cancelled 48 hours in advance.',
          ),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel appointment'),
        content: Text(
          'Are you sure you want to cancel your appointment with ${appt.doctorName.isNotEmpty ? appt.doctorName : "this doctor"}?',
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
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _firestoreService.cancelAppointment(appointmentId: appt.id);
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

  void _showProfileSheet() {
    final user = _authService.currentUser;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.patientTint,
                child: Icon(
                  Icons.person_outline,
                  color: AppTheme.patientPrimary,
                ),
              ),
              title: Text(
                user?.displayName?.trim().isNotEmpty == true
                    ? user!.displayName!
                    : 'Your profile',
              ),
              subtitle: Text(user?.email ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _authService.signOut();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onPatientNavigation(int index) {
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (index == 2) {
      _showProfileSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.patientBackground,
        body: const Center(child: Text('Please sign in to view appointments.')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.patientBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 18),
                  child: Text(
                    'My appointments',
                    style: TextStyle(
                      color: AppTheme.patientInk,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4ECEA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: AppTheme.patientInk,
                      unselectedLabelColor: AppTheme.patientMuted,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(text: 'Upcoming'),
                        Tab(text: 'Past'),
                        Tab(text: 'Cancelled'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<AppointmentModel>>(
                    stream: _firestoreService.getUserAppointments(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.patientPrimary,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              describeError(snapshot.error ?? 'Unknown error'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.dangerRed),
                            ),
                          ),
                        );
                      }

                      final appointments = snapshot.data ?? [];
                      final now = DateTime.now();
                      final upcoming =
                          appointments
                              .where(
                                (appointment) =>
                                    !appointment.isCancelled &&
                                    appointment.date.isAfter(now),
                              )
                              .toList()
                            ..sort((a, b) => a.date.compareTo(b.date));
                      final past =
                          appointments
                              .where(
                                (appointment) =>
                                    !appointment.isCancelled &&
                                    (appointment.date.isBefore(now) ||
                                        appointment.isCompleted ||
                                        appointment.isNoShow),
                              )
                              .toList()
                            ..sort((a, b) => b.date.compareTo(a.date));
                      final cancelled =
                          appointments
                              .where((appointment) => appointment.isCancelled)
                              .toList()
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: PatientBottomNavigationBar(
        selectedIndex: 1,
        onTap: _onPatientNavigation,
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
              size: 48,
              color: AppTheme.patientMuted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              isUpcoming
                  ? 'No upcoming appointments.'
                  : 'No appointments in this section.',
              style: const TextStyle(
                color: AppTheme.patientMuted,
                fontSize: 15,
              ),
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
        final title = appt.doctorName.isNotEmpty ? appt.doctorName : 'Doctor';
        final statusLabel = appt.isCancelled
            ? 'Cancelled'
            : appt.isCompleted
            ? 'Completed'
            : appt.isNoShow
            ? 'No-show'
            : 'Confirmed';
        final statusColor = appt.isCancelled
            ? AppTheme.patientMuted
            : AppTheme.patientPrimary;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.patientBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.patientInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: appt.isCancelled
                          ? AppTheme.patientDisabled
                          : AppTheme.patientTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${appt.specialty} · ${DateFormat('EEE d, HH:mm').format(appt.date.toLocal())}',
                style: const TextStyle(
                  color: AppTheme.patientMuted,
                  fontSize: 14,
                ),
              ),
              if (appt.reason.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  appt.reason,
                  style: const TextStyle(
                    color: AppTheme.patientMuted,
                    fontSize: 13,
                  ),
                ),
              ],
              if (canCancel) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _cancelAppointment(appt),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dangerRed,
                    side: const BorderSide(color: AppTheme.dangerRed),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel appointment',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
