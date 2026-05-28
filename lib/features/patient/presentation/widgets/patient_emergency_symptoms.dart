import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// An emergency symptom item with name and icon.
class EmergencySymptomItem {
  final String name;
  final IconData icon;
  const EmergencySymptomItem(this.name, this.icon);
}

class PatientEmergencySymptomsSection extends StatelessWidget {
  final List<EmergencySymptomItem> symptoms;
  final Set<String> selectedSymptoms;
  final ValueChanged<String> onToggle;

  const PatientEmergencySymptomsSection({
    super.key,
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
  final EmergencySymptomItem item;
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
