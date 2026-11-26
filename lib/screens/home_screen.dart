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
import '../widgets/patient_bottom_navigation.dart';

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
  late final Stream<List<DoctorModel>> _doctorsStream = _firestoreService
      .getDoctors();

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
    final recordsFuture = _sqlService.isConfigured
        ? _sqlService.fetchSqlMedicalRecords()
        : null;

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
                          const Icon(
                            Icons.storage_rounded,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SQL Medical Records',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      Text(
                        _sqlService.isConfigured
                            ? 'Connected to your secure medical records service.'
                            : 'Medical records service is not configured.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      if (!_sqlService.isConfigured)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'No medical records are available because no SQL service is connected.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else if (snapshot.connectionState ==
                          ConnectionState.waiting)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (snapshot.hasError)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Medical records could not be loaded. Please try again later.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else if (!snapshot.hasData || snapshot.data!.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text('No medical records found.'),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            controller: controller,
                            itemCount: snapshot.data!.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) {
                              final item = snapshot.data![index];
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFEFF6FF),
                                    child: Icon(
                                      Icons.folder_shared_outlined,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                  title: Text(
                                    item['diagnosis']?.toString() ??
                                        'Medical Checkup',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${item['doctor_name'] ?? 'Doctor'} • ${item['record_date'] ?? ''}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Chip(
                                    label: Text(
                                      item['status']?.toString() ?? 'Active',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.successGreen,
                                      ),
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

  void _onPatientNavigation(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
      );
    } else if (index == 2) {
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
                leading: const Icon(Icons.folder_shared_outlined),
                title: const Text('Medical records'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSqlRecordsSheet(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _signOut();
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final accountName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim().split(RegExp(r'\s+')).first
        : user?.email?.split('@').first ?? 'there';

    return Scaffold(
      backgroundColor: AppTheme.patientBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $accountName',
                        style: const TextStyle(
                          color: AppTheme.patientMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Find your doctor',
                        style: TextStyle(
                          color: AppTheme.patientInk,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(
                          () => _searchQuery = value.trim().toLowerCase(),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search doctor or specialty',
                          hintStyle: const TextStyle(
                            color: AppTheme.patientMuted,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppTheme.patientMuted,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppTheme.patientBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppTheme.patientBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppTheme.patientPrimary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _specialties.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final specialty = _specialties[index];
                            final selected = _selectedSpecialty == specialty;
                            return ChoiceChip(
                              label: Text(specialty),
                              selected: selected,
                              showCheckmark: false,
                              onSelected: (_) => setState(
                                () => _selectedSpecialty = specialty,
                              ),
                              backgroundColor: Colors.white,
                              selectedColor: AppTheme.patientPrimary,
                              side: BorderSide(
                                color: selected
                                    ? AppTheme.patientPrimary
                                    : AppTheme.patientBorder,
                              ),
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : AppTheme.patientInk,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Doctors',
                        style: TextStyle(
                          color: AppTheme.patientInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                            child: Text(
                              describeError(snapshot.error!),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.patientPrimary,
                          ),
                        );
                      }

                      final filtered = snapshot.data!.where((doctor) {
                        final matchesQuery =
                            doctor.name.toLowerCase().contains(_searchQuery) ||
                            doctor.specialty.toLowerCase().contains(
                              _searchQuery,
                            ) ||
                            doctor.phone.toLowerCase().contains(_searchQuery);
                        final matchesSpecialty =
                            _selectedSpecialty == 'All' ||
                            doctor.specialty.toLowerCase() ==
                                _selectedSpecialty.toLowerCase();
                        return matchesQuery && matchesSpecialty;
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: AppTheme.patientMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No doctors registered yet.'
                                    : 'No matching doctors found.',
                                style: const TextStyle(
                                  color: AppTheme.patientMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doctor = filtered[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppTheme.patientBorder),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DoctorDetailsScreen(doctor: doctor),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: AppTheme.patientTint,
                                          backgroundImage:
                                              doctor.avatarUrl.isNotEmpty
                                              ? NetworkImage(doctor.avatarUrl)
                                              : null,
                                          child: doctor.avatarUrl.isEmpty
                                              ? Text(
                                                  doctor.name.isNotEmpty
                                                      ? doctor.name[0]
                                                            .toUpperCase()
                                                      : 'D',
                                                  style: const TextStyle(
                                                    color:
                                                        AppTheme.patientPrimary,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: _PresenceDot(
                                            doctorId: doctor.id,
                                            fallbackOnline: doctor.available,
                                            service: _realtimeDb,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doctor.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppTheme.patientInk,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            doctor.specialty,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppTheme.patientMuted,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: doctor.active
                                          ? () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    DoctorDetailsScreen(
                                                      doctor: doctor,
                                                    ),
                                              ),
                                            )
                                          : null,
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.patientPrimary,
                                        disabledBackgroundColor:
                                            AppTheme.patientDisabled,
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor:
                                            AppTheme.patientMuted,
                                        minimumSize: const Size(68, 44),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Book'),
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
          ),
        ),
      ),
      bottomNavigationBar: PatientBottomNavigationBar(
        selectedIndex: 0,
        onTap: _onPatientNavigation,
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
  late final Stream<DatabaseEvent> _stream = widget.service
      .getDoctorLivePresence(widget.doctorId);

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
