import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../features/auth/presentation/portal_role_screen.dart';
import 'add_patient_page.dart';
import 'patient_qr_page.dart';

class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _doctorProfile;
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _authService.getDoctorProfile();
      final doctorId = _supabase.auth.currentUser!.id;
      final patients = await _supabase
          .from('patients')
          .select(
              'id, full_name, age, gender, qr_code, is_activated, status, treatment_start_date')
          .eq('doctor_id', doctorId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _doctorProfile = profile;
          _patients = List<Map<String, dynamic>>.from(patients);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Yakin ingin keluar?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: GoogleFonts.poppins(color: const Color(0xFF5A8DA0))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
                Text('Logout', style: GoogleFonts.poppins(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4F8),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A6B8A)))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFF1A6B8A),
                child: CustomScrollView(
                  slivers: [
                    // Header
                    SliverToBoxAdapter(child: _buildHeader()),

                    // Stats row
                    SliverToBoxAdapter(child: _buildStatsRow()),

                    // Patients section title
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                        child: Row(
                          children: [
                            Text(
                              'Daftar Pasien',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A3A4A),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_patients.length} pasien',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF5A8DA0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Patient list or empty state
                    _patients.isEmpty
                        ? SliverToBoxAdapter(child: _buildEmptyState())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, index) =>
                                  _buildPatientCard(_patients[index]),
                              childCount: _patients.length,
                            ),
                          ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPatientPage()),
          );
          if (result == true) _loadData();
        },
        backgroundColor: const Color(0xFF1A6B8A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: Text('Tambah Pasien',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _doctorProfile?['full_name'] ?? 'Dokter';
    final hospital = _doctorProfile?['hospital_name'] ?? '-';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, 👋',
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: const Color(0xFF5A8DA0)),
                ),
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A3A4A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (hospital != '-')
                  Text(
                    hospital,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF5A8DA0)),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _logout,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD8EDF4)),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFF1A6B8A), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final active = _patients.where((p) => p['status'] == 'active').length;
    final notActivated =
        _patients.where((p) => p['is_activated'] == false).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _StatCard(
              label: 'Total Pasien',
              value: '${_patients.length}',
              color: const Color(0xFF1A6B8A)),
          const SizedBox(width: 12),
          _StatCard(
              label: 'Aktif Berobat',
              value: '$active',
              color: const Color(0xFF2E8B57)),
          const SizedBox(width: 12),
          _StatCard(
              label: 'Belum Aktivasi',
              value: '$notActivated',
              color: const Color(0xFFF0A500)),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final isActivated = patient['is_activated'] == true;
    final gender = patient['gender'] == 'male' ? '♂' : '♀';
    final qrCode = patient['qr_code'] ?? '-';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        shadowColor: const Color(0xFF1A6B8A).withOpacity(0.1),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientQRPage(
                patientName: patient['full_name'],
                qrCode: qrCode,
                isActivated: isActivated,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A6B8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      patient['full_name'][0].toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A6B8A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['full_name'],
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A3A4A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$gender ${patient['age']} tahun',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: const Color(0xFF5A8DA0)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.qr_code_2_rounded,
                              size: 13, color: Color(0xFF8AACBA)),
                          const SizedBox(width: 4),
                          Text(
                            qrCode,
                            style: GoogleFonts.robotoMono(
                              fontSize: 12,
                              color: const Color(0xFF5A8DA0),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActivated
                            ? const Color(0xFF2E8B57).withOpacity(0.1)
                            : const Color(0xFFF0A500).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActivated ? 'Aktif' : 'Menunggu',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isActivated
                              ? const Color(0xFF2E8B57)
                              : const Color(0xFFF0A500),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF8AACBA), size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF1A6B8A).withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.people_outline_rounded,
                size: 40, color: Color(0xFF1A6B8A)),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada pasien',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A3A4A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap tombol "Tambah Pasien" untuk\nmenambahkan pasien baru',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 13, color: const Color(0xFF5A8DA0)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: color.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
