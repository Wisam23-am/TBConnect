import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tbconnect/services/auth_service.dart';
import 'package:tbconnect/features/auth/presentation/portal_role_screen.dart';

import '../../../widgets/doctor_bottom_nav_bar.dart';
import 'home_page.dart';
import 'create_patient_screen.dart';
import 'doctor_profile_page.dart';

/// Main shell for the doctor flow.
///
/// Provides a persistent [DoctorBottomNavBar] across all three tabs
/// (Dasbor / Tambah / Profil) without page-transition animations on
/// the bottom bar — only the body content swaps via [IndexedStack].
class DoctorMainShell extends StatefulWidget {
  const DoctorMainShell({super.key});

  @override
  State<DoctorMainShell> createState() => _DoctorMainShellState();
}

class _DoctorMainShellState extends State<DoctorMainShell> {
  final _authService = AuthService();
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = const [
      HomePage(embedded: true),
      CreatePatientScreen(embedded: true),
      DoctorProfilePage(embedded: true),
    ];
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            Text('Logout', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
        content: Text('Yakin ingin keluar?', style: GoogleFonts.manrope()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: GoogleFonts.manrope(color: const Color(0xFF5A8DA0))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Logout', style: GoogleFonts.manrope(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logoutDoctor();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PortalRoleScreen()),
          (route) => false,
        );
      }
    }
  }

  // ──────────────────────────────────────────────
  // Per-tab AppBar configuration
  // ──────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    switch (_currentIndex) {
      case 0:
        return AppBar(
          toolbarHeight: 72,
          backgroundColor: Color(0xFF112D4E),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF112D4E), Color(0xFF3F72AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 0,
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE5F0FF),
                ),
                child: const Icon(Icons.dashboard, color: Color(0xFF112D4E)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dasbor Triase',
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE5F0FF),
                      )),
                ],
              ),
            ],
          ),
        );
      case 1:
        return AppBar(
          toolbarHeight: 72,
          backgroundColor: Color(0xFF112D4E),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF112D4E), Color(0xFF3F72AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 0,
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE5F0FF),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded,
                    color: Color(0xFF112D4E), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tambah Pasien',
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE5F0FF),
                      )),
                ],
              ),
            ],
          ),
        );
      default:
        return AppBar();
    }
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _currentIndex == 2 ? null : _buildAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: DoctorBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
