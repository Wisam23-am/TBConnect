import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/auth_service.dart';
import '../../auth/presentation/portal_role_screen.dart';

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final _authService = AuthService();

  PatientSession? _session;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final session = await _authService.getPatientSession();
      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Gagal memuat profil: $e';
        });
      }
    }
  }

  void _redirectToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PortalRoleScreen()),
      (route) => false,
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF112D4E)),
      );
    }

    if (_error != null) {
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
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: const Color(0xFF5A8DA0),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final session = _session;
    if (session == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_rounded,
                size: 64, color: Color(0xFFC4C6CF)),
            const SizedBox(height: 16),
            Text(
              'Belum login',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF112D4E),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _redirectToLogin,
              child: const Text('Login'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: const Color(0xFF112D4E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profil Pasien',
              style: GoogleFonts.manrope(
                color: const Color(0xFF001833),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Detail informasi pasien dan data klinis terkait.',
              style: GoogleFonts.manrope(
                color: const Color(0xFF43474E),
                fontSize: 13,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 18),
            _DetailCard(
              icon: Icons.person_outline_rounded,
              title: 'Data Pasien',
              children: [
                _DetailRow(label: 'Nama Lengkap', value: session.fullName),
                _DetailRow(
                  label: 'Tanggal Lahir',
                  value: _formatDate(session.treatmentStartDate),
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailCard(
              icon: Icons.medical_services_outlined,
              title: 'Informasi Klinik',
              children: [
                _DetailRow(
                    label: 'Nama Rumah Sakit',
                    value: session.doctorId == 'guest'
                        ? 'Klinik / Rumah Sakit'
                        : 'RSUD Dr. Soetomo'),
                _DetailRow(
                    label: 'Nama Dokter',
                    value: session.doctorId == 'guest'
                        ? 'Dokter Pembina'
                        : 'Dr. Siti Aminah, Sp.P'),
                _DetailRow(
                  label: 'Tanggal Masuk',
                  value: _formatDate(session.treatmentStartDate),
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _authService.logoutPatient();
                  if (mounted) _redirectToLogin();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Keluar Akun'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C112D4E),
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2A609C), size: 26),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: const Color(0xFF001833),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              color: const Color(0xFF6B7280),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: GoogleFonts.manrope(
              color: const Color(0xFF1F2937),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
          ),
        ),
        if (showDivider) ...[
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
