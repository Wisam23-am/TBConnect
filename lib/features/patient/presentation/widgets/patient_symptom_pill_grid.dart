import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A common symptom item with a name label.
class SymptomItem {
  final String name;
  const SymptomItem(this.name);
}

class PatientSymptomPillGrid extends StatelessWidget {
  final List<SymptomItem> symptoms;
  final Set<String> selectedSymptoms;
  final ValueChanged<String> onToggle;

  const PatientSymptomPillGrid({
    super.key,
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
