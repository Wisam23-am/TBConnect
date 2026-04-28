import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'doctor/doctor_login_page.dart';
import 'patient/patient_login_page.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 1),

              // Logo / Icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A6B8A),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A6B8A).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'TBConnect',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A3A4A),
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Sistem Monitoring Pengobatan TBC',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF5A8DA0),
                ),
              ),

              const Spacer(flex: 2),

              // Dokter button
              _RoleCard(
                icon: Icons.local_hospital_rounded,
                title: 'Masuk sebagai Dokter',
                subtitle: 'Kelola pasien & pantau kepatuhan berobat',
                color: const Color(0xFF1A6B8A),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DoctorLoginPage()),
                ),
              ),

              const SizedBox(height: 16),

              // Pasien button
              _RoleCard(
                icon: Icons.person_rounded,
                title: 'Masuk sebagai Pasien',
                subtitle: 'Catat obat harian & pantau perkembangan',
                color: const Color(0xFF2E8B57),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PatientLoginPage()),
                ),
              ),

              const Spacer(flex: 1),

              Text(
                'TBConnect v1.0 • Pengobatan Lebih Teratur',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF8AACBA),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      shadowColor: color.withOpacity(0.2),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A3A4A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B8E9F),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
