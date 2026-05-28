import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientScheduleHeader extends StatelessWidget {
  final bool isToday;
  final bool isMaxPast;
  final String formattedDate;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const PatientScheduleHeader({
    super.key,
    required this.isToday,
    required this.isMaxPast,
    required this.formattedDate,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isToday ? 'Jadwal Hari Ini' : 'Jadwal Sebelumnya',
              style: GoogleFonts.manrope(
                color: const Color(0xFF001833),
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formattedDate,
              style: GoogleFonts.manrope(
                color: const Color(0xFF43474E),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left,
                  color: isMaxPast ? Colors.grey : const Color(0xFF112D4E)),
              onPressed: isMaxPast ? null : onPrevious,
            ),
            IconButton(
              icon: Icon(Icons.chevron_right,
                  color: isToday ? Colors.grey : const Color(0xFF112D4E)),
              onPressed: isToday ? null : onNext,
            ),
          ],
        ),
      ],
    );
  }
}
