import 'package:flutter/material.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/custom_text.dart';
final GlobalKey<FormState> formKey = GlobalKey<FormState>();
class CustomAuthBtn extends StatelessWidget {
  const CustomAuthBtn ({super.key, required this.text, required this.onTap});
  final String text ;
  final Function() ? onTap ;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
           onTap: onTap,
          //hena el action ba2a backend w auth w kda
          //5ally balk el onTab msh required , 
          //ya3ny 3aizo hatktb el function "onTab(){function};"
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80),
            child: Container(
            height: 55,
            decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            color: Colors.white,
            ),
            width: double.infinity,
            child: Center(child: CustomText(
            text: text,
            color: AppColors.primary,
            size: 25,
            weight: FontWeight.bold)),
                   ),
          ),
    );
   }
  }