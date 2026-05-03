import 'package:flutter/material.dart';

import 'doctor_login_screen.dart';
import 'patient_login_screen.dart';

class PortalRoleScreen extends StatelessWidget {
  const PortalRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return Stack(
              children: [
                isWide
                    ? Row(
                        children: const [
                          Expanded(
                            child: _PortalPane(
                              isPatient: true,
                              backgroundColor: Color(0xFFF8F9FA),
                              gradientColorA: Color(0xFFF8F9FA),
                              gradientColorB: Color(0xFFEDF1F5),
                            ),
                          ),
                          Expanded(
                            child: _PortalPane(
                              isPatient: false,
                              backgroundColor: Color(0xFF112D4E),
                              gradientColorA: Color(0xFF112D4E),
                              gradientColorB: Color(0xFF1A3B64),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: const [
                          Expanded(
                            child: _PortalPane(
                              isPatient: true,
                              backgroundColor: Color(0xFFF8F9FA),
                              gradientColorA: Color(0xFFF8F9FA),
                              gradientColorB: Color(0xFFEDF1F5),
                            ),
                          ),
                          Expanded(
                            child: _PortalPane(
                              isPatient: false,
                              backgroundColor: Color(0xFF112D4E),
                              gradientColorA: Color(0xFF112D4E),
                              gradientColorB: Color(0xFF1A3B64),
                            ),
                          ),
                        ],
                      ),
                Align(
                  alignment: isWide ? Alignment.center : Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: isWide ? 0 : 16),
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFE1E3E4)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.medical_services_rounded,
                              color: Color(0xFF2A609C),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'TBConnect',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: Color(0xFF001833),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PortalPane extends StatelessWidget {
  const _PortalPane({
    required this.isPatient,
    required this.backgroundColor,
    required this.gradientColorA,
    required this.gradientColorB,
  });

  final bool isPatient;
  final Color backgroundColor;
  final Color gradientColorA;
  final Color gradientColorB;

  @override
  Widget build(BuildContext context) {
    final title = isPatient ? 'Portal Pasien' : 'Portal Dokter';
    final subtitle = isPatient
        ? 'Pantau obat harian, catat gejala, dan lihat perkembangan pengobatan Anda dengan mudah dan jelas.'
        : 'Triase pasien, kelola rekam medis, dan pantau kepatuhan pengobatan pasien TB secara real-time.';
    final cta = isPatient ? 'Masuk sebagai Pasien' : 'Masuk sebagai Dokter';

    final fgTitle = isPatient ? const Color(0xFF001833) : Colors.white;
    final fgBody =
        isPatient ? const Color(0xFF43474E) : const Color(0xFFAFCAE8);
    final iconCircle = isPatient ? const Color(0xFFD4E3FF) : Colors.white;
    final iconColor =
        isPatient ? const Color(0xFF2F486A) : const Color(0xFF2A609C);
    final buttonBg = isPatient ? const Color(0xFF001833) : Colors.white;
    final buttonFg = isPatient ? Colors.white : const Color(0xFF001833);

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => isPatient
                  ? const PatientLoginScreen()
                  : const DoctorLoginScreen(),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: isPatient ? Alignment.topLeft : Alignment.topRight,
              end: isPatient ? Alignment.bottomRight : Alignment.bottomLeft,
              colors: [gradientColorA, gradientColorB],
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: iconCircle,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPatient
                            ? Icons.person_rounded
                            : Icons.health_and_safety_rounded,
                        size: 48,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 40,
                        height: 1.2,
                        letterSpacing: -0.8,
                        fontWeight: FontWeight.w700,
                        color: fgTitle,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.55,
                        color: fgBody,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: buttonBg,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cta,
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                              color: buttonFg,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: buttonFg,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
