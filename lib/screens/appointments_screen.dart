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
              'L\'annulation n\'est permise que jusqu\'à 48 h avant le rendez-vous.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler le rendez-vous'),
        content: Text(
          'Voulez-vous vraiment annuler votre consultation avec ${appt.doctorName.isNotEmpty ? appt.doctorName : "ce médecin"} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, annuler'),
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
          content: Text('Rendez-vous annulé avec succès.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
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
    final user = _authService.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mes rendez-vous')),
        body: const Center(child: Text('Veuillez vous connecter.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes rendez-vous'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          indicatorColor: AppTheme.primaryBlue,
          tabs: const [
            Tab(text: 'À venir'),
            Tab(text: 'Passés'),
            Tab(text: 'Annulés'),
          ],
        ),
      ),
      body: StreamBuilder<List<AppointmentModel>>(
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
          final upcoming = appts
              .where((a) => !a.isCancelled && a.date.isAfter(now))
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date)); // chronological

          final past = appts
              .where((a) =>
                  !a.isCancelled &&
                  (a.date.isBefore(now) || a.isCompleted || a.isNoShow))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date)); // reverse chronological

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
    );
  }

  Widget _buildAppointmentList(List<AppointmentModel> items,
      {bool isUpcoming = false}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Aucun rendez-vous dans cette section.',
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
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: (appt.isCancelled
                          ? AppTheme.dangerRed
                          : AppTheme.primaryBlue)
                      .withValues(alpha: 0.1),
                  child: Icon(
                    appt.isCancelled
                        ? Icons.cancel_outlined
                        : Icons.calendar_today_rounded,
                    color: appt.isCancelled
                        ? AppTheme.dangerRed
                        : AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                          if (appt.specialty.isNotEmpty &&
                              appt.specialty != 'General')
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                appt.specialty,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.yMMMMEEEEd().add_jm().format(appt.date),
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted),
                      ),
                      if (appt.reason.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Motif : ${appt.reason}',
                            style: const TextStyle(
                                fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
                if (canCancel)
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined,
                        color: AppTheme.dangerRed),
                    tooltip: 'Annuler ce rendez-vous',
                    onPressed: () => _cancelAppointment(appt),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
