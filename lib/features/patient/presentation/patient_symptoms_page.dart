import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/patient_bottom_nav_bar.dart';
import 'patient_home_page.dart';
import 'patient_weight_progress_page.dart';

enum ConditionLevel {
  sangat_buruk,
  kurang_baik,
  cukup_baik,
  sangat_baik,
}

class PatientSymptomsPage extends StatefulWidget {
  const PatientSymptomsPage({super.key});

  @override
  State<PatientSymptomsPage> createState() => _PatientSymptomsPageState();
}

class _PatientSymptomsPageState extends State<PatientSymptomsPage> {
  final _authService = AuthService();
  final _patientService = PatientDataService();
  final _notesController = TextEditingController();

  int _selectedNavIndex = 1; // Gejala tab

  // State untuk kondisi kesehatan
  ConditionLevel? _selectedCondition;

  // State untuk gejala umum
  Set<String> _selectedSymptoms = {};
  final List<String> _commonSymptoms = [
    'Batuk',
    'Keringat Malam',
    'Berat Badan Turun',
    'Lemas / Lelah',
  ];

  // State untuk gejala darurat
  Set<String> _selectedEmergencySymptoms = {};
  final List<Map<String, dynamic>> _emergencySymptoms = [
    {'name': 'Efek samping obat', 'icon': Icons.local_pharmacy_outlined},
    {'name': 'Pingsan', 'icon': Icons.person_off_outlined},
    {'name': 'Ruam Parah', 'icon': Icons.error_outline},
    {'name': 'Muntah Berat', 'icon': Icons.sick_outlined},
    {'name': 'Kulit Menguning', 'icon': Icons.warning_amber_outlined},
    {'name': 'Gangguan Penglihatan', 'icon': Icons.visibility_off_outlined},
    {'name': 'Batuk Berdarah', 'icon': Icons.bloodtype_outlined},
    {'name': 'Sesak Nafas', 'icon': Icons.air_outlined},
    {'name': 'Nyeri Dada', 'icon': Icons.favorite_outlined},
  ];

  bool _isSubmitting = false;

  Future<void> _submitSymptoms() async {
    if (_selectedCondition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kondisi kesehatan Anda terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final session = await _authService.getPatientSession();
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi tidak valid'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Hitung nausea, dizziness, fatigue dari symptoms yang dipilih
    int nauseaLevel = _selectedSymptoms.contains('Muntah Berat') ? 3 : 0;
    int dizzinessLevel = _selectedSymptoms.contains('Pingsan') ? 3 : 0;
    int fatigueLevel = _selectedSymptoms.contains('Lemas / Lelah') ? 3 : 0;

    bool hemoptysis = _selectedEmergencySymptoms.contains('Batuk Berdarah');
    bool chestPain = _selectedEmergencySymptoms.contains('Nyeri Dada');
    bool shortnessOfBreath = _selectedEmergencySymptoms.contains('Sesak Nafas');

    try {
      setState(() => _isSubmitting = true);

      await _patientService.logSymptoms(
        patientId: session.patientId,
        nauseaLevel: nauseaLevel,
        dizzinessLevel: dizzinessLevel,
        fatigueLevel: fatigueLevel,
        hemoptysis: hemoptysis,
        chestPain: chestPain,
        shortnessOfBreath: shortnessOfBreath,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Laporan gejala hari ini berhasil disimpan',
              style: GoogleFonts.manrope(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );

        // Reset form
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _handleBottomNavTap(int index) {
    if (index == _selectedNavIndex) return;

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PatientHomePage(
            initialNavIndex: 3,
            allowGuestMode: true,
          ),
        ),
      );
      return;
    }

    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PatientWeightProgressPage()),
      );
      return;
    }

    setState(() => _selectedNavIndex = index);
  }

  void _resetForm() {
    setState(() {
      _selectedCondition = null;
      _selectedSymptoms.clear();
      _selectedEmergencySymptoms.clear();
      _notesController.clear();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF001833),
            size: 24,
          ),
        ),
        title: Text(
          'Monitoring Gejala',
          style: GoogleFonts.manrope(
            color: const Color(0xFF001833),
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.22,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFD4E3FF),
              child: IconButton(
                icon: const Icon(Icons.person, color: Color(0xFF2A609C)),
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────────────────────
            // Kondisi Kesehatan Section
            // ─────────────────────────────────────────────────────────
            Text(
              'Bagaimana perasaan Anda hari ini?',
              style: GoogleFonts.manrope(
                color: const Color(0xFF001833),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih ikon yang paling menggambarkan kondisi Anda saat ini.',
              style: GoogleFonts.manrope(
                color: const Color(0xFF5A8DA0),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),

            // Grid kondisi (2x2)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1,
              children: [
                _buildConditionCard(
                  condition: ConditionLevel.sangat_buruk,
                  label: 'Sangat Buruk',
                  icon: Icons.sentiment_very_dissatisfied,
                  iconColor: const Color(0xFFE63946),
                  bgColor: const Color(0xFFFFEBEE),
                ),
                _buildConditionCard(
                  condition: ConditionLevel.kurang_baik,
                  label: 'Kurang Baik',
                  icon: Icons.sentiment_dissatisfied,
                  iconColor: const Color(0xFF666666),
                  bgColor: const Color(0xFFF5F5F5),
                ),
                _buildConditionCard(
                  condition: ConditionLevel.cukup_baik,
                  label: 'Cukup Baik',
                  icon: Icons.sentiment_satisfied,
                  iconColor: const Color(0xFF2A609C),
                  bgColor: const Color(0xFFE3F2FD),
                ),
                _buildConditionCard(
                  condition: ConditionLevel.sangat_baik,
                  label: 'Sangat Baik',
                  icon: Icons.sentiment_very_satisfied,
                  iconColor: const Color(0xFFFFC107),
                  bgColor: const Color(0xFFFFF9E6),
                  isSelected: _selectedCondition == ConditionLevel.sangat_baik,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ─────────────────────────────────────────────────────────
            // Gejala yang Dirasakan Section
            // ─────────────────────────────────────────────────────────
            Text(
              'Gejala yang dirasakan?',
              style: GoogleFonts.manrope(
                color: const Color(0xFF001833),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.16,
              ),
            ),
            const SizedBox(height: 16),

            // Checkbox list untuk gejala umum
            Column(
              children: _commonSymptoms
                  .map((symptom) => _buildSymptomCheckbox(symptom))
                  .toList(),
            ),
            const SizedBox(height: 32),

            // ─────────────────────────────────────────────────────────
            // Gejala Darurat Section
            // ─────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF5350)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_rounded,
                          color: Color(0xFFC62828), size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Gejala Darurat',
                        style: GoogleFonts.manrope(
                          color: const Color(0xFFC62828),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Segera hubungi fasilitas kesehatan jika Anda mengalami gejala ini.',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF5A8DA0),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.54,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Grid gejala darurat
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: _emergencySymptoms
                        .map((symptom) => _buildEmergencySymptomCard(
                              symptom['name'],
                              symptom['icon'],
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ─────────────────────────────────────────────────────────
            // Catatan Tambahan Section
            // ─────────────────────────────────────────────────────────
            Text(
              'Catatan Tambahan kepada Dokter',
              style: GoogleFonts.manrope(
                color: const Color(0xFF001833),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.16,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tuliskan keluhan atau catatan lain di sini...',
                hintStyle: GoogleFonts.manrope(
                  color: const Color(0xFFC4C6CF),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE1E3E4)),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: GoogleFonts.manrope(
                color: const Color(0xFF43474E),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // ─────────────────────────────────────────────────────────
            // Submit Button
            // ─────────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitSymptoms,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF001833),
                  disabledBackgroundColor: const Color(0xFFCED4DB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Simpan Laporan Hari Ini',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.60,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: PatientBottomNavBar(
        currentIndex: _selectedNavIndex,
        items: const [
          PatientBottomNavItem(icon: Icons.home_rounded, label: 'Beranda'),
          PatientBottomNavItem(
              icon: Icons.monitor_heart_outlined, label: 'Gejala'),
          PatientBottomNavItem(icon: Icons.medication_rounded, label: 'Obat'),
          PatientBottomNavItem(icon: Icons.person_rounded, label: 'Profil'),
        ],
        onTap: _handleBottomNavTap,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Helper Widgets
  // ──────────────────────────────────────────────────────────────

  Widget _buildConditionCard({
    required ConditionLevel condition,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    bool isSelected = false,
  }) {
    final isThisSelected = _selectedCondition == condition;

    return GestureDetector(
      onTap: () => setState(() => _selectedCondition = condition),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isThisSelected ? const Color(0xFF2A609C) : Colors.transparent,
            width: isThisSelected ? 2 : 0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: const Color(0xFF001833),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isThisSelected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(Icons.check_circle,
                    color: const Color(0xFF2A609C), size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomCheckbox(String symptom) {
    final isChecked = _selectedSymptoms.contains(symptom);

    return GestureDetector(
      onTap: () => setState(() {
        if (isChecked) {
          _selectedSymptoms.remove(symptom);
        } else {
          _selectedSymptoms.add(symptom);
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isChecked ? const Color(0xFFE3F2FD) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isChecked ? const Color(0xFF2A609C) : const Color(0xFFE1E3E4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              symptom,
              style: GoogleFonts.manrope(
                color: const Color(0xFF43474E),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isChecked ? const Color(0xFF2A609C) : Colors.transparent,
                border: Border.all(
                  color: isChecked
                      ? const Color(0xFF2A609C)
                      : const Color(0xFFC4C6CF),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: isChecked
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencySymptomCard(String symptom, IconData icon) {
    final isSelected = _selectedEmergencySymptoms.contains(symptom);

    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedEmergencySymptoms.remove(symptom);
        } else {
          _selectedEmergencySymptoms.add(symptom);
        }
      }),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEF5350) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFC62828) : const Color(0xFFE1E3E4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFFC62828),
              size: 28,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                symptom,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: isSelected ? Colors.white : const Color(0xFF43474E),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
