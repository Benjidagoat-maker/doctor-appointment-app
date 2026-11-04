import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/realtime_db_service.dart';
import '../services/sql_api_service.dart';
import '../models/doctor_model.dart';
import '../theme/app_theme.dart';
import 'doctor_details_screen.dart';
import 'appointments_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _realtimeDb = RealtimeDbService();
  final _sqlService = SqlApiService();
  String _searchQuery = '';

  void _showSqlRecordsSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, controller) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _sqlService.fetchSqlMedicalRecords(_authService.currentUser?.uid ?? 'guest'),
              builder: (context, snapshot) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.storage_rounded, color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          Text(
                            'SQL Medical Records',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      Text(
                        'Synchronized via REST API (PostgreSQL / MySQL / Cloud SQL)',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Expanded(child: Center(child: CircularProgressIndicator()))
                      else if (!snapshot.hasData || snapshot.data!.isEmpty)
                        const Expanded(child: Center(child: Text('No medical records found.')))
                      else
                        Expanded(
                          child: ListView.separated(
                            controller: controller,
                            itemCount: snapshot.data!.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, index) {
                              final item = snapshot.data![index];
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFEFF6FF),
                                    child: Icon(Icons.folder_shared_outlined, color: AppTheme.primaryBlue),
                                  ),
                                  title: Text(
                                    item['diagnosis'] ?? 'Medical Checkup',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    '${item['doctor']} • ${item['date']}\nDB: ${item['source']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Chip(
                                    label: Text(
                                      item['status'] ?? 'Active',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.successGreen),
                                    ),
                                    backgroundColor: AppTheme.successGreen.withOpacity(0.1),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Your Doctor'),
        actions: [
          // Button to view SQL Records
          IconButton(
            tooltip: 'View SQL Connected Records',
            icon: const Icon(Icons.storage_outlined),
            onPressed: () => _showSqlRecordsSheet(context),
          ),
          // Button to view Booked Appointments
          IconButton(
            tooltip: 'My Appointments',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final nav = Navigator.of(context);
              await _authService.signOut();
              nav.pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            color: Colors.white,
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by doctor name or specialty...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),

          // Doctor List
          Expanded(
            child: StreamBuilder<List<DoctorModel>>(
              stream: _firestoreService.getDoctors(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading doctors: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final doctors = snapshot.data ?? [];
                final filtered = doctors.where((doc) {
                  return doc.name.toLowerCase().contains(_searchQuery) ||
                      doc.specialty.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty ? 'No doctors registered yet.' : 'No matching doctors found.',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DoctorDetailsScreen(doctor: doc),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // Avatar with Realtime DB Presence indicator
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.12),
                                    child: Text(
                                      doc.name.isNotEmpty ? doc.name[0].toUpperCase() : 'D',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  // Realtime presence badge from Firebase Realtime Database
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: StreamBuilder(
                                      stream: _realtimeDb.getDoctorLivePresence(doc.id),
                                      builder: (context, presenceSnap) {
                                        bool isLiveOnline = doc.available;
                                        if (presenceSnap.hasData && presenceSnap.data?.snapshot.value != null) {
                                          final val = presenceSnap.data!.snapshot.value;
                                          if (val is Map && val['isOnline'] != null) {
                                            isLiveOnline = val['isOnline'] == true;
                                          }
                                        }
                                        return Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: isLiveOnline ? AppTheme.successGreen : Colors.grey,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      doc.specialty,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.primaryBlue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 14, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          doc.phone,
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: doc.available
                                      ? AppTheme.successGreen.withOpacity(0.12)
                                      : AppTheme.dangerRed.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  doc.available ? 'Available' : 'Booked',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: doc.available ? AppTheme.successGreen : AppTheme.dangerRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
