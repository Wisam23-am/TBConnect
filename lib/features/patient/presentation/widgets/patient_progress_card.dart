import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientProgressCard extends StatelessWidget {
  final int treatmentMonth;

  const PatientProgressCard({super.key, required this.treatmentMonth});

  @override
  Widget build(BuildContext context) {
    final progress = treatmentMonth / 6;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PROGRESS PENGOBATAN',
                style: GoogleFonts.manrope(
                  color: const Color(0xFF43474E),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.60,
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Bulan $treatmentMonth ',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF001833),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: 'dari 6',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF43474E),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: const Color(0xFFEDEEEF),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF2A609C)),
            ),
          ),
        ],
      ),
    );
  }
}
