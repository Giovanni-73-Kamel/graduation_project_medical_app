import 'package:flutter/material.dart';
import 'package:medical/auth_pages/login.dart';
import 'package:medical/home_pages/home.dart';
import 'package:medical/home_pages/settings.dart';
import 'package:medical/functions/settings_provider.dart';
import 'package:medical/screens/doctor/doctor_home_screen.dart';
import 'package:medical/services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsProvider = SettingsProvider();
  await settingsProvider.load();

  runApp(MyApp(settingsProvider: settingsProvider));
}

class MyApp extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const MyApp({super.key, required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      provider: settingsProvider,
      child: ListenableBuilder(
        listenable: settingsProvider,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: "Health Tracker",
            theme: settingsProvider.themeData,
            builder: (context, child) {
              // Apply global font scale
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(settingsProvider.fontScale),
                ),
                child: Directionality(
                  textDirection: settingsProvider.isRtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: child!,
                ),
              );
            },
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<Widget> _initialScreen = _resolveInitialScreen();

  Future<Widget> _resolveInitialScreen() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      return const LoginView();
    }

    try {
      final profile = await ApiService.getUserProfile();
      final role = profile['role']?.toString().toLowerCase();
      if (role == 'doctor') {
        return const DoctorHomeScreen();
      }
      return const HomeView();
    } catch (_) {
      await ApiService.clearToken();
      return const LoginView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreen,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data ?? const LoginView();
      },
    );
  }
}
