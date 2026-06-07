import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientSectionTitle extends StatelessWidget {
  final String text;
  const PatientSectionTitle(this.text, {super.key});

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
