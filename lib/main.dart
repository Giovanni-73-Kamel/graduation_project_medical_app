import 'package:flutter/material.dart';
import 'package:medical/auth_pages/login.dart';
import 'package:medical/home_pages/home.dart';
import 'package:medical/home_pages/settings.dart';
import 'package:medical/functions/settings_provider.dart';

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
            // home: DoctorHomeScreen(),
            home: HomeView(),
          );
        },
      ),
    );
  }
}
