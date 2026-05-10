import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tbconnect/pages/doctor/add_patient_page.dart';
import 'package:tbconnect/pages/doctor/doctor_feedback_page.dart';
import 'package:tbconnect/pages/doctor/doctor_profile_page.dart';
import 'package:tbconnect/pages/doctor/patient_detail_page.dart';
import 'package:tbconnect/widgets/doctor_bottom_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<_PriorityPatient> _patients = [
    _PriorityPatient(
      name: 'Budi Widodo',
      subtitle: 'Batuk Berdarah',
      status: 'Segera',
      statusColor: const Color(0xFFDE2C2C),
      dailyLog: 'Pasien melaporkan minum obat tepat waktu hari ini.',
      symptoms: ['Batuk', 'Darah'],
      note: 'Segera lakukan evaluasi mendalam dan konfirmasi ketersediaan obat yang sesuai.',
    ),
    _PriorityPatient(
      name: 'Siti Aminah',
      subtitle: 'Tidak ada gejala berat',
      status: 'Stabil',
      statusColor: const Color(0xFF4B7DD8),
      dailyLog: 'Pasien melaporkan minum obat tepat waktu hari ini.',
      symptoms: ['Batuk', 'Demam Ringan'],
      note: 'Sedikit mual setelah makan siang tetapi sudah membaik.',
    ),
    _PriorityPatient(
      name: 'Ahmad Suryana',
      subtitle: 'Belum lapor 2 hari',
      status: 'Terlambat',
      statusColor: const Color(0xFF527BBF),
      dailyLog: 'Pasien belum mengirim laporan minum obat selama dua hari terakhir.',
      symptoms: ['Belum Lapor'],
      note: 'Hubungi pasien dan pastikan ia kembali mengisi laporan harian.',
    ),
  ];

  DateTime _selectedDate = DateTime.now();

  String get _dayLabel {
    final weekday = _selectedDate.weekday;
    const names = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return names[weekday - 1];
  }

  String get _monthLabel {
    const names = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
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

    if (picked != null) {
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=3'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
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
            ..._patients.map((patient) => _buildPatientCard(patient)).toList(),
            const SizedBox(height: 100),
          ],
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

  Widget _buildPatientCard(_PriorityPatient patient) {
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
                  patient.initials,
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
                    Text(patient.name,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF112D4E),
                        )),
                    const SizedBox(height: 6),
                    Text(patient.subtitle,
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
                  color: patient.statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(patient.status,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: patient.statusColor,
                    )),
              ),
            ],
          ),
          children: [
            const SizedBox(height: 4),
            _buildInfoRow(
              icon: Icons.medication_rounded,
              title: 'Log Harian Terakhir',
              description: patient.dailyLog,
            ),
            const SizedBox(height: 14),
            Text('Gejala Dilaporkan',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: patient.symptoms
                  .map((symptom) => Chip(
                        visualDensity: VisualDensity.compact,
                        labelStyle: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF112D4E)),
                        backgroundColor: const Color(0xFFEAF2FF),
                        label: Text(symptom),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            _buildInfoRow(
              icon: Icons.note_alt_outlined,
              title: 'Catatan Tambahan',
              description: patient.note,
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
                          builder: (_) => DoctorFeedbackPage(patientName: patient.name),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF112D4E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          builder: (_) => PatientDetailPage(patientName: patient.name),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC4C6CF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  Widget _buildInfoRow({required IconData icon, required String title, required String description}) {
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

class _PriorityPatient {
  final String name;
  final String subtitle;
  final String status;
  final Color statusColor;
  final String dailyLog;
  final List<String> symptoms;
  final String note;

  _PriorityPatient({
    required this.name,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.dailyLog,
    required this.symptoms,
    required this.note,
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }
}
