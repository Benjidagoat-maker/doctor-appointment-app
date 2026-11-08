import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../models/doctor_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/realtime_db_service.dart';
import '../services/sql_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_utils.dart';
import 'appointments_screen.dart';
import 'doctor_details_screen.dart';
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
  final _searchController = TextEditingController();

  // Created once. Creating the stream inside build() would re-subscribe to
  // Firestore (and flash a spinner) on every keystroke in the search box.
  late final Stream<List<DoctorModel>> _doctorsStream =
      _firestoreService.getDoctors();

  String _searchQuery = '';
  String _selectedSpecialty = 'All';
  final List<String> _specialties = const [
    'All',
    'Cardiology',
    'Dermatology',
    'Neurology',
    'Pediatrics',
    'Orthopedics',
    'General Medicine',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSqlRecordsSheet(BuildContext context) {
    // One fetch per opening - not one per rebuild while the sheet is dragged.
    final recordsFuture = _sqlService
        .fetchSqlMedicalRecords(_authService.currentUser?.uid ?? 'guest');

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
              future: recordsFuture,
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
                          const Icon(Icons.storage_rounded,
                              color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          Text('SQL Medical Records',
                              style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                      Text(
                        _sqlService.isConfigured
                            ? 'Synchronized via REST API (PostgreSQL / MySQL / Cloud SQL)'
                            : 'Demo data - no SQL backend is configured yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Expanded(
                            child: Center(child: CircularProgressIndicator()))
                      else if (!snapshot.hasData || snapshot.data!.isEmpty)
                        const Expanded(
                            child: Center(child: Text('No medical records found.')))
                      else
                        Expanded(
                          child: ListView.separated(
                            controller: controller,
                            itemCount: snapshot.data!.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) {
                              final item = snapshot.data![index];
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFEFF6FF),
                                    child: Icon(Icons.folder_shared_outlined,
                                        color: AppTheme.primaryBlue),
                                  ),
                                  title: Text(
                                    item['diagnosis'] ?? 'Medical Checkup',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    '${item['doctor']} • ${item['date']}\n${item['source']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Chip(
                                    label: Text(
                                      item['status'] ?? 'Active',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.successGreen),
                                    ),
                                    backgroundColor: AppTheme.successGreen
                                        .withValues(alpha: 0.1),
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

  Future<void> _signOut() async {
    final nav = Navigator.of(context);
    await _authService.signOut();
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Your Doctor'),
        actions: [
          IconButton(
            tooltip: 'View SQL Connected Records',
            icon: const Icon(Icons.storage_outlined),
            onPressed: () => _showSqlRecordsSheet(context),
          ),
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
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by doctor name, specialty or phone...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: _specialties.map((spec) {
                final isSelected = _selectedSpecialty == spec;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(spec),
                    selected: isSelected,
                    selectedColor: AppTheme.v22ElectricBlue,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.v22ElectricBlue
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    onSelected: (_) => setState(() => _selectedSpecialty = spec),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<DoctorModel>>(
              stream: _doctorsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(describeError(snapshot.error!),
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final filtered = snapshot.data!.where((doc) {
                  final matchesQuery = doc.name.toLowerCase().contains(_searchQuery) ||
                      doc.specialty.toLowerCase().contains(_searchQuery) ||
                      doc.phone.toLowerCase().contains(_searchQuery);
                  final matchesSpecialty = _selectedSpecialty == 'All' ||
                      doc.specialty.toLowerCase() == _selectedSpecialty.toLowerCase();
                  return matchesQuery && matchesSpecialty;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No doctors registered yet.'
                              : 'No matching doctors found.',
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
                              builder: (_) => DoctorDetailsScreen(doctor: doc)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: AppTheme.primaryBlue
                                        .withValues(alpha: 0.12),
                                    child: Text(
                                      doc.name.isNotEmpty
                                          ? doc.name[0].toUpperCase()
                                          : 'D',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: _PresenceDot(
                                      doctorId: doc.id,
                                      fallbackOnline: doc.available,
                                      service: _realtimeDb,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(doc.name,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(doc.specialty,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.primaryBlue,
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined,
                                            size: 14, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Text(doc.phone,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textMuted)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (doc.available
                                          ? AppTheme.successGreen
                                          : AppTheme.dangerRed)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  doc.available ? 'Available' : 'Unavailable',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: doc.available
                                        ? AppTheme.successGreen
                                        : AppTheme.dangerRed,
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

/// Live presence badge. Owns its stream so it is subscribed once per card,
/// not re-created on every parent rebuild (e.g. while typing in search).
class _PresenceDot extends StatefulWidget {
  final String doctorId;
  final bool fallbackOnline;
  final RealtimeDbService service;

  const _PresenceDot({
    required this.doctorId,
    required this.fallbackOnline,
    required this.service,
  });

  @override
  State<_PresenceDot> createState() => _PresenceDotState();
}

class _PresenceDotState extends State<_PresenceDot> {
  late final Stream<DatabaseEvent> _stream =
      widget.service.getDoctorLivePresence(widget.doctorId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _stream,
      builder: (context, snap) {
        var online = widget.fallbackOnline;
        final value = snap.data?.snapshot.value;
        if (value is Map && value['isOnline'] != null) {
          online = value['isOnline'] == true;
        }
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: online ? AppTheme.successGreen : Colors.grey,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      },
    );
  }
}
