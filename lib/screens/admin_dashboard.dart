import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/doctor_model.dart';
import '../models/appointment_model.dart';
import 'login_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  void _showAddDoctorDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final firestoreService = FirestoreService();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Doctor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: specCtrl,
              decoration: const InputDecoration(labelText: 'Specialty'),
            ),
            TextField(
              controller: phoneCtrl,
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
              if (nameCtrl.text.isEmpty) return;
              final nav = Navigator.of(dialogContext);
              await firestoreService.addDoctor(
                DoctorModel(
                  id: '',
                  name: nameCtrl.text,
                  specialty: specCtrl.text,
                  phone: phoneCtrl.text,
                  available: true,
                ),
              );
              nav.pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final nav = Navigator.of(context);
                await AuthService().signOut();
                nav.pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Doctors'),
              Tab(text: 'Appointments'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            StreamBuilder<List<DoctorModel>>(
              stream: firestoreService.getDoctors(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final doctors = snapshot.data!;
                return ListView.builder(
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final doc = doctors[index];
                    return ListTile(
                      title: Text(doc.name),
                      subtitle: Text(doc.specialty),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => firestoreService.deleteDoctor(doc.id),
                      ),
                    );
                  },
                );
              },
            ),
            StreamBuilder<List<AppointmentModel>>(
              stream: firestoreService.getAllAppointments(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final appts = snapshot.data!;
                return ListView.builder(
                  itemCount: appts.length,
                  itemBuilder: (context, index) {
                    final appt = appts[index];
                    return ListTile(
                      title: Text('Appt ID: ${appt.id}'),
                      subtitle: Text(
                        'User: ${appt.userId}\nStatus: ${appt.status}',
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddDoctorDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
