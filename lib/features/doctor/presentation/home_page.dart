import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tbconnect/pages/doctor/add_patient_page.dart';
import 'package:tbconnect/pages/doctor/doctor_feedback_page.dart';
import 'package:tbconnect/pages/doctor/doctor_profile_page.dart';
import 'package:tbconnect/pages/doctor/patient_detail_page.dart';
import 'package:tbconnect/widgets/doctor_bottom_nav_bar.dart';
import 'package:tbconnect/services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DoctorService _doctorService = DoctorService();

  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String? _errorMessage;

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTriageData();
  }

  Future<void> _loadTriageData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _doctorService.getTriageBoard();
      if (mounted) {
        setState(() {
          _patients = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data: $e';
        });
      }
    }
  }

  String get _dayLabel {
    final weekday = _selectedDate.weekday;
    const names = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return names[weekday - 1];
  }

  String get _monthLabel {
    const names = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return names[_selectedDate.month - 1];
  }

  Future<void> _pickLogDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF112D4E)),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tanggal log dipilih: ${picked.day} $_monthLabel ${picked.year}'),
        ),
      );
    }
  }

  void _handleNavTap(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddPatientPage()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DoctorProfilePage()),
      );
    }
  }

  // ──────────────────────────────────────────────
  // Helper: ambil status & warna berdasarkan triage
  // ──────────────────────────────────────────────
  ({String label, Color color, String subtitle}) _resolveStatus(
      Map<String, dynamic> patient) {
    final hasEmergency = patient['has_emergency_symptom'] == true;
    final hasMissed = patient['has_missed_medication'] == true;
    final priority = patient['priority_level'] as int? ?? 3;

    if (hasEmergency || priority == 1) {
      return (
        label: 'Segera',
        color: const Color(0xFFDE2C2C),
        subtitle: 'Gejala darurat terdeteksi',
      );
    } else if (hasMissed || priority == 2) {
      return (
        label: 'Terlambat',
        color: const Color(0xFF527BBF),
        subtitle: 'Belum lapor minum obat hari ini',
      );
    } else {
      return (
        label: 'Stabil',
        color: const Color(0xFF4B7DD8),
        subtitle: 'Tidak ada gejala berat',
      );
    }
  }

  // ──────────────────────────────────────────────
  // Helper: teks log harian
  // ──────────────────────────────────────────────
  String _dailyLogText(Map<String, dynamic> patient) {
    final adherence = patient['adherence_7d_pct'];
    final weight = patient['latest_weight_kg'];

    final parts = <String>[];
    if (adherence != null) {
      parts.add('Kepatuhan 7 hari: $adherence%');
    }
    if (weight != null) {
      parts.add('Berat terbaru: $weight kg');
    }
    if (parts.isEmpty) {
      return 'Belum ada data laporan harian.';
    }
    return parts.join(' | ');
  }

  // ──────────────────────────────────────────────
  // Helper: gejala yang terdeteksi
  // ──────────────────────────────────────────────
  List<String> _symptoms(Map<String, dynamic> patient) {
    final list = <String>[];
    if (patient['has_emergency_symptom'] == true) {
      list.add('Gejala Darurat');
    }
    if (patient['has_missed_medication'] == true) {
      list.add('Obat Terlewat');
    }
    final adherence = patient['adherence_7d_pct'];
    if (adherence != null && (adherence as num) < 80) {
      list.add('Kepatuhan Rendah');
    }
    if (list.isEmpty) {
      list.add('Tidak ada gejala');
    }
    return list;
  }

  // ──────────────────────────────────────────────
  // Helper: catatan tambahan
  // ──────────────────────────────────────────────
  String _additionalNote(Map<String, dynamic> patient) {
    final hasEmergency = patient['has_emergency_symptom'] == true;
    final hasMissed = patient['has_missed_medication'] == true;
    final adherence = patient['adherence_7d_pct'];

    if (hasEmergency) {
      return '⚠️ Pasien melaporkan gejala darurat. Segera lakukan evaluasi dan konfirmasi kondisi pasien.';
    }
    if (hasMissed) {
      return 'Hubungi pasien untuk memastikan kondisi dan mengingatkan minum obat.';
    }
    if (adherence != null && (adherence as num) < 80) {
      return 'Kepatuhan minum obat perlu ditingkatkan. Berikan edukasi dan motivasi ke pasien.';
    }
    return 'Pasien dalam kondisi stabil. Pantau secara rutin.';
  }

  // ──────────────────────────────────────────────
  // Helper: inisial
  // ──────────────────────────────────────────────
  String _initials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: Colors.white,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF112D4E),
                    )),
                Text('Pantau pasien Anda secara real-time',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: const Color(0xFF5A8DA0),
                    )),
              ],
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Color(0xFFE5F0FF),
              child: Icon(Icons.person, color: Color(0xFF112D4E)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTriageData,
          color: const Color(0xFF112D4E),
          child: _buildBody(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickLogDate,
        backgroundColor: const Color(0xFF112D4E),
        child: const Icon(Icons.calendar_today),
      ),
      bottomNavigationBar: DoctorBottomNavBar(
        currentIndex: 0,
        onTap: _handleNavTap,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF112D4E)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 64, color: Color(0xFFC4C6CF)),
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
                onPressed: _loadTriageData,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      children: [
        _buildDateCard(),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('Daftar Prioritas',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF112D4E),
                )),
            const Spacer(),
            Text('${_patients.length} pasien',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: const Color(0xFF5A8DA0),
                )),
          ],
        ),
        const SizedBox(height: 14),
        if (_patients.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.people_outline_rounded,
                      size: 64, color: Color(0xFFC4C6CF)),
                  const SizedBox(height: 12),
                  Text('Belum ada pasien',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF112D4E),
                      )),
                  const SizedBox(height: 4),
                  Text('Tambahkan pasien baru untuk memulai',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: const Color(0xFF5A8DA0),
                      )),
                ],
              ),
            ),
          )
        else
          ..._patients.map((patient) => _buildPatientCard(patient)),
      ],
    );
  }

  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Text('Hari ini',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF5A8DA0),
              )),
          const SizedBox(height: 8),
          Text('$_dayLabel, ${_selectedDate.day} $_monthLabel ${_selectedDate.year}',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF112D4E),
              )),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final name = patient['full_name'] as String? ?? 'Pasien';
    final patientId = patient['patient_id'] as String?;
    final status = _resolveStatus(patient);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A112D4E),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE5F0FF),
                child: Text(
                  _initials(name),
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF112D4E),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF112D4E),
                        )),
                    const SizedBox(height: 6),
                    Text(status.subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: const Color(0xFF5A8DA0),
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(status.label,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: status.color,
                    )),
              ),
            ],
          ),
          children: [
            const SizedBox(height: 4),
            _buildInfoRow(
              icon: Icons.medication_rounded,
              title: 'Log Harian Terakhir',
              description: _dailyLogText(patient),
            ),
            const SizedBox(height: 14),
            Text('Gejala Terdeteksi',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _symptoms(patient)
                  .map((symptom) => Chip(
                        visualDensity: VisualDensity.compact,
                        labelStyle: GoogleFonts.manrope(
                            fontSize: 12, color: const Color(0xFF112D4E)),
                        backgroundColor: const Color(0xFFEAF2FF),
                        label: Text(symptom),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            _buildInfoRow(
              icon: Icons.note_alt_outlined,
              title: 'Catatan Tambahan',
              description: _additionalNote(patient),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DoctorFeedbackPage(
                            patientName: name,
                            patientId: patientId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF112D4E),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Berikan Feedback'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientDetailPage(
                            patientName: name,
                            patientId: patientId,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC4C6CF)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Detail Pasien'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1A4D7A)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  )),
              const SizedBox(height: 4),
              Text(description,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: const Color(0xFF5A8DA0),
                    height: 1.4,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}
