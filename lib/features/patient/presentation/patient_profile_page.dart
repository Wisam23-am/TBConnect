import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/auth_service.dart';
import '../../../services/patient_service.dart';
import '../../auth/presentation/portal_role_screen.dart';

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final _authService = AuthService();
  final _patientService = PatientDataService();

  PatientSession? _session;
  Map<String, dynamic>? _dbProfile;
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
      if (session == null) {
        if (mounted) _redirectToLogin();
        return;
      }

      final dbProfile = await _patientService.getPatientProfile(session.patientId);

      if (mounted) {
        setState(() {
          _session = session;
          _dbProfile = dbProfile;
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

  String _formatDate(dynamic dtStr) {
    if (dtStr == null) return '-';
    DateTime dt;
    if (dtStr is DateTime) {
      dt = dtStr;
    } else {
      dt = DateTime.tryParse(dtStr.toString()) ?? DateTime.now();
    }
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _calculateTreatmentPhase(DateTime startDate) {
    final now = DateTime.now();
    final difference = now.difference(startDate).inDays;
    final months = (difference / 30).floor() + 1;
    return 'Bulan ke-$months';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, 2).toUpperCase() : 'PS';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF112D4E)),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    final db = _dbProfile;
    final session = _session;

    if (db == null || session == null) {
      return _buildErrorState();
    }

    final doctor = db['doctors'] ?? {};
    final treatmentStartDate = DateTime.tryParse(db['treatment_start_date'] ?? '') ?? DateTime.now();
    final treatmentPhase = _calculateTreatmentPhase(treatmentStartDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: const Color(0xFF112D4E),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HERO SECTION ──
              _buildHeroSection(db['full_name'] ?? 'Pasien', db['nik'] ?? '-'),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── KARTU 1: INFO MEDIS UTAMA ──
                    _buildInfoCard(
                      icon: Icons.health_and_safety_rounded,
                      title: 'Informasi Medis',
                      children: [
                        _DetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Tanggal Mulai Pengobatan',
                          value: _formatDate(db['treatment_start_date']),
                        ),
                        _DetailRow(
                          icon: Icons.timeline_rounded,
                          label: 'Fase Pengobatan',
                          value: treatmentPhase,
                        ),
                        _DetailRow(
                          icon: Icons.monitor_weight_outlined,
                          label: 'Berat Badan Awal',
                          value: '${db['initial_weight_kg'] ?? '-'} kg',
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── KARTU 2: DATA DEMOGRAFI ──
                    _buildInfoCard(
                      icon: Icons.person_outline_rounded,
                      title: 'Data Diri',
                      children: [
                        _DetailRow(
                          icon: Icons.cake_rounded,
                          label: 'Tempat, Tanggal Lahir',
                          value: '${db['birth_place'] ?? '-'}, ${_formatDate(db['birth_date'])}',
                        ),
                        _DetailRow(
                          icon: Icons.male_rounded,
                          label: 'Jenis Kelamin',
                          value: db['gender'] == 'L' ? 'Laki-laki' : (db['gender'] == 'P' ? 'Perempuan' : '-'),
                        ),
                        _DetailRow(
                          icon: Icons.phone_android_rounded,
                          label: 'Nomor Telepon',
                          value: db['phone_number'] ?? '-',
                        ),
                        _DetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Alamat',
                          value: db['address'] ?? '-',
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── KARTU 3: FASILITAS KESEHATAN ──
                    _buildInfoCard(
                      icon: Icons.local_hospital_outlined,
                      title: 'Fasilitas Kesehatan',
                      children: [
                        _DetailRow(
                          icon: Icons.medical_services_outlined,
                          label: 'Dokter Pembina',
                          value: doctor['full_name'] ?? '-',
                        ),
                        _DetailRow(
                          icon: Icons.business_rounded,
                          label: 'Rumah Sakit / Klinik',
                          value: doctor['hospital_name'] ?? db['faskes_name'] ?? '-',
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── LOGOUT BUTTON ──
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _authService.logoutPatient();
                          if (mounted) _redirectToLogin();
                        },
                        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                        label: Text(
                          'Keluar Akun',
                          style: GoogleFonts.manrope(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(String name, String nik) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      decoration: const BoxDecoration(
        color: Color(0xFF112D4E),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _initials(name),
                style: GoogleFonts.manrope(
                  color: const Color(0xFF112D4E),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'NIK: $nik',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A112D4E),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF2A609C), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: const Color(0xFF001833),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: Color(0xFFC4C6CF)),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat profil',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF112D4E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Terjadi kesalahan sistem.',
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
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: const Color(0xFFC4C6CF), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF1F2937),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
