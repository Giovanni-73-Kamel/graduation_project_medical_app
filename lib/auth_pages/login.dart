import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/button.dart';
import 'package:medical/functions/custom_text.dart';
import 'package:medical/functions/txtField.dart';
import 'package:medical/services/api_service.dart';
import 'package:medical/home_pages/home.dart';
import 'signup1.dart';

/// LoginView 
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final emailController = TextEditingController(); // Using email as username for this example
  final passController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isDoctor = false;
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  Future<void> _attemptLogin() async {
    if (formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await ApiService.login(emailController.text, passController.text);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeView()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Gap(60),

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
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const Gap(40),
                  
                  CustomText(
                    text: 'Welcome Back',
                    color: AppColors.primary,
                    size: 32,
                    weight: FontWeight.bold,
                  ),

                  const Gap(8),

                  CustomText(
                    text: 'Login to continue your journey',
                    color: Colors.grey.shade600,
                    size: 16,
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
                                color: !isDoctor ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    color: !isDoctor ? Colors.white : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                  const Gap(8),
                                  Text(
                                    'User',
                                    style: TextStyle(
                                      color: !isDoctor ? Colors.white : Colors.grey.shade600,
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
                                color: isDoctor ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.medical_services_outlined,
                                    color: isDoctor ? Colors.white : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                  const Gap(8),
                                  Text(
                                    'Doctor',
                                    style: TextStyle(
                                      color: isDoctor ? Colors.white : Colors.grey.shade600,
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

                  // Email field with border styling
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: CustomTxtfield(
                      controller: emailController,
                      hint: 'Email Address',
                      isPassword: false,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),

                  const Gap(20),

                  // Password field with border styling
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: CustomTxtfield(
                      controller: passController,
                      hint: 'Password',
                      isPassword: true,
                    ),
                  ),

                  const Gap(16),

                  // Forgot password link
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        // Navigate to forgot password
                        print('Forgot password tapped');
                      },
                      child: CustomText(
                        text: 'Forgot Password?',
                        color: AppColors.primary,
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const Gap(40),

                  // Login button with border
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
                          ? const Center(child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ))
                          : CustomAuthBtn(
                              text: 'Login',
                              onTap: _attemptLogin,
                            ),
                    ),
                  ),
                  
                  const Gap(30),
                  
                  // Divider with "OR" text
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
                  
                  const Gap(30),
                  
                  // Sign up section with better visual hierarchy
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomText(
                        text: "Don't have an account? ",
                        color: Colors.grey.shade700,
                        size: 15,
                        weight: FontWeight.w500,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignUpView(),
                            ),
                          );
                        },
                        child: CustomText(
                          text: 'Sign Up',
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
}