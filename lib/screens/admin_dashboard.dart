import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';
import '../models/doctor_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_utils.dart';
import 'login_screen.dart';

/// Super Admin Dashboard V22
/// Premium Glassmorphism UI with Glowing Electric-Blue (#0066FF / #00D2FF) Accents
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  late final Stream<List<DoctorModel>> _doctors = _firestoreService.getDoctors();
  late final Stream<List<AppointmentModel>> _appointments =
      _firestoreService.getAllAppointments();
  late final Stream<List<UserModel>> _users = _firestoreService.getAllUsers();

  late final TabController _tabController;
  String _selectedSpecialty = 'All';
  String _selectedApptStatus = 'All';

  final List<String> _specialties = const [
    'All',
    'Cardiology',
    'Dermatology',
    'Neurology',
    'Pediatrics',
    'Orthopedics',
    'General Medicine',
  ];

  final List<String> _apptStatuses = const [
    'All',
    'booked',
    'Pending',
    'Confirmed',
    'Completed',
    'cancelled',
  ];

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

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: error ? AppTheme.dangerRed : const Color(0xFF0066FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, {String? successMsg}) async {
    try {
      await action();
      if (mounted && successMsg != null) {
        _toast(successMsg, error: false);
      }
    } catch (e) {
      if (mounted) _toast(describeError(e), error: true);
    }
  }

  Future<void> _signOut() async {
    final nav = Navigator.of(context);
    await _authService.signOut();
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  // ============================================================
  // USER ROLE MANAGEMENT (Promote to Admin / Demote)
  // ============================================================
  Future<void> _toggleUserRole(UserModel user) async {
    final newRole = user.isAdmin ? 'user' : 'admin';
    final isPromote = newRole == 'admin';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              isPromote ? Icons.verified_user : Icons.remove_moderator,
              color: isPromote ? AppTheme.v22ElectricBlue : AppTheme.dangerRed,
            ),
            const SizedBox(width: 10),
            Text(isPromote ? 'Promote to Admin' : 'Demote to User'),
          ],
        ),
        content: Text(
          isPromote
              ? 'Grant Super Admin privileges to ${user.name} (${user.email})?'
              : 'Revoke Admin privileges from ${user.name} (${user.email})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isPromote ? AppTheme.v22ElectricBlue : AppTheme.dangerRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isPromote ? 'Promote' : 'Demote'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _run(
        () => _firestoreService.toggleUserRole(user.uid, user.role),
        successMsg: isPromote
            ? '${user.name} is now an ADMIN.'
            : '${user.name} role changed to USER.',
      );
    }
  }

  // ============================================================
  // DOCTOR MANAGEMENT MODALS & ACTIONS
  // ============================================================
  void _showAddDoctorDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final bioCtrl = TextEditingController();
    final expCtrl = TextEditingController(text: '5');
    final avatarCtrl = TextEditingController();
    String selectedSpec = _specialties[1]; // default Cardiology

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: AppTheme.v22ElectricBlue),
              SizedBox(width: 10),
              Text('Add New Doctor (V22)'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Doctor Name (e.g. Dr. John Doe)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedSpec,
                  decoration: const InputDecoration(
                    labelText: 'Specialty',
                    prefixIcon: Icon(Icons.local_hospital_outlined),
                  ),
                  items: _specialties
                      .where((s) => s != 'All')
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedSpec = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact / Schedule Phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: expCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Experience (Years)',
                    prefixIcon: Icon(Icons.history_edu_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Bio / Clinical Background',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: avatarCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Avatar Image URL (Optional)',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.v22ElectricBlue,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  _toast('Doctor name is required', error: true);
                  return;
                }
                final nav = Navigator.of(dialogCtx);
                final exp = int.tryParse(expCtrl.text.trim()) ?? 0;
                final doc = DoctorModel(
                  id: '',
                  name: name,
                  specialty: selectedSpec,
                  phone: phoneCtrl.text.trim(),
                  available: true,
                  bio: bioCtrl.text.trim(),
                  experienceYears: exp,
                  avatarUrl: avatarCtrl.text.trim(),
                );

                await _run(
                  () => _firestoreService.addDoctor(doc),
                  successMsg: '$name added to $selectedSpec directory.',
                );
                nav.pop();
              },
              child: const Text('Add Doctor'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDoctor(DoctorModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Doctor Profile'),
        content: Text(
          'Permanently remove ${doc.name} (${doc.specialty}) from the directory?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Doctor'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _run(
        () => _firestoreService.deleteDoctor(doc.id),
        successMsg: '${doc.name} removed from database.',
      );
    }
  }

  // ============================================================
  // APPOINTMENT MANAGEMENT MODALS & ACTIONS
  // ============================================================
  void _showAddAppointmentDialog(List<DoctorModel> availableDoctors) {
    if (availableDoctors.isEmpty) {
      _toast('No doctors registered yet. Please add a doctor first.', error: true);
      return;
    }

    final patientNameCtrl = TextEditingController();
    final patientEmailCtrl = TextEditingController();
    DoctorModel selectedDoc = availableDoctors.first;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    String selectedStatus = 'Confirmed';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.event_note, color: AppTheme.v22ElectricBlue),
              SizedBox(width: 10),
              Text('Schedule Appointment'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: patientNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Patient Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: patientEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Patient Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DoctorModel>(
                  initialValue: selectedDoc,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Doctor & Specialty',
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                  items: availableDoctors
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text('${d.name} (${d.specialty})'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedDoc = val);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: AppTheme.v22ElectricBlue),
                  title: Text(DateFormat.yMMMd().format(selectedDate)),
                  subtitle: const Text('Tap to change date'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time, color: AppTheme.v22ElectricCyan),
                  title: Text(selectedTime.format(context)),
                  subtitle: const Text('Tap to change time slot'),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setDialogState(() => selectedTime = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.v22ElectricBlue,
              ),
              onPressed: () async {
                final patient = patientNameCtrl.text.trim();
                final email = patientEmailCtrl.text.trim();
                if (patient.isEmpty || email.isEmpty) {
                  _toast('Patient name and email are required.', error: true);
                  return;
                }
                final nav = Navigator.of(dialogCtx);
                final appointmentDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final appt = AppointmentModel(
                  id: '',
                  userId: email,
                  patientName: patient,
                  patientEmail: email,
                  doctorId: selectedDoc.id,
                  doctorName: selectedDoc.name,
                  specialty: selectedDoc.specialty,
                  date: appointmentDateTime,
                  status: selectedStatus,
                  createdAt: DateTime.now(),
                );

                await _run(
                  () => _firestoreService.addAppointment(appt),
                  successMsg: 'Appointment booked for $patient.',
                );
                nav.pop();
              },
              child: const Text('Book Appointment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAppointmentStatus(AppointmentModel appt, String newStatus) async {
    await _run(
      () => _firestoreService.updateAppointmentStatus(appt.id, newStatus),
      successMsg: 'Status updated to $newStatus.',
    );
  }

  Future<void> _rescheduleAppointment(AppointmentModel appt) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: appt.date.isAfter(DateTime.now())
          ? appt.date
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(appt.date),
    );
    if (pickedTime == null) return;

    final updatedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    await _run(
      () => _firestoreService.rescheduleAppointment(appt.id, updatedDateTime),
      successMsg: 'Appointment rescheduled to ${DateFormat.yMMMd().add_jm().format(updatedDateTime)}.',
    );
  }

  Future<void> _confirmDeleteAppointment(AppointmentModel appt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Appointment Record'),
        content: Text(
          'Permanently delete appointment for ${appt.patientName.isNotEmpty ? appt.patientName : appt.userId} with ${appt.doctorName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Record'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _run(
        () => _firestoreService.deleteAppointment(appt.id),
        successMsg: 'Appointment record deleted.',
      );
    }
  }

  // ============================================================
  // UI BUILD & SECTIONS
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF4F7FC),
              Color(0xFFE9F0FE),
              Color(0xFFE1ECFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopHeader(),
              _buildMetricsSummary(),
              _buildTabsBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRegisteredUsersTab(),
                    _buildDoctorsTab(),
                    _buildAppointmentsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.v22ElectricBlue,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.add),
        label: Text(
          _tabController.index == 0
              ? 'Users'
              : _tabController.index == 1
                  ? 'Add Doctor'
                  : 'New Appt',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (_tabController.index == 1) {
            _showAddDoctorDialog();
          } else if (_tabController.index == 2) {
            _doctors.first.then((docs) => _showAddAppointmentDialog(docs));
          } else {
            _toast('Admins can manage user roles directly from the Users list.');
          }
        },
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: const Border(
          bottom: BorderSide(color: AppTheme.v22GlassBorder, width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.v22GlowShadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.v22ElectricGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.v22ElectricBlue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Super Admin Dashboard',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.v22DeepSlate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.v22ElectricBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.v22ElectricBlue.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'V22',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.v22ElectricBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _authService.currentUser?.email ?? 'kenjirobenji@gmail.com',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign Out',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.dangerRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: _signOut,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSummary() {
    return StreamBuilder<List<UserModel>>(
      stream: _users,
      builder: (context, userSnap) {
        return StreamBuilder<List<DoctorModel>>(
          stream: _doctors,
          builder: (context, docSnap) {
            return StreamBuilder<List<AppointmentModel>>(
              stream: _appointments,
              builder: (context, apptSnap) {
                final users = userSnap.data ?? [];
                final doctors = docSnap.data ?? [];
                final appts = apptSnap.data ?? [];

                final onlineCount = users.where((u) => u.isOnline).length;
                final activeDoctors = doctors.where((d) => d.available).length;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: [
                      _buildMetricTile(
                        label: 'Total Users',
                        value: '${users.length}',
                        icon: Icons.people_alt_rounded,
                        accentColor: AppTheme.v22ElectricBlue,
                      ),
                      const SizedBox(width: 10),
                      _buildMetricTile(
                        label: 'Online Live',
                        value: '$onlineCount',
                        icon: Icons.bolt_rounded,
                        accentColor: const Color(0xFF10B981),
                        isPulse: true,
                      ),
                      const SizedBox(width: 10),
                      _buildMetricTile(
                        label: 'Doctors',
                        value: '$activeDoctors/${doctors.length}',
                        icon: Icons.medical_services_rounded,
                        accentColor: AppTheme.v22ElectricCyan,
                      ),
                      const SizedBox(width: 10),
                      _buildMetricTile(
                        label: 'Appts',
                        value: '${appts.length}',
                        icon: Icons.event_available_rounded,
                        accentColor: const Color(0xFF8B5CF6),
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

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    bool isPulse = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: AppTheme.v22GlassCard(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 16),
                if (isPulse) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.v22DeepSlate,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.v22GlassBorder),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textDark,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: AppTheme.v22ElectricGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.v22ElectricBlue.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.people_outline, size: 18),
            text: 'Users Monitor',
          ),
          Tab(
            icon: Icon(Icons.medical_services_outlined, size: 18),
            text: 'Doctors Directory',
          ),
          Tab(
            icon: Icon(Icons.calendar_month_outlined, size: 18),
            text: 'Appointments',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 1: REGISTERED USERS LIVE MONITOR
  // ============================================================
  Widget _buildRegisteredUsersTab() {
    return StreamBuilder<List<UserModel>>(
      stream: _users,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(describeError(snapshot.error!)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data!;
        if (users.isEmpty) {
          return const Center(child: Text('No registered users found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final isOnline = user.isOnline;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: AppTheme.v22GlassCard(
                borderColor: user.isAdmin
                    ? AppTheme.v22ElectricBlue.withValues(alpha: 0.4)
                    : AppTheme.v22GlassBorder,
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: user.isAdmin
                          ? AppTheme.v22ElectricBlue
                          : Colors.grey.shade200,
                      foregroundColor:
                          user.isAdmin ? Colors.white : AppTheme.v22DeepSlate,
                      child: Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : user.email[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFF10B981)
                              : Colors.grey.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name.isEmpty ? 'User' : user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: user.isAdmin
                            ? AppTheme.v22ElectricBlue.withValues(alpha: 0.12)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: user.isAdmin
                              ? AppTheme.v22ElectricBlue.withValues(alpha: 0.3)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: user.isAdmin
                              ? AppTheme.v22ElectricBlue
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.email,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          isOnline ? Icons.circle : Icons.history,
                          size: 11,
                          color: isOnline
                              ? const Color(0xFF10B981)
                              : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOnline
                              ? 'Online Now'
                              : user.lastLogin != null
                                  ? 'Last seen: ${DateFormat.yMd().add_jm().format(user.lastLogin!)}'
                                  : 'Offline',
                          style: TextStyle(
                            fontSize: 11,
                            color: isOnline
                                ? const Color(0xFF10B981)
                                : AppTheme.textMuted,
                            fontWeight: isOnline
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: user.isAdmin
                        ? Colors.grey.shade100
                        : AppTheme.v22ElectricBlue,
                    foregroundColor: user.isAdmin
                        ? AppTheme.dangerRed
                        : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  icon: Icon(
                    user.isAdmin
                        ? Icons.remove_moderator_outlined
                        : Icons.verified_user_outlined,
                    size: 14,
                  ),
                  label: Text(user.isAdmin ? 'Demote' : 'Promote'),
                  onPressed: () => _toggleUserRole(user),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // TAB 2: DOCTOR MANAGEMENT (CATEGORIZED BY SPECIALTY)
  // ============================================================
  Widget _buildDoctorsTab() {
    return Column(
      children: [
        _buildSpecialtyFilterBar(),
        Expanded(
          child: StreamBuilder<List<DoctorModel>>(
            stream: _doctors,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text(describeError(snapshot.error!)));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var list = snapshot.data!;
              if (_selectedSpecialty != 'All') {
                list = list
                    .where((d) =>
                        d.specialty.toLowerCase() ==
                        _selectedSpecialty.toLowerCase())
                    .toList();
              }

              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.medical_information_outlined,
                          size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        'No doctors found in $_selectedSpecialty.',
                        style: const TextStyle(
                            fontSize: 15, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Doctor to Category'),
                        onPressed: _showAddDoctorDialog,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final doc = list[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: AppTheme.v22GlassCard(),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                AppTheme.v22ElectricBlue.withValues(alpha: 0.12),
                            backgroundImage: doc.avatarUrl.isNotEmpty
                                ? NetworkImage(doc.avatarUrl)
                                : null,
                            child: doc.avatarUrl.isEmpty
                                ? const Icon(Icons.person,
                                    color: AppTheme.v22ElectricBlue, size: 28)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        doc.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.v22ElectricCyan
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        doc.specialty,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.v22ElectricBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (doc.bio.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    doc.bio,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (doc.phone.isNotEmpty) ...[
                                      const Icon(Icons.phone_outlined,
                                          size: 13, color: AppTheme.textMuted),
                                      const SizedBox(width: 4),
                                      Text(doc.phone,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textMuted)),
                                      const SizedBox(width: 12),
                                    ],
                                    if (doc.experienceYears > 0) ...[
                                      const Icon(Icons.work_history_outlined,
                                          size: 13, color: AppTheme.textMuted),
                                      const SizedBox(width: 4),
                                      Text('${doc.experienceYears} yrs exp',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textMuted)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Tooltip(
                                message: doc.available
                                    ? 'Status: Available'
                                    : 'Status: Unavailable',
                                child: Switch(
                                  activeThumbColor: AppTheme.v22ElectricBlue,
                                  value: doc.available,
                                  onChanged: (v) => _run(
                                    () => _firestoreService
                                        .setDoctorAvailability(doc.id, v),
                                    successMsg:
                                        '${doc.name} marked as ${v ? 'Available' : 'Unavailable'}.',
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete doctor',
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.dangerRed, size: 20),
                                onPressed: () => _confirmDeleteDoctor(doc),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialtyFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _specialties.map((spec) {
          final isSelected = _selectedSpecialty == spec;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(spec),
              selected: isSelected,
              selectedColor: AppTheme.v22ElectricBlue,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.v22ElectricBlue
                    : AppTheme.v22GlassBorder,
              ),
              onSelected: (_) => setState(() => _selectedSpecialty = spec),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // TAB 3: COMPLETE APPOINTMENT CONTROL
  // ============================================================
  Widget _buildAppointmentsTab() {
    return Column(
      children: [
        _buildAppointmentStatusFilterBar(),
        Expanded(
          child: StreamBuilder<List<AppointmentModel>>(
            stream: _appointments,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text(describeError(snapshot.error!)));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var list = snapshot.data!;
              if (_selectedApptStatus != 'All') {
                list = list
                    .where((a) =>
                        a.status.toLowerCase() ==
                        _selectedApptStatus.toLowerCase())
                    .toList();
              }

              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_busy_outlined,
                          size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        'No appointments found ($_selectedApptStatus).',
                        style: const TextStyle(
                            fontSize: 15, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final appt = list[index];
                  final isCancelled = appt.isCancelled;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: AppTheme.v22GlassCard(),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isCancelled
                                      ? AppTheme.dangerRed.withValues(alpha: 0.12)
                                      : AppTheme.v22ElectricBlue
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isCancelled
                                      ? Icons.cancel_outlined
                                      : Icons.event_available,
                                  color: isCancelled
                                      ? AppTheme.dangerRed
                                      : AppTheme.v22ElectricBlue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appt.doctorName.isNotEmpty
                                          ? appt.doctorName
                                          : 'Specialist Doctor',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      DateFormat.yMMMEd()
                                          .add_jm()
                                          .format(appt.date),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.v22ElectricBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(appt.status),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              const Icon(Icons.person_pin_outlined,
                                  size: 14, color: AppTheme.textMuted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Patient: ${appt.patientName.isNotEmpty ? appt.patientName : appt.userId} '
                                  '${appt.patientEmail.isNotEmpty ? '(${appt.patientEmail})' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Quick Status Dropdown Menu
                              PopupMenuButton<String>(
                                tooltip: 'Change Status',
                                icon: const Icon(Icons.edit_note,
                                    color: AppTheme.v22ElectricBlue),
                                onSelected: (status) =>
                                    _updateAppointmentStatus(appt, status),
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                      value: 'Confirmed',
                                      child: Text('Confirm')),
                                  const PopupMenuItem(
                                      value: 'Pending',
                                      child: Text('Mark Pending')),
                                  const PopupMenuItem(
                                      value: 'Completed',
                                      child: Text('Mark Completed')),
                                  const PopupMenuItem(
                                      value: 'cancelled',
                                      child: Text('Cancel Appointment')),
                                ],
                              ),
                              IconButton(
                                tooltip: 'Reschedule Date & Time',
                                icon: const Icon(Icons.edit_calendar_outlined,
                                    color: AppTheme.v22ElectricCyan, size: 20),
                                onPressed: () => _rescheduleAppointment(appt),
                              ),
                              IconButton(
                                tooltip: 'Delete Appointment Record',
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.dangerRed, size: 20),
                                onPressed: () => _confirmDeleteAppointment(appt),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentStatusFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _apptStatuses.map((status) {
          final isSelected = _selectedApptStatus == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(status.toUpperCase()),
              selected: isSelected,
              selectedColor: AppTheme.v22ElectricBlue,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 11,
              ),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.v22ElectricBlue
                    : AppTheme.v22GlassBorder,
              ),
              onSelected: (_) => setState(() => _selectedApptStatus = status),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    final lower = status.toLowerCase();

    if (lower == 'confirmed' || lower == 'booked') {
      bg = const Color(0xFF10B981).withValues(alpha: 0.14);
      fg = const Color(0xFF10B981);
    } else if (lower == 'pending') {
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.14);
      fg = const Color(0xFFD97706);
    } else if (lower == 'completed') {
      bg = AppTheme.v22ElectricBlue.withValues(alpha: 0.14);
      fg = AppTheme.v22ElectricBlue;
    } else {
      bg = AppTheme.dangerRed.withValues(alpha: 0.14);
      fg = AppTheme.dangerRed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
