import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:medical/auth_pages/login.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/custom_text.dart';
import 'package:medical/functions/settings_provider.dart';
import 'package:medical/home_pages/settings.dart';
import 'package:medical/services/api_service.dart';
import 'package:medical/models/doctor_model.dart';
import 'package:medical/widgets/doctor_card.dart';
import 'package:medical/screens/patient/doctor_selection_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// The ProfileView screen displays user information including
/// name, email, age, health score, and profile photo.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

/// The state class manages all data and UI for the ProfileView widget.
class _ProfileViewState extends State<ProfileView> {
  String userName = "Loading...";
  String userEmail = "...";
  String userPhone = "...";
  String userHeight = "";
  String userWeight = "";
  int userAge = 0;
  int healthScore = 75;
  bool _isLoading = true;
  bool _isSavingMetrics = false;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // Doctor related state
  DoctorModel? _assignedDoctor;
  bool _isLoadingDoctor = true;

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _loadProfileImage();
    _fetchAssignedDoctor();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_path');
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        setState(() {
          _profileImage = file;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path', pickedFile.path);
      }
    } catch (e) {
      print('Failed to pick image: $e');
    }
  }

  int _calculateAge(String dobString) {
    try {
      DateTime dob = DateTime.parse(dobString);
      DateTime today = DateTime.now();
      int age = today.year - dob.year;
      if (today.month < dob.month ||
          (today.month == dob.month && today.day < dob.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await ApiService.getUserProfile();
      setState(() {
        userEmail = profile['email'] ?? 'No email';
        userName = profile['username'] ?? userEmail.split('@')[0].toUpperCase();
        userPhone = profile['phone_number'] ?? 'Not set';
        userHeight = _numericPart(_metricText(profile['height']));
        userWeight = _numericPart(_metricText(profile['weight']));
        _heightController.text = userHeight;
        _weightController.text = userWeight;

        if (profile['date_of_birth'] != null) {
          userAge = _calculateAge(profile['date_of_birth']);
        } else {
          userAge = 0;
        }

        healthScore = 75; // Placeholder
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching profile: $e');
      if (mounted) {
        setState(() {
          userName = "Error Loading";
          _isLoading = false;
        });
      }
    }
  }

  String _metricText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text;
  }

  String _numericPart(String value) {
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(value);
    return match?.group(0) ?? '';
  }

  double? _positiveNumber(String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  Future<void> _saveBodyMetrics() async {
    final height = _positiveNumber(_heightController.text);
    final weight = _positiveNumber(_weightController.text);
    if (height == null || weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter positive height and weight values.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSavingMetrics = true);
    try {
      final heightText = _formatNumber(height);
      final weightText = _formatNumber(weight);
      await ApiService.updateUserProfile({
        'height': heightText,
        'weight': weightText,
      });
      if (!mounted) return;
      setState(() {
        userHeight = heightText;
        userWeight = weightText;
        _heightController.text = heightText;
        _weightController.text = weightText;
      });
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Body metrics updated for blood pressure analysis.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update body metrics: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingMetrics = false);
      }
    }
  }

  Future<void> _showBodyMetricsEditor() async {
    _heightController.text = userHeight;
    _weightController.text = userWeight;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Body metrics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Height',
                  suffixText: 'cm',
                  border: OutlineInputBorder(),
                ),
              ),
              const Gap(14),
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  suffixText: 'kg',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  _isSavingMetrics ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: _isSavingMetrics ? null : _saveBodyMetrics,
              icon: _isSavingMetrics
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchAssignedDoctor() async {
    try {
      final profile = await ApiService.getUserProfile();
      final doctorId = profile['doctor_id'];

      if (doctorId != null) {
        final doctorData = await ApiService.getDoctorById(doctorId);
        final doctor = DoctorModel.fromJson(doctorData);

        if (mounted) {
          setState(() {
            _assignedDoctor = doctor;
            _isLoadingDoctor = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingDoctor = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDoctor = false;
        });
      }
    }
  }

  Future<void> _navigateToDoctorSelection() async {
    final selectedDoctor = await Navigator.push<DoctorModel>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DoctorSelectionScreen(currentDoctorId: _assignedDoctor?.id),
      ),
    );

    if (selectedDoctor != null && mounted) {
      setState(() {
        _assignedDoctor = selectedDoctor;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doctor assigned successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final isDark = s.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F1923) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white60 : Colors.grey[600]!;
    final emptyCardBg = isDark ? const Color(0xFF1A2A3A) : Colors.grey[100]!;
    final emptyCardBorder = isDark ? Colors.white12 : Colors.grey[300]!;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const Gap(40),
                    // profile photo icon
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A2A3A) : Colors.grey[200],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 4,
                          ),
                          image: _profileImage != null
                              ? DecorationImage(
                                  image: FileImage(_profileImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _profileImage == null
                            ? Icon(
                                Icons.camera_alt,
                                size: 40,
                                color: isDark ? Colors.white38 : Colors.grey[600],
                              )
                            : null,
                      ),
                    ),

                    const Gap(30),

                    CustomText(
                      text: s.t('my_profile'),
                      color: AppColors.primary,
                      size: 35,
                      weight: FontWeight.bold,
                    ),

                    const Gap(40),

                    _buildInfoCard(
                      icon: Icons.person_outline,
                      label: s.t('profile_name'),
                      value: userName,
                    ),

                    const Gap(20),

                    _buildInfoCard(
                      icon: Icons.email_outlined,
                      label: s.t('profile_email'),
                      value: userEmail,
                    ),

                    const Gap(20),

                    _buildInfoCard(
                      icon: Icons.cake_outlined,
                      label: s.t('profile_age'),
                      value: userAge > 0
                          ? '$userAge ${s.t('profile_age_years')}'
                          : s.t('profile_age_not_set'),
                    ),

                    const Gap(20),

                    _buildInfoCard(
                      icon: Icons.phone_android_outlined,
                      label: s.t('profile_phone'),
                      value: userPhone,
                    ),

                    const Gap(40),

                    _buildBodyMetricsSection(
                      textColor,
                      subtextColor,
                      emptyCardBg,
                      emptyCardBorder,
                    ),

                    const Gap(40),

                    _buildHealthScoreCard(s),

                    const Gap(40),

                    _buildDoctorSection(s, textColor, subtextColor, emptyCardBg, emptyCardBorder),

                    const Gap(40),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await ApiService.clearToken();
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginView(),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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

  /// Builds a reusable information card widget
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
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),

          const Gap(15),

          // Label and Value
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

  Widget _buildBodyMetricsSection(
    Color textColor,
    Color subtextColor,
    Color cardBg,
    Color cardBorder,
  ) {
    final hasHeight = userHeight.trim().isNotEmpty;
    final hasWeight = userWeight.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_outlined, color: AppColors.primary),
              const Gap(10),
              Expanded(
                child: Text(
                  'Blood pressure AI profile',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit body metrics',
                onPressed: _showBodyMetricsEditor,
                icon: const Icon(Icons.edit_outlined),
                color: AppColors.primary,
              ),
            ],
          ),
          const Gap(14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Height',
                  value: hasHeight ? '$userHeight cm' : 'Not set',
                  isReady: hasHeight,
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
              const Gap(12),
              Expanded(
                child: _buildMetricTile(
                  label: 'Weight',
                  value: hasWeight ? '$userWeight kg' : 'Not set',
                  isReady: hasWeight,
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
            ],
          ),
          const Gap(12),
          Text(
            hasHeight && hasWeight
                ? 'Ready for the systolic and diastolic AI model.'
                : 'Height and weight are required before the blood pressure AI model can run.',
            style: TextStyle(
              color: hasHeight && hasWeight ? Colors.green[700] : subtextColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required bool isReady,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReady
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: subtextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(6),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the health score card with a progress indicator
  Widget _buildHealthScoreCard(SettingsProvider s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.favorite_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const Gap(15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: s.t('health_score'),
                      color: Colors.white70,
                      size: 14,
                      weight: FontWeight.w500,
                    ),
                    const Gap(5),
                    CustomText(
                      text: '$healthScore / 100',
                      color: Colors.white,
                      size: 18,
                      weight: FontWeight.bold,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: healthScore / 100,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                _getHealthScoreColor(healthScore),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns color based on health score
  Color _getHealthScoreColor(int score) {
    if (score >= 80) {
      return Colors.green;
    } else if (score >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Builds the doctor section widget
  Widget _buildDoctorSection(SettingsProvider s, Color textColor,
      Color subtextColor, Color emptyCardBg, Color emptyCardBorder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CustomText(
              text: s.t('my_doctor'),
              color: AppColors.primary,
              size: 20,
              weight: FontWeight.bold,
            ),
            TextButton.icon(
              onPressed: _navigateToDoctorSelection,
              icon: const Icon(Icons.edit, size: 16),
              label: Text(s.t('change'), style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _isLoadingDoctor
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            : _assignedDoctor != null
            ? DoctorCard(
                doctor: _assignedDoctor!,
                onTap: _navigateToDoctorSelection,
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: emptyCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: emptyCardBorder),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_add_outlined,
                      size: 48,
                      color: subtextColor.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.t('no_doctor_assigned'),
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.t('tap_select_doctor'),
                      style: TextStyle(color: subtextColor.withOpacity(0.7), fontSize: 14),
                    ),
                  ],
                ),
              ),
      ],
    );
  }
}
