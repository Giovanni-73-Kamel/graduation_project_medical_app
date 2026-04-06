import 'package:flutter/material.dart';
import 'package:medical/auth_pages/login.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Catch uncaught exceptions during build
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter Error: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  };
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Health Tracker",
      // home: HomeView(),
       home: LoginView(),

    );
  }
}
