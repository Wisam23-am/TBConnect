import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/presentation/portal_role_screen.dart';
import 'features/doctor/presentation/home_page.dart';
import 'features/patient/presentation/patient_home_page.dart';
import 'services/auth_service.dart';

class TbConnectApp extends StatelessWidget {
  const TbConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF001833),
      onPrimary: Colors.white,
      secondary: Color(0xFF2A609C),
      onSecondary: Colors.white,
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: Color(0xFFF8F9FA),
      onSurface: Color(0xFF191C1D),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TBConnect',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        textTheme: GoogleFonts.manropeTextTheme(),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF112D4E),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            textStyle: const TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFC4C6CF)),
            foregroundColor: const Color(0xFF001833),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFC4C6CF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFC4C6CF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF112D4E), width: 1.6),
          ),
          hintStyle: const TextStyle(color: Color(0xFF74777F)),
        ),
      ),
      home: const _AppStartupHandler(),
    );
  }
}

/// Menentukan halaman awal berdasarkan session yang tersimpan:
/// - Dokter: via Supabase Auth
/// - Pasien: via SharedPreferences (PatientSession)
class _AppStartupHandler extends StatefulWidget {
  const _AppStartupHandler();

  @override
  State<_AppStartupHandler> createState() => _AppStartupHandlerState();
}

class _AppStartupHandlerState extends State<_AppStartupHandler> {
  final _authService = AuthService();
  bool _checking = true;
  Widget _target = const PortalRoleScreen();

  @override
  void initState() {
    super.initState();
    _resolveRoute();
  }

  Future<void> _resolveRoute() async {
    // Cek dokter (Supabase Auth session)
    if (Supabase.instance.client.auth.currentUser != null) {
      if (mounted) {
        setState(() {
          _target = const HomePage();
          _checking = false;
        });
      }
      return;
    }

    // Cek pasien (SharedPreferences session)
    final patientSession = await _authService.getPatientSession();
    if (patientSession != null) {
      if (mounted) {
        setState(() {
          _target = const PatientHomePage();
          _checking = false;
        });
      }
      return;
    }

    // Tidak ada session → portal role selection
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF112D4E)),
        ),
      );
    }
    return _target;
  }
}
