import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/auth_service.dart';
import '../../../services/patient_service.dart';

// =============================================================================
// Data Models
// =============================================================================

/// Mood/condition level enum with display metadata.
enum MoodLevel {
  sangat_buruk('Sangat Buruk', '😞', Color(0xFFE63946), Color(0xFFFFEBEE)),
  kurang_baik('Kurang Baik', '😐', Color(0xFF666666), Color(0xFFF5F5F5)),
  cukup_baik('Cukup Baik', '🙂', Color(0xFF2A609C), Color(0xFFE3F2FD)),
  sangat_baik('Sangat Baik', '😊', Color(0xFF2A609C), Color(0xFFE3F2FD));

  final String label;
  final String emoji;
  final Color color;
  final Color bgColor;
  const MoodLevel(this.label, this.emoji, this.color, this.bgColor);
}

/// A common symptom item with a name label.
class _SymptomItem {
  final String name;
  const _SymptomItem(this.name);
}

/// An emergency symptom item with name and icon.
class _EmergencySymptomItem {
  final String name;
  final IconData icon;
  const _EmergencySymptomItem(this.name, this.icon);
}

// =============================================================================
// Constants
// =============================================================================

const _kCommonSymptoms = [
  _SymptomItem('Batuk'),
  _SymptomItem('Keringat Malam'),
  _SymptomItem('Berat Badan Turun'),
  _SymptomItem('Lemas / Lelah'),
];

const _kEmergencySymptoms = [
  _EmergencySymptomItem('Efek samping obat', Icons.local_pharmacy_outlined),
  _EmergencySymptomItem('Pingsan', Icons.person_off_outlined),
  _EmergencySymptomItem('Ruam Parah', Icons.error_outline),
  _EmergencySymptomItem('Muntah Berat', Icons.sick_outlined),
  _EmergencySymptomItem('Kulit Menguning', Icons.warning_amber_outlined),
  _EmergencySymptomItem('Gangguan Penglihatan', Icons.visibility_off_outlined),
  _EmergencySymptomItem('Batuk Berdarah', Icons.bloodtype_outlined),
  _EmergencySymptomItem('Sesak Nafas', Icons.air_outlined),
  _EmergencySymptomItem('Nyeri Dada', Icons.favorite_outlined),
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
            _SectionTitle('Bagaimana perasaan Anda hari ini?'),
            const SizedBox(height: 16),
            _MoodSelector(
              selectedMood: _selectedMood,
              onMoodSelected: (mood) => setState(() => _selectedMood = mood),
            ),
            const SizedBox(height: 32),

            // ── Common Symptoms ──
            _SectionTitle('Gejala yang dirasakan?'),
            const SizedBox(height: 16),
            _SymptomPillGrid(
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
            _EmergencySymptomsSection(
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
            _SectionTitle('Catatan Tambahan kepada Dokter'),
            const SizedBox(height: 12),
            _NotesField(controller: _notesController),
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

// =============================================================================
// Reusable Widgets
// =============================================================================

/// Section title text.
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        color: const Color(0xFF001833),
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.16,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mood Selector — row of 4 circular mood cards
// ─────────────────────────────────────────────────────────────────────────────

class _MoodSelector extends StatelessWidget {
  final MoodLevel? selectedMood;
  final ValueChanged<MoodLevel> onMoodSelected;

  const _MoodSelector({
    required this.selectedMood,
    required this.onMoodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: MoodLevel.values.map((mood) {
        final isSelected = selectedMood == mood;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: mood == MoodLevel.values.first ? 0 : 8,
              right: mood == MoodLevel.values.last ? 0 : 8,
            ),
            child: _MoodCard(
              mood: mood,
              isSelected: isSelected,
              onTap: () => onMoodSelected(mood),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MoodCard extends StatelessWidget {
  final MoodLevel mood;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodCard({
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF2A609C) : const Color(0xFFE1E3E4),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0x1E2A609C),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: mood.bgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  mood.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mood.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: const Color(0xFF001833),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Symptom Pill Grid — wrapping pill-shaped toggle buttons
// ─────────────────────────────────────────────────────────────────────────────

class _SymptomPillGrid extends StatelessWidget {
  final List<_SymptomItem> symptoms;
  final Set<String> selectedSymptoms;
  final ValueChanged<String> onToggle;

  const _SymptomPillGrid({
    required this.symptoms,
    required this.selectedSymptoms,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: symptoms.map((item) {
        final isSelected = selectedSymptoms.contains(item.name);
        return GestureDetector(
          onTap: () => onToggle(item.name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2A609C) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2A609C)
                    : const Color(0xFFE1E3E4),
              ),
            ),
            child: Text(
              item.name,
              style: GoogleFonts.manrope(
                color: isSelected ? Colors.white : const Color(0xFF43474E),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Emergency Symptoms Section — red card with 2-column grid
// ─────────────────────────────────────────────────────────────────────────────

class _EmergencySymptomsSection extends StatelessWidget {
  final List<_EmergencySymptomItem> symptoms;
  final Set<String> selectedSymptoms;
  final ValueChanged<String> onToggle;

  const _EmergencySymptomsSection({
    required this.symptoms,
    required this.selectedSymptoms,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_rounded,
                  color: Color(0xFFC62828), size: 22),
              const SizedBox(width: 10),
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
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
            children: symptoms
                .map((item) => _EmergencySymptomCard(
                      item: item,
                      isSelected: selectedSymptoms.contains(item.name),
                      onTap: () => onToggle(item.name),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _EmergencySymptomCard extends StatelessWidget {
  final _EmergencySymptomItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _EmergencySymptomCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEF5350) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFC62828) : const Color(0xFFE1E3E4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              color: isSelected ? Colors.white : const Color(0xFFC62828),
              size: 24,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: isSelected ? Colors.white : const Color(0xFF43474E),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notes Field — large text area with gray background
// ─────────────────────────────────────────────────────────────────────────────

class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  const _NotesField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E3E4)),
      ),
      child: TextField(
        controller: controller,
        maxLines: 5,
        decoration: InputDecoration(
          hintText: 'Tuliskan keluhan atau catatan lain di sini...',
          hintStyle: GoogleFonts.manrope(
            color: const Color(0xFFC4C6CF),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        style: GoogleFonts.manrope(
          color: const Color(0xFF43474E),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
