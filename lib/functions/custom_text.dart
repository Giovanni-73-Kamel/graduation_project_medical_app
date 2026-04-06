import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
  const CustomText({
    super.key,
    required this.text,
    required this.color,
    required this.size,
    required this.weight});
  final String text; 
  final Color color;
  final double size;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Text(
           text,
           style: TextStyle(
            fontSize: size ,
            color: color,
            fontWeight: weight ,
           ),
          );
  }
}