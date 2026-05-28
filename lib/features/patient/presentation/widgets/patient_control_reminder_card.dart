import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientControlReminderCard extends StatelessWidget {
  final DateTime scheduledDate;
  final String formattedDate;
  final String location;

  const PatientControlReminderCard({
    super.key,
    required this.scheduledDate,
    required this.formattedDate,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = scheduledDate.difference(DateTime.now()).inDays;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDBE2EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x19112D4E)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notification_important_rounded,
              color: Color(0xFF112D4E), size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  daysLeft > 0
                      ? 'Pengingat Kontrol: $daysLeft Hari Lagi'
                      : daysLeft == 0
                          ? '🔔 Jadwal Kontrol Hari Ini!'
                          : '⚠️ Jadwal kontrol terlewat',
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF112D4E),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$location\n$formattedDate',
                  style: GoogleFonts.manrope(
                    color: const Color(0xCC112D4E),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.43,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
