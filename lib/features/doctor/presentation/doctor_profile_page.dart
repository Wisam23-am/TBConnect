// ============================================================
// TBConnect - Doctor Profile Page
// File: lib/features/doctor/presentation/doctor_profile_page.dart
//
// Menampilkan profil dokter dengan desain dari Figma:
// - Gradient banner + avatar lingkaran overlap
// - Personal Details, Practice Status, Credentials cards
// - Tombol Log Out
//
// Mendukung mode [embedded] untuk digunakan di DoctorMainShell.
// Responsive: menggunakan MediaQuery dan LayoutBuilder.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tbconnect/services/auth_service.dart';
import 'package:tbconnect/services/doctor_service.dart';
import 'package:tbconnect/features/auth/presentation/portal_role_screen.dart';

// =============================================================================
// DoctorProfilePage — Halaman utama profil dokter
// =============================================================================

class DoctorProfilePage extends StatefulWidget {
  const DoctorProfilePage({super.key, this.embedded = false});

  /// Saat [embedded] true, halaman dirender tanpa Scaffold sendiri
  /// sehingga bisa ditempatkan di dalam [DoctorMainShell].
  final bool embedded;

  @override
  State<DoctorProfilePage> createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  final _authService = AuthService();
  final _doctorService = DoctorService();

  Map<String, dynamic>? _profile;
  int _patientCount = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ---------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _authService.getDoctorProfile();
      int count = 0;
      try {
        final patients = await _doctorService.getTriageBoard();
        count = patients.length;
      } catch (_) {
        // Patient count is optional — ignore failure
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _patientCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat profil: $e';
        });
      }
    }
  }

  // ---------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
        content:
            Text('Yakin ingin keluar?', style: GoogleFonts.manrope()),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Logout',
                style: GoogleFonts.manrope(color: Colors.white)),
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

  // ---------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.trim().isNotEmpty) return name.trim()[0].toUpperCase();
    return 'D';
  }

  String _getEmail() {
    // Try from profile first, then fallback to auth user
    final fromProfile = _profile?['email'] as String?;
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    final authEmail = Supabase.instance.client.auth.currentUser?.email;
    return authEmail ?? '-';
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;
    final horizontalPadding = isWide ? 48.0 : 24.0;

    Widget body;

    if (_isLoading) {
      body = const Center(
        child: CircularProgressIndicator(color: Color(0xFF112D4E)),
      );
    } else if (_errorMessage != null) {
      body = _buildErrorState();
    } else {
      body = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gradient Banner ──
            const _ProfileBanner(),

            // ── Avatar (overlapping banner via negative offset) ──
            Center(
              child: Transform.translate(
                offset: const Offset(0, -64),
                child: _DoctorAvatar(
                  initials: _getInitials(_profile?['full_name'] ?? 'D'),
                ),
              ),
            ),

            // ── Name & Subtitle ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: _DoctorIdentity(
                name: _profile?['full_name'] ?? '-',
                specialization:
                    _profile?['specialization'] ?? 'Dokter Paru-Paru',
              ),
            ),

            const SizedBox(height: 32),

            // ── Personal Details Card ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: _PersonalDetailsCard(
                fullName: _profile?['full_name'] ?? '-',
                strNumber: _profile?['str_number'] ?? '-',
                hospitalName: _profile?['hospital_name'] ?? '-',
                email: _getEmail(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Practice Status Card ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: _PracticeStatusCard(patientCount: _patientCount),
            ),

            const SizedBox(height: 16),

            // ── Credentials Card ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: const _CredentialsCard(),
            ),

            const SizedBox(height: 32),

            // ── Action Buttons ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: _ActionButtons(onLogout: _logout),
            ),

            const SizedBox(height: 24),
          ],
        ),
      );
    }

    // Embedded mode: return just the body (for DoctorMainShell)
    if (widget.embedded) return body;

    // Standalone mode: wrap in Scaffold
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Profil Dokter',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF112D4E),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDE2C2C)),
            onPressed: _logout,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 64, color: Color(0xFFC4C6CF)),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF112D4E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: const Color(0xFF5A8DA0),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF112D4E),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// GRADIENT BANNER
// =============================================================================

/// Gradient blue banner/cover image di bagian atas halaman profil.
/// Tinggi tetap 192px sesuai Figma, merespons lebar layar.
class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 192,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF112D4E), Color(0xFF2A609C)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Decorative circle (Figma: top-right circle)
              Positioned(
                right: -16,
                top: -16,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFF112D4E).withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// DOCTOR AVATAR
// =============================================================================

/// Avatar lingkaran dokter dengan inisial.
/// Ukuran 128x128 sesuai Figma, border putih 4px, rounded 24px.
class _DoctorAvatar extends StatelessWidget {
  final String initials;

  const _DoctorAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        color: const Color(0xFFE5F0FF),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.manrope(
            color: const Color(0xFF112D4E),
            fontSize: 48,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DOCTOR IDENTITY (Name + Specialization)
// =============================================================================

/// Menampilkan nama dokter (40px) dan spesialisasi.
class _DoctorIdentity extends StatelessWidget {
  final String name;
  final String specialization;

  const _DoctorIdentity({
    required this.name,
    required this.specialization,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Name — responsive font size
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: const Color(0xFF112D4E),
              fontSize: 40,
              fontWeight: FontWeight.w700,
              height: 1.20,
              letterSpacing: -0.80,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Specialization
        Text(
          specialization,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: const Color(0xFF43474E),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.50,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// PERSONAL DETAILS CARD
// =============================================================================

/// Kartu informasi pribadi dokter: nama, STR, rumah sakit, email.
/// Setiap baris memiliki ikon, label abu-abu, dan nilai tebal.
class _PersonalDetailsCard extends StatelessWidget {
  final String fullName;
  final String strNumber;
  final String hospitalName;
  final String email;

  const _PersonalDetailsCard({
    required this.fullName,
    required this.strNumber,
    required this.hospitalName,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDBE2EF), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A112D4E),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──
          Text(
            'Personal Details',
            style: GoogleFonts.manrope(
              color: const Color(0xFF112D4E),
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1.33,
              letterSpacing: -0.24,
            ),
          ),
          const SizedBox(height: 24),

          // ── Detail rows ──
          _DetailRow(
            icon: Icons.person_outline_rounded,
            label: 'NAMA LENGKAP',
            value: fullName,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.badge_outlined,
            label: 'NOMOR STR',
            value: strNumber,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.local_hospital_outlined,
            label: 'NAMA RUMAH SAKIT',
            value: hospitalName,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.email_outlined,
            label: 'EMAIL',
            value: email,
          ),
        ],
      ),
    );
  }
}

/// Satu baris detail dengan ikon, label, dan value.
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF112D4E)),
          ),
          const SizedBox(width: 16),
          // Label + Value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF8D94A0),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.33,
                    letterSpacing: 0.60,
                  ),
                ),
                const SizedBox(height: 2),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Text(
                      value,
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF112D4E),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.56,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PRACTICE STATUS CARD
// =============================================================================

/// Kartu status praktik dokter — latar belakang biru tua dengan:
/// - Label "PRACTICE STATUS"
/// - Green dot + "Active Practice"
/// - Jumlah pasien aktif bulan ini
class _PracticeStatusCard extends StatelessWidget {
  final int patientCount;

  const _PracticeStatusCard({required this.patientCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF112D4E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 15,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle (Figma: right-top circle)
          Positioned(
            right: -16,
            top: -16,
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0x338BBBFD),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Opacity(
                opacity: 0.70,
                child: Text(
                  'PRACTICE STATUS',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.33,
                    letterSpacing: 0.60,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Green dot + Active Practice
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Practice',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.56,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Patient count description
              Opacity(
                opacity: 0.80,
                child: Text(
                  'Menangani $patientCount pasien TB aktif bulan ini.',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.38,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CREDENTIALS CARD
// =============================================================================

/// Kartu kredensial dokter yang menampilkan daftar sertifikasi/pendidikan.
/// Data bersifat statis (dapat diperluas dengan data dari DB nanti).
class _CredentialsCard extends StatelessWidget {
  const _CredentialsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDBE2EF), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A112D4E),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium_outlined,
                    size: 18, color: Color(0xFF112D4E)),
              ),
              const SizedBox(width: 12),
              Text(
                'Credentials',
                style: GoogleFonts.manrope(
                  color: const Color(0xFF112D4E),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Credential Items ──
          const _CredentialItem(
            icon: Icons.school_outlined,
            label: 'Master of Pulmonology',
          ),
          const SizedBox(height: 14),
          const _CredentialItem(
            icon: Icons.verified_outlined,
            label: 'WHO TB Cert. 2023',
          ),
          const SizedBox(height: 14),
          const _CredentialItem(
            icon: Icons.medical_services_outlined,
            label: 'IDK Specialist Member',
          ),
        ],
      ),
    );
  }
}

/// Satu item kredensial dengan ikon dan teks.
class _CredentialItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CredentialItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2A609C)),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: const Color(0xFF43474E),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.50,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// ACTION BUTTONS
// =============================================================================

/// Tombol aksi: Log Out (outlined red).
class _ActionButtons extends StatelessWidget {
  final VoidCallback onLogout;

  const _ActionButtons({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Log Out ──
        OutlinedButton(
          onPressed: onLogout,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFBA1A1A), width: 1),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded,
                  color: Color(0xFFBA1A1A), size: 20),
              const SizedBox(width: 8),
              Text(
                'Log Out',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: const Color(0xFFBA1A1A),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.56,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
