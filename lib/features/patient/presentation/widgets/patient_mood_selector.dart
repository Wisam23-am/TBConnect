import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

class PatientMoodSelector extends StatelessWidget {
  final MoodLevel? selectedMood;
  final ValueChanged<MoodLevel> onMoodSelected;

  const PatientMoodSelector({
    super.key,
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
