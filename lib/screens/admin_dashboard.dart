import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';
import '../models/doctor_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_utils.dart';
import 'login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _firestoreService = FirestoreService();
  late final Stream<List<DoctorModel>> _doctors = _firestoreService.getDoctors();
  late final Stream<List<AppointmentModel>> _appointments =
      _firestoreService.getAllAppointments();

  void _toast(String message, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppTheme.dangerRed : AppTheme.successGreen,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) _toast(describeError(e));
    }
  }

  Future<void> _confirmDelete(DoctorModel doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete doctor'),
        content: Text('Remove ${doc.name} from the directory?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _firestoreService.deleteDoctor(doc.id));
  }

  void _showAddDoctorDialog() {
    final nameCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Doctor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: specCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Specialty'),
            ),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final nav = Navigator.of(dialogContext);
              try {
                await _firestoreService.addDoctor(
                  DoctorModel(
                    id: '',
                    name: name,
                    specialty: specCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    available: true,
                  ),
                );
                nav.pop();
              } catch (e) {
                if (mounted) _toast(describeError(e));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) {
      nameCtrl.dispose();
      specCtrl.dispose();
      phoneCtrl.dispose();
    });
  }

  Future<void> _signOut() async {
    final nav = Navigator.of(context);
    await AuthService().signOut();
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              tooltip: 'Sign Out',
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Doctors'), Tab(text: 'Appointments')],
          ),
        ),
        body: TabBarView(
          children: [
            StreamBuilder<List<DoctorModel>>(
              stream: _doctors,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(describeError(snapshot.error!)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final doctors = snapshot.data!;
                if (doctors.isEmpty) {
                  return const Center(
                      child: Text('No doctors yet. Tap + to add one.'));
                }
                return ListView.builder(
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final doc = doctors[index];
                    return ListTile(
                      title: Text(doc.name),
                      subtitle: Text(doc.specialty),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: doc.available ? 'Available' : 'Unavailable',
                            child: Switch(
                              value: doc.available,
                              onChanged: (v) => _run(() => _firestoreService
                                  .setDoctorAvailability(doc.id, v)),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete doctor',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(doc),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            StreamBuilder<List<AppointmentModel>>(
              stream: _appointments,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(describeError(snapshot.error!)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final appts = snapshot.data!;
                if (appts.isEmpty) {
                  return const Center(child: Text('No appointments yet.'));
                }
                return ListView.builder(
                  itemCount: appts.length,
                  itemBuilder: (context, index) {
                    final appt = appts[index];
                    return ListTile(
                      leading: Icon(
                        appt.isCancelled
                            ? Icons.cancel_outlined
                            : Icons.event_available_outlined,
                        color: appt.isCancelled
                            ? AppTheme.dangerRed
                            : AppTheme.primaryBlue,
                      ),
                      title: Text(
                          '${appt.doctorName.isEmpty ? 'Doctor' : appt.doctorName} - ${DateFormat.yMMMd().add_jm().format(appt.date)}'),
                      subtitle: Text('Patient: ${appt.userId}\nStatus: ${appt.status}'),
                      isThreeLine: true,
                    );
                  },
                );
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Add doctor',
          onPressed: _showAddDoctorDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
