import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/auth_service.dart';
import '../../../services/patient_service.dart';
import 'widgets/patient_section_title.dart';
import 'widgets/patient_mood_selector.dart';
import 'widgets/patient_symptom_pill_grid.dart';
import 'widgets/patient_emergency_symptoms.dart';
import 'widgets/patient_notes_field.dart';

// =============================================================================
// Constants
// =============================================================================

const _kCommonSymptoms = [
  SymptomItem('Batuk'),
  SymptomItem('Keringat Malam'),
  SymptomItem('Berat Badan Turun'),
  SymptomItem('Lemas / Lelah'),
];

const _kEmergencySymptoms = [
  EmergencySymptomItem('Efek samping obat', Icons.local_pharmacy_outlined),
  EmergencySymptomItem('Pingsan', Icons.person_off_outlined),
  EmergencySymptomItem('Ruam Parah', Icons.error_outline),
  EmergencySymptomItem('Muntah Berat', Icons.sick_outlined),
  EmergencySymptomItem('Kulit Menguning', Icons.warning_amber_outlined),
  EmergencySymptomItem('Gangguan Penglihatan', Icons.visibility_off_outlined),
  EmergencySymptomItem('Batuk Berdarah', Icons.bloodtype_outlined),
  EmergencySymptomItem('Sesak Nafas', Icons.air_outlined),
  EmergencySymptomItem('Nyeri Dada', Icons.favorite_outlined),
];

// =============================================================================
// Main Page
// =============================================================================

class PatientSymptomsPage extends StatefulWidget {
  const PatientSymptomsPage({super.key});

  @override
  State<PatientSymptomsPage> createState() => _PatientSymptomsPageState();
}

class _PatientSymptomsPageState extends State<PatientSymptomsPage> {
  final _authService = AuthService();
  final _patientService = PatientDataService();
  final _notesController = TextEditingController();

  MoodLevel? _selectedMood;
  final Set<String> _selectedSymptoms = {};
  final Set<String> _selectedEmergencySymptoms = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadTodayReport();
  }

  /// Load today's existing report to pre-fill the form (if any).
  Future<void> _loadTodayReport() async {
    try {
      final session = await _authService.getPatientSession();
      if (session == null) return;

      final report = await _patientService.getTodaySymptomReport(
        patientId: session.patientId,
      );
      if (report == null || !mounted) return;

      // Pre-fill mood
      final moodStr = report['mood_level'] as String?;
      if (moodStr != null) {
        _selectedMood = MoodLevel.values.firstWhere(
          (m) => m.name == moodStr,
          orElse: () => MoodLevel.cukup_baik,
        );
      }

      // Pre-fill symptoms
      final symptoms = (report['symptoms'] as List?)?.cast<String>() ?? [];
      _selectedSymptoms.addAll(symptoms);

      // Pre-fill emergency symptoms
      final emergency =
          (report['emergency_symptoms'] as List?)?.cast<String>() ?? [];
      _selectedEmergencySymptoms.addAll(emergency);

      // Pre-fill notes
      final notes = report['notes'] as String?;
      if (notes != null && notes.isNotEmpty) {
        _notesController.text = notes;
      }

      setState(() {});
    } catch (_) {
      // Silently ignore — form stays empty
    }
  }

  Future<bool> _submitReport() async {
    if (_selectedMood == null) {
      _showSnackBar(
        'Pilih kondisi kesehatan Anda terlebih dahulu',
        Colors.orange,
      );
      return false;
    }

    final session = await _authService.getPatientSession();
    if (session == null) {
      _showSnackBar('Sesi tidak valid', Colors.redAccent);
      return false;
    }

    try {
      setState(() => _isSubmitting = true);

      await _patientService.saveDailySymptomReport(
        patientId: session.patientId,
        moodLevel: _selectedMood!.name,
        symptoms: _selectedSymptoms.toList(),
        emergencySymptoms: _selectedEmergencySymptoms.toList(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        _showSnackBar(
          '✅ Laporan gejala hari ini berhasil disimpan',
          const Color(0xFF2E7D32),
        );
        _resetForm();
      }
      return true;
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal menyimpan: $e', Colors.redAccent);
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedMood = null;
      _selectedSymptoms.clear();
      _selectedEmergencySymptoms.clear();
      _notesController.clear();
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monitor_heart_outlined,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Monitoring Gejala',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.22,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF112D4E), Color(0xFF3F72AF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mood Selector ──
            const PatientSectionTitle('Bagaimana perasaan Anda hari ini?'),
            const SizedBox(height: 16),
            PatientMoodSelector(
              selectedMood: _selectedMood,
              onMoodSelected: (mood) => setState(() => _selectedMood = mood),
            ),
            const SizedBox(height: 32),

            // ── Common Symptoms ──
            const PatientSectionTitle('Gejala yang dirasakan?'),
            const SizedBox(height: 16),
            PatientSymptomPillGrid(
              symptoms: _kCommonSymptoms,
              selectedSymptoms: _selectedSymptoms,
              onToggle: (name) {
                setState(() {
                  if (_selectedSymptoms.contains(name)) {
                    _selectedSymptoms.remove(name);
                  } else {
                    _selectedSymptoms.add(name);
                  }
                });
              },
            ),
            const SizedBox(height: 32),

            // ── Emergency Symptoms ──
            PatientEmergencySymptomsSection(
              symptoms: _kEmergencySymptoms,
              selectedSymptoms: _selectedEmergencySymptoms,
              onToggle: (name) {
                setState(() {
                  if (_selectedEmergencySymptoms.contains(name)) {
                    _selectedEmergencySymptoms.remove(name);
                  } else {
                    _selectedEmergencySymptoms.add(name);
                  }
                });
              },
            ),
            const SizedBox(height: 32),

            // ── Notes ──
            const PatientSectionTitle('Catatan Tambahan kepada Dokter'),
            const SizedBox(height: 12),
            PatientNotesField(controller: _notesController),
            const SizedBox(height: 32),

            // ── Submit Button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF001833),
                  disabledBackgroundColor: const Color(0xFFCED4DB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
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
          ],
        ),
      ),
    );
  }
}
