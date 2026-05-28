import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientMedicationReminderSection extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final VoidCallback onTakeMedication;

  const PatientMedicationReminderSection({
    super.key,
    required this.schedule,
    required this.onTakeMedication,
  });

  @override
  Widget build(BuildContext context) {
    // Tentukan waktu sesi dari label_id (misal: 'morning', 'evening')
    String getSessionTime(String labelId) {
      if (labelId.contains('morning')) return '06:00 - 09:00';
      if (labelId.contains('afternoon')) return '12:00 - 15:00';
      if (labelId.contains('evening')) return '18:00 - 21:00';
      return 'Sesuai Jadwal';
    }

    final String sessionLabel = schedule['label_id'] ?? 'Sesi Minum Obat';
    final String timeWindow = getSessionTime(sessionLabel);
    final List<String> meds =
        (schedule['medications'] as List?)?.cast<String>() ??
            ['Rifampisin', 'Isoniazid', 'Pyrazinamide', 'Ethambutol'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              const Icon(Icons.medication_liquid_rounded,
                  color: Color(0xFF112D4E)),
              const SizedBox(width: 8),
              Text(
                'Jadwal Minum Obat Anda',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF112D4E),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _MedicationReminderCard(
            sessionName: sessionLabel.toUpperCase(),
            timeWindow: timeWindow,
            medications: meds,
            onTake: onTakeMedication,
          ),
        ),
        const SizedBox(height: 24),
        Container(height: 8, color: const Color(0xFFF3F5F9)), // Separator
      ],
    );
  }
}

class _MedicationReminderCard extends StatelessWidget {
  final String sessionName;
  final String timeWindow;
  final List<String> medications;
  final VoidCallback onTake;

  const _MedicationReminderCard({
    required this.sessionName,
    required this.timeWindow,
    required this.medications,
    required this.onTake,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Merah (Urgent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF1F1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFFFE4E4)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Belum Diminum',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0xFFFFE4E4)),
                  ),
                  child: Text(
                    timeWindow,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionName,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                // Daftar Obat
                ...medications.map((med) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            med,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 20),
                // Tombol Konfirmasi
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTake,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF112D4E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Konfirmasi Minum Obat',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
