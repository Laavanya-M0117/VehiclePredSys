import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state_provider.dart';
import 'screens/ble_pairing_screen.dart';
import 'screens/main_navigation_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStateProvider(),
      child: const VehiclePredictiveTriageApp(),
    ),
  );
}

class VehiclePredictiveTriageApp extends StatelessWidget {
  const VehiclePredictiveTriageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, child) {
        return MaterialApp(
          title: 'Vehicle Predictive Triage',
          debugShowCheckedModeBanner: false,
          themeMode: provider.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF5F6FA),
            primaryColor: const Color(0xFF6C5CE7),
            cardColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C5CE7),
              secondary: Color(0xFF00B894),
              surface: Colors.white,
              error: Color(0xFFFF7675),
            ),
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0D0E15),
            primaryColor: const Color(0xFF6C5CE7),
            cardColor: const Color(0xFF161922),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6C5CE7),
              secondary: Color(0xFF00B894),
              surface: Color(0xFF161922),
              error: Color(0xFFFF7675),
            ),
            fontFamily: 'Roboto',
          ),
          home: provider.isAuthenticated
              ? const MainNavigationShell()
              : const BlePairingScreen(),
        );
      },
    );
  }
}
