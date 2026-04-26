import 'package:flutter/material.dart';
import 'package:medical/auth_pages/login.dart';
import 'package:medical/home_pages/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Health Tracker",

      // home: DoctorHomeScreen(),
      home: HomeView(),
    );
  }
}
