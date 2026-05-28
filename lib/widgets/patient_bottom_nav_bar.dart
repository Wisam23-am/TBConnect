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
      PatientBottomNavItem(icon: Icons.monitor_heart_outlined, label: 'Gejala'),
      PatientBottomNavItem(icon: Icons.monitor_weight_rounded, label: 'Berat'),
      PatientBottomNavItem(icon: Icons.person_rounded, label: 'Profil'),
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF112D4E),
        border: Border(top: BorderSide(color: Color(0x33FFFFFF), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33112D4E),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          currentIndex: currentIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withOpacity(0.72),
          selectedLabelStyle: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          onTap: onTap,
          items: items
              .asMap()
              .entries
              .map(
                (entry) => BottomNavigationBarItem(
                  icon: _buildNavIcon(
                    entry.value.icon,
                    isSelected: false,
                  ),
                  activeIcon: _buildNavIcon(
                    entry.value.icon,
                    isSelected: true,
                  ),
                  label: entry.value.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, {required bool isSelected}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 24,
        color:
            isSelected ? const Color.fromARGB(255, 25, 77, 136) : Colors.white,
      ),
    );
  }
}
