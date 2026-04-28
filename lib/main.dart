import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/supabase_config.dart';
import 'pages/role_selection_page.dart';
import 'pages/doctor/doctor_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const TBConnectApp());
}

class TBConnectApp extends StatelessWidget {
  const TBConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Cek apakah dokter sudah login
    final supabase = Supabase.instance.client;
    final isLoggedIn = supabase.auth.currentUser != null;

    return MaterialApp(
      title: 'TBConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A6B8A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: isLoggedIn ? const DoctorDashboardPage() : const RoleSelectionPage(),
    );
  }
}
