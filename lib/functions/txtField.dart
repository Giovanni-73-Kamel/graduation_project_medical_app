import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:medical/functions/app_colors.dart';
class CustomTxtfield extends StatefulWidget {
  const CustomTxtfield({
    super.key,
    required this.hint,
    required this.isPassword,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.isRequired = true,
  });
  final String hint;
  final bool isPassword;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool isRequired;

  @override
  State<CustomTxtfield> createState() => _CustomTxtfieldState();
}

class _CustomTxtfieldState extends State<CustomTxtfield> {
  late bool _obscureText;
  @override
  void initState() {
    _obscureText = widget.isPassword;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      cursorHeight: 20,
      cursorColor: AppColors.primary,
      validator: (v) {
        // If field is not required and empty, skip validation
        if (!widget.isRequired && (v == null || v.isEmpty)) {
          return null;
        }
        
        if (v == null || v.isEmpty) {
          return 'please fill ${widget.hint}';
        }

        // Email validation
        if (widget.hint.toLowerCase().contains('email')) {
          if (!v.contains('@') || !v.contains('.com')) {
            return 'email must contain "@" and ".com"';
          }
        }

        // Password validation
        if (widget.isPassword) {
          if (v.length < 8) {
            return 'password must be at least 8 digits';
          }
        }

        // Number validation
        if (widget.keyboardType == TextInputType.number ||
            widget.hint.toLowerCase().contains('number') ||
            widget.hint.toLowerCase().contains('phone')) {
          final numberRegex = RegExp(r'^[0-9]+$');
          if (!numberRegex.hasMatch(v)) {
            return 'please enter numbers only';
          }
        }

        return null;
      },
      obscureText: _obscureText,
      decoration: InputDecoration(
          suffixIcon: widget.isPassword
              ? GestureDetector(
                  onTap: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                  child: Icon(CupertinoIcons.eye))
              : null,
          enabledBorder:
              OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          focusedBorder:
              OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          hintText: widget.hint,
          fillColor: Colors.white,
          filled: true),
    );
  }
}