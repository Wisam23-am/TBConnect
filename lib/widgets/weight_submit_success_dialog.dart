import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget Dialog untuk menampilkan pesan sukses input berat badan
/// Dialog ini akan otomatis ditutup setelah 2 detik
class WeightSubmitSuccessDialog extends StatefulWidget {
  const WeightSubmitSuccessDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const WeightSubmitSuccessDialog(),
    );
  }

  @override
  State<WeightSubmitSuccessDialog> createState() =>
      _WeightSubmitSuccessDialogState();
}

class _WeightSubmitSuccessDialogState extends State<WeightSubmitSuccessDialog> {
  @override
  void initState() {
    super.initState();
    // Otomatis tutup setelah 2 detik
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon dengan background
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFD4E3FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                size: 40,
                color: Color(0xFF2A609C),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Anda sudah mengisi berat\nbadan minggu ini',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: const Color(0xFF001833),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.56,
                letterSpacing: -0.18,
              ),
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              'Untuk akurasi pemantauan, berat badan hanya perlu diperbarui satu kali setiap minggunya.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: const Color(0xFF5A8DA0),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.57,
              ),
            ),
            const SizedBox(height: 32),

            // Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF001833),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  'Ok, Mengerti',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
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
