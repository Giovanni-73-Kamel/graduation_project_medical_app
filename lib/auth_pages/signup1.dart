import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/button.dart';
import 'package:medical/functions/custom_text.dart';
import 'package:medical/functions/txtField.dart';
import 'package:medical/services/api_service.dart';
import 'package:medical/screens/doctor/doctor_home_screen.dart';
import 'signup2.dart';

/// SignUpView - Step 1: Basic account information
class SignUpView extends StatefulWidget {
  const SignUpView({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passController = TextEditingController();
  final confirmPassController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isDoctor = false;
  DateTime? _selectedDate;
  String _heightUnit = 'cm';   // 'cm' or 'in'
  String _weightUnit = 'kg';   // 'kg' or 'lbs'

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passController.dispose();
    confirmPassController.dispose();
    heightController.dispose();
    weightController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _goToStep2() async {
    // Validate all basic form fields first
    if (!formKey.currentState!.validate()) return;

    // Validate date of birth
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your date of birth'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate password match
    if (passController.text != confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // All valid — check role and navigate accordingly
    final dob =
        "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

    // Build height/weight strings with their units
    final heightValue = heightController.text.trim();
    final weightValue = weightController.text.trim();
    final heightStr = heightValue.isEmpty ? '' : '$heightValue $_heightUnit';
    final weightStr = weightValue.isEmpty ? '' : '$weightValue $_weightUnit';
    
    // Auto-calculate age from the selected date of birth
    final age = DateTime.now().year - _selectedDate!.year;
    final birthMonth = _selectedDate!.month;
    final birthDay = _selectedDate!.day;
    final now = DateTime.now();
    int calculatedAge = age;
    if (now.month < birthMonth || (now.month == birthMonth && now.day < birthDay)) {
      calculatedAge--;
    }
    final ageStr = calculatedAge.toString();

    if (isDoctor) {
      // Doctor: Skip step 2, create account directly and go to doctor home
      try {
        await ApiService.signUp(
          username: nameController.text.trim(),
          email: emailController.text.trim(),
          password: passController.text,
          phoneNumber: phoneController.text.trim(),
          role: 'doctor',
          dateOfBirth: dob,
          age: ageStr,
          height: heightStr,
          weight: weightStr,
          // Provide empty strings for doctor/emergency info since skipping step 2
          doctorName: '',
          doctorEmail: '',
          doctorPhone: '',
          emergencyName: '',
          emergencyEmail: '',
          emergencyPhone: '',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Doctor account created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate directly to doctor home screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DoctorHomeScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      // Patient: Go to step 2 for additional info
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SignUp2View(
            username: nameController.text.trim(),
            email: emailController.text.trim(),
            password: passController.text,
            phoneNumber: phoneController.text.trim(),
            role: 'patient',
            dateOfBirth: dob,
            age: ageStr,
            height: heightStr,
            weight: weightStr,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,

      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),

          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),

            child: Form(
              key: formKey,

              child: Column(
                children: [
                  const Gap(40),

                  // Logo with subtle shadow for depth
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'images/logo.png',
                      width: 100,
                      height: 100,
                    ),
                  ),

                  const Gap(30),

                  // Welcome text section
                  CustomText(
                    text: 'Create Account',
                    color: AppColors.primary,
                    size: 32,
                    weight: FontWeight.bold,
                  ),

                  const Gap(8),

                  CustomText(
                    text: 'Step 1 of 2 — Basic information',
                    color: Colors.grey.shade600,
                    size: 15,
                    weight: FontWeight.w400,
                  ),

                  const Gap(30),

                  // Role Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isDoctor = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isDoctor
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    color: !isDoctor
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                  const Gap(8),
                                  Text(
                                    'User profile',
                                    style: TextStyle(
                                      color: !isDoctor
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isDoctor = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isDoctor
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.medical_services_outlined,
                                    color: isDoctor
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                  const Gap(8),
                                  Text(
                                    'Doctor profile',
                                    style: TextStyle(
                                      color: isDoctor
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Gap(30),

                  // ── Name ──
                  _buildField(
                    child: CustomTxtfield(
                      controller: nameController,
                      hint: 'Full Name',
                      isPassword: false,
                    ),
                  ),

                  const Gap(18),

                  // ── Email ──
                  _buildField(
                    child: CustomTxtfield(
                      controller: emailController,
                      hint: 'Email',
                      isPassword: false,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),

                  const Gap(18),

                  // ── Phone Number ──
                  _buildField(
                    child: CustomTxtfield(
                      controller: phoneController,
                      hint: 'Phone Number',
                      isPassword: false,
                      keyboardType: TextInputType.phone,
                    ),
                  ),

                  const Gap(18),

                  // ── Date of Birth ──
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            color: AppColors.primary,
                          ),
                          const Gap(12),
                          CustomText(
                            text: _selectedDate == null
                                ? 'Date of Birth'
                                : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                            color: _selectedDate == null
                                ? Colors.grey.shade600
                                : Colors.black87,
                            size: 16,
                            weight: FontWeight.w400,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Gap(18),



                  // ── Height & Weight (same row) ──
                  Row(
                    children: [
                      // Height
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: heightController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Height',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 15,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 15,
                                    ),
                                  ),
                                ),
                              ),
                              // Unit toggle (cm / in)
                              GestureDetector(
                                onTap: () => setState(() {
                                  _heightUnit = _heightUnit == 'cm' ? 'in' : 'cm';
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _heightUnit,
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Gap(12),

                      // Weight
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: weightController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Weight',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 15,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 15,
                                    ),
                                  ),
                                ),
                              ),
                              // Unit toggle (kg / lbs)
                              GestureDetector(
                                onTap: () => setState(() {
                                  _weightUnit = _weightUnit == 'kg' ? 'lbs' : 'kg';
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _weightUnit,
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Gap(18),

                  // ── Password ──
                  _buildField(
                    child: CustomTxtfield(
                      controller: passController,
                      hint: 'Password',
                      isPassword: true,
                    ),
                  ),

                  const Gap(18),

                  // ── Confirm Password ──
                  _buildField(
                    child: CustomTxtfield(
                      controller: confirmPassController,
                      hint: 'Confirm Your Password',
                      isPassword: true,
                    ),
                  ),

                  const Gap(36),

                  // ── "Complete signing up" Button ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: CustomAuthBtn(
                        text: 'Complete signing up',
                        onTap: _goToStep2,
                      ),
                    ),
                  ),

                  const Gap(30),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade300,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CustomText(
                          text: 'OR',
                          color: Colors.grey.shade500,
                          size: 14,
                          weight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade300,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  const Gap(24),

                  // Already have an account
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomText(
                        text: 'Already have an account? ',
                        color: Colors.grey.shade700,
                        size: 15,
                        weight: FontWeight.w500,
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: CustomText(
                          text: 'Login',
                          color: AppColors.primary,
                          size: 15,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const Gap(40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wraps a field with the standard primary-border decoration.
  Widget _buildField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}
