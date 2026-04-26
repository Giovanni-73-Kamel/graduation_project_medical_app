import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/custom_text.dart';
import 'package:medical/services/api_service.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  Map<String, dynamic> _doctorProfile = {};
  bool _isLoading = true;
  String? _error;

  // Default values for missing data
  final Map<String, dynamic> _defaultProfile = {
    'username': 'Dr. Unknown',
    'email': 'doctor@medicalclinic.com',
    'phone_number': '+20 100 000 0000',
    'role': 'doctor',
    'doctor_name': 'Dr. Adam El-Masry',
    'doctor_email': 'dr.adam@medicalclinic.com',
    'doctor_phone': '+20 100 000 0000',
    'specialty': 'General Practitioner',
    'experience': 5,
    'total_patients': 0,
    'rating': '4.5',
  };

  final List<String> _specialisations = [
    'General Medicine',
    'Patient Care',
    'Medical Consultation',
  ];

  @override
  void initState() {
    super.initState();
    _loadDoctorProfile();
  }

  Future<void> _loadDoctorProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await ApiService.getUserProfile();

      // Get actual patient count
      int patientCount = 0;
      try {
        final patients = await ApiService.getPatients();
        patientCount = patients.length;
      } catch (e) {
        // If we can't get patients, just use 0
        print('Failed to load patients for profile: $e');
      }

      if (mounted) {
        setState(() {
          _doctorProfile = {...profile, 'total_patients': patientCount};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadDoctorProfile();
  }

  String get _doctorName =>
      _doctorProfile['doctor_name'] ??
      _doctorProfile['username'] ??
      _defaultProfile['doctor_name'];

  String get _doctorEmail =>
      _doctorProfile['doctor_email'] ??
      _doctorProfile['email'] ??
      _defaultProfile['doctor_email'];

  String get _doctorPhone =>
      _doctorProfile['doctor_phone'] ??
      _doctorProfile['phone_number'] ??
      _defaultProfile['doctor_phone'];

  String get _specialty =>
      _doctorProfile['specialty'] ?? _defaultProfile['specialty'];

  int get _experience =>
      (_doctorProfile['experience'] ?? _defaultProfile['experience']) as int;

  int get _totalPatients =>
      (_doctorProfile['total_patients'] ?? _defaultProfile['total_patients'])
          as int;

  String get _rating =>
      (_doctorProfile['rating'] ?? _defaultProfile['rating']).toString();

  // Add specialisation dialog
  void _showAddSpecialisationDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Specialisation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. Pediatric Cardiology',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() => _specialisations.add(text));
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1565C0)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _refresh,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Gap(40),

              // Avatar
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 4),
                ),
                child: const Icon(Icons.person, size: 64, color: Colors.white),
              ),

              const Gap(14),

              // Stats row under avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statChip('$_totalPatients Patients'),
                  const Gap(10),
                  _statChip('$_experience yrs exp.'),
                  const Gap(10),
                  _statChip(_rating),
                ],
              ),

              const Gap(16),

              // Title
              CustomText(
                text: 'My Profile',
                color: AppColors.primary,
                size: 35,
                weight: FontWeight.bold,
              ),

              const Gap(40),

              // Info cards
              _buildInfoCard(
                icon: Icons.person_outline,
                label: 'Name',
                value: _doctorName,
              ),
              const Gap(20),
              _buildInfoCard(
                icon: Icons.medical_services_outlined,
                label: 'Specialty',
                value: _specialty,
              ),
              const Gap(20),
              _buildInfoCard(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _doctorEmail,
              ),
              const Gap(20),
              _buildInfoCard(
                icon: Icons.phone_android_outlined,
                label: 'Phone',
                value: _doctorPhone,
              ),
              const Gap(20),
              _buildInfoCard(
                icon: Icons.local_hospital_outlined,
                label: 'Role',
                value:
                    _doctorProfile['role']?.toString().toUpperCase() ??
                    'DOCTOR',
              ),

              const Gap(30),

              // Specialisations section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const Gap(15),
                        const Expanded(
                          child: CustomText(
                            text: 'Specialisations',
                            color: Colors.white70,
                            size: 14,
                            weight: FontWeight.w500,
                          ),
                        ),
                        // Add button
                        GestureDetector(
                          onTap: _showAddSpecialisationDialog,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _specialisations
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),

              const Gap(20),

              // Sign out button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  label: const CustomText(
                    text: 'Sign Out',
                    color: Colors.white,
                    size: 16,
                    weight: FontWeight.w600,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),

              const Gap(40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const Gap(15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  text: label,
                  color: Colors.white70,
                  size: 14,
                  weight: FontWeight.w500,
                ),
                const Gap(5),
                CustomText(
                  text: value,
                  color: Colors.white,
                  size: 18,
                  weight: FontWeight.bold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
