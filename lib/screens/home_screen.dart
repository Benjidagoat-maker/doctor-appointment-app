import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/doctor_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/realtime_db_service.dart';
import '../services/sql_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_utils.dart';
import 'doctor_details_screen.dart';

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
    // One fetch per opening - not one per rebuild while the sheet is dragged.
    final recordsFuture = _sqlService.fetchSqlMedicalRecords(
      _authService.currentUser?.uid ?? 'guest',
    );

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
                            ? 'Synchronized via REST API (PostgreSQL / MySQL / Cloud SQL)'
                            : 'Demo data - no SQL backend is configured yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
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
                                    item['diagnosis'] ?? 'Medical Checkup',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Care'),
        actions: [
          IconButton(
            tooltip: 'View SQL Connected Records',
            icon: const Icon(Icons.storage_outlined),
            onPressed: () => _showSqlRecordsSheet(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find the right care for you',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Browse trusted doctors and book a time that works for you.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search doctors or specialties',
                    prefixIcon: const Icon(Icons.search_rounded),
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
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  children: _specialties.map((spec) {
                    final isSelected = _selectedSpecialty == spec;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(spec),
                        selected: isSelected,
                        showCheckmark: false,
                        selectedColor: AppTheme.primaryBlue,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : const Color(0xFFDCE7E4),
                          ),
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedSpecialty = spec),
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
                          child: Text(
                            describeError(snapshot.error!),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final filtered = snapshot.data!.where((doc) {
                      final matchesQuery =
                          doc.name.toLowerCase().contains(_searchQuery) ||
                          doc.specialty.toLowerCase().contains(_searchQuery) ||
                          doc.phone.toLowerCase().contains(_searchQuery);
                      final matchesSpecialty =
                          _selectedSpecialty == 'All' ||
                          doc.specialty.toLowerCase() ==
                              _selectedSpecialty.toLowerCase();
                      return matchesQuery && matchesSpecialty;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 56,
                              color: Colors.grey.shade400,
                            ),
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

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 740) {
                          return GridView.builder(
                            padding: const EdgeInsets.all(20),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 560,
                                  mainAxisExtent: 134,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) =>
                                _doctorCard(context, filtered[index]),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _doctorCard(context, filtered[index]),
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
    );
  }

  Widget _doctorCard(BuildContext context, DoctorModel doctor) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DoctorDetailsScreen(doctor: doctor),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.primaryBlue.withValues(
                      alpha: 0.12,
                    ),
                    backgroundImage: doctor.avatarUrl.isNotEmpty
                        ? NetworkImage(doctor.avatarUrl)
                        : null,
                    child: doctor.avatarUrl.isEmpty
                        ? Text(
                            doctor.name.isNotEmpty
                                ? doctor.name[0].toUpperCase()
                                : 'D',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      doctor.specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctor.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorDetailsScreen(doctor: doctor),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(doctor.active ? 'Book' : 'View'),
                ),
              ),
            ],
          ),
        ),
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
