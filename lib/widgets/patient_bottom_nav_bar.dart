import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientBottomNavItem {
  final IconData icon;
  final String label;

  const PatientBottomNavItem({
    required this.icon,
    required this.label,
  });
}

class PatientBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PatientBottomNavItem> items;

  const PatientBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = const [
      PatientBottomNavItem(icon: Icons.home_rounded, label: 'Beranda'),
      PatientBottomNavItem(
          icon: Icons.monitor_heart_outlined, label: 'Gejala'),
      PatientBottomNavItem(icon: Icons.monitor_weight_rounded, label: 'Berat'),
      PatientBottomNavItem(icon: Icons.calendar_month_rounded, label: 'Jadwal'),
      PatientBottomNavItem(icon: Icons.person_rounded, label: 'Profil'),
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFDBE2EF), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A112D4E),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        selectedItemColor: const Color(0xFF112D4E),
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedLabelStyle: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        onTap: onTap,
        items: items
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
