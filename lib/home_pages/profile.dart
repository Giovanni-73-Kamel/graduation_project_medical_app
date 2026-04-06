import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/custom_text.dart';
import 'package:medical/services/api_service.dart';

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
  int userAge = 0;
  int healthScore = 75; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  int _calculateAge(String dobString) {
    try {
      DateTime dob = DateTime.parse(dobString);
      DateTime today = DateTime.now();
      int age = today.year - dob.year;
      if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Set the background color for the whole screen
      backgroundColor: Colors.white,

      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const Gap(40),
             // profile photo icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 4,
                  ),
                  image: DecorationImage(
                    image: AssetImage('images/ana.png'), // elsora elle hat7otaha
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const Gap(30),

              // Page Title
              CustomText(
                text: 'My Profile',
                color: AppColors.primary,
                size: 35,
                weight: FontWeight.bold,
              ),

              const Gap(40),

              // Profile Information Cards
              
              // Name Card
              _buildInfoCard(
                icon: Icons.person_outline,
                label: 'Name',
                value: userName,
              ),

              const Gap(20),

              // Email Card
              _buildInfoCard(
                icon: Icons.email_outlined,
                label: 'Email',
                value: userEmail,
              ),

              const Gap(20),

              // Age Card
              _buildInfoCard(
                icon: Icons.cake_outlined,
                label: 'Age',
                value: userAge > 0 ? '$userAge years' : 'Not set',
              ),

              const Gap(20),

              // Phone Card
              _buildInfoCard(
                icon: Icons.phone_android_outlined,
                label: 'Phone',
                value: userPhone,
              ),

              const Gap(20),

              // Health Score Card
              _buildHealthScoreCard(),

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
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
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

  /// Builds the health score card with a progress indicator
  Widget _buildHealthScoreCard() {
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
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.favorite_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const Gap(15),

              // Label and Score
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CustomText(
                      text: 'Health Score',
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

          // Progress Bar
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
}