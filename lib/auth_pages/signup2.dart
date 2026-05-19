import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/button.dart';
import 'package:medical/functions/custom_text.dart';
import 'package:medical/functions/txtField.dart';
import 'package:medical/services/api_service.dart';
import 'login.dart';

/// SignUp2View - Step 2: Doctor & emergency contact information
/// Receives account data from SignUpView (step 1) via constructor.
class SignUp2View extends StatefulWidget {
  final String username;
  final String email;
  final String password;
  final String phoneNumber;
  final String role;
  final String dateOfBirth;
  final String age;
  final String height;
  final String weight;

  const SignUp2View({
    super.key,
    required this.username,
    required this.email,
    required this.password,
    required this.phoneNumber,
    required this.role,
    required this.dateOfBirth,
    required this.age,
    required this.height,
    required this.weight,
  });

  @override
  State<SignUp2View> createState() => _SignUp2ViewState();
}

class _SignUp2ViewState extends State<SignUp2View> {
  final doctorNameController = TextEditingController();
  final doctorEmailController = TextEditingController();
  final doctorNumberController = TextEditingController();
  final relativeNameController = TextEditingController();
  final relativeEmailController = TextEditingController();
  final relativeNumberController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    doctorNameController.dispose();
    doctorEmailController.dispose();
    doctorNumberController.dispose();
    relativeNameController.dispose();
    relativeEmailController.dispose();
    relativeNumberController.dispose();
    super.dispose();
  }

  Future<void> _finishSignUp() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.signUp(
        username: widget.username,
        email: widget.email,
        password: widget.password,
        phoneNumber: widget.phoneNumber,
        role: widget.role,
        dateOfBirth: widget.dateOfBirth,
        age: widget.age,
        height: widget.height,
        weight: widget.weight,
        doctorName: doctorNameController.text.trim(),
        doctorEmail: doctorEmailController.text.trim(),
        doctorPhone: doctorNumberController.text.trim(),
        emergencyName: relativeNameController.text.trim(),
        emergencyEmail: relativeEmailController.text.trim(),
        emergencyPhone: relativeNumberController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please login.'),
            backgroundColor: Colors.green,
          ),
        );
        // Pop all the way back to login
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginView()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

                  // Logo
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

                  // Title
                  CustomText(
                    text: 'Almost There!',
                    color: AppColors.primary,
                    size: 32,
                    weight: FontWeight.bold,
                  ),

                  const Gap(8),

                  CustomText(
                    text: 'Step 2 of 2 — Complete your profile',
                    color: Colors.grey.shade600,
                    size: 15,
                    weight: FontWeight.w400,
                  ),

                  const Gap(40),

                  // ─── Doctor's Information ───────────────────────────
                  _sectionHeader("Personal Doctor's Information"),
                  const Gap(20),

                  _buildField(
                    child: CustomTxtfield(
                      controller: doctorNameController,
                      hint: "Doctor's Name",
                      isPassword: false,
                    ),
                  ),

                  const Gap(18),

                  _buildField(
                    child: CustomTxtfield(
                      controller: doctorEmailController,
                      hint: "Doctor's Email",
                      isPassword: false,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),

                  const Gap(18),

                  _buildField(
                    child: CustomTxtfield(
                      controller: doctorNumberController,
                      hint: "Doctor's Phone Number",
                      isPassword: false,
                      keyboardType: TextInputType.phone,
                    ),
                  ),

                  const Gap(36),

                  // ─── Emergency Contact ──────────────────────────────
                  _sectionHeader("Emergency Contact"),
                  const Gap(20),

                  _buildField(
                    child: CustomTxtfield(
                      controller: relativeNameController,
                      hint: "Relative's Name",
                      isPassword: false,
                    ),
                  ),

                  const Gap(18),

                  _buildField(
                    child: CustomTxtfield(
                      controller: relativeEmailController,
                      hint: "Relative's Email",
                      isPassword: false,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),

                  const Gap(18),

                  _buildField(
                    child: CustomTxtfield(
                      controller: relativeNumberController,
                      hint: "Relative's Phone Number",
                      isPassword: false,
                      keyboardType: TextInputType.phone,
                    ),
                  ),

                  const Gap(40),

                  // ─── "Finish signing up" Button ─────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : CustomAuthBtn(
                              text: 'Finish signing up',
                              onTap: _finishSignUp,
                            ),
                    ),
                  ),

                  const Gap(24),

                  // ─── Back button ────────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back_ios,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const Gap(4),
                        CustomText(
                          text: 'Go Back',
                          color: AppColors.primary,
                          size: 15,
                          weight: FontWeight.bold,
                        ),
                      ],
                    ),
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

  /// Section header pill label.
  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomText(
          text: title,
          color: AppColors.primary,
          size: 16,
          weight: FontWeight.bold,
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