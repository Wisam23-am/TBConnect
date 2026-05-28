import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientNotesField extends StatelessWidget {
  final TextEditingController controller;
  const PatientNotesField({super.key, required this.controller});

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
