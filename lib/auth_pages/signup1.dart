import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/button.dart';
import 'package:medical/functions/custom_text.dart';
import 'package:medical/functions/txtField.dart';
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
  final formKey = GlobalKey<FormState>();
  bool isDoctor = false;
  DateTime? _selectedDate;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passController.dispose();
    confirmPassController.dispose();
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

  void _goToStep2() {
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

    // All valid — navigate to step 2 passing collected data
    final dob =
        "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignUp2View(
          username: nameController.text.trim(),
          email: emailController.text.trim(),
          password: passController.text,
          phoneNumber: phoneController.text.trim(),
          role: isDoctor ? 'doctor' : 'patient',
          dateOfBirth: dob,
        ),
      ),
    );
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
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
                          horizontal: 16, vertical: 15),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_outlined,
                              color: AppColors.primary),
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
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
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
                              color: Colors.grey.shade300, thickness: 1)),
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
                              color: Colors.grey.shade300, thickness: 1)),
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