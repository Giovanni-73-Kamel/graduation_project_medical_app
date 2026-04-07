import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/custom_text.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  // Dummy doctor data
  final String doctorName = 'Dr. Adam El-Masry';
  final String doctorEmail = 'dr.adam@medicalclinic.com';
  final String doctorPhone = '+20 100 000 0000';
  final String doctorClinic = 'Cairo Heart Center, Floor 3';
  final String doctorSpecialty = 'Cardiologist';
  final int experience = 10;
  final int totalPatients = 214;
  final String rating = '4.9';

  List<String> specialisations = [
    'Interventional Cardiology',
    'Echocardiography',
    'Cardiac Imaging',
    'Hypertension',
  ];

  // ── Add specialisation dialog ──────────────────────────────────────────────
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
                setState(() => specialisations.add(text));
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Gap(40),

              // ── Avatar ──────────────────────────────────────────────────
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
                  _statChip('$totalPatients Patients'),
                  const Gap(10),
                  _statChip('$experience yrs exp.'),
                  const Gap(10),
                  _statChip('⭐ $rating'),
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

              // ── Info cards ───────────────────────────────────────────────
              _buildInfoCard(
                icon: Icons.person_outline,
                label: 'Name',
                value: doctorName,
              ),
              const Gap(20),
              _buildInfoCard(
                icon: Icons.medical_services_outlined,
                label: 'Specialty',
                value: doctorSpecialty,
              ),
              const Gap(20),
              _buildInfoCard(
                icon: Icons.email_outlined,
                label: 'Email',
                value: doctorEmail,
              ),
              const Gap(20),
              _buildInfoCard(
                icon: Icons.phone_android_outlined,
                label: 'Phone',
                value: doctorPhone,
              ),
              const Gap(20),
              _buildInfoCard(
                icon: Icons.local_hospital_outlined,
                label: 'Clinic',
                value: doctorClinic,
              ),

              const Gap(30),

              // ── Specialisations section ──────────────────────────────────
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
                          child: const Icon(Icons.workspace_premium_outlined,
                              color: Colors.white, size: 28),
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
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const Gap(14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: specialisations
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      width: 1),
                                ),
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),

              const Gap(20),

              // ── Sign out button ──────────────────────────────────────────
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
                        borderRadius: BorderRadius.circular(15)),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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