import 'package:flutter/material.dart';

import '../../../../widgets/patient_bottom_nav_bar.dart';
import 'patient_home_page.dart';
import 'patient_symptoms_page.dart';
import 'patient_weight_progress_page.dart';
import 'patient_profile_page.dart';

/// Shared shell widget that wraps all patient pages with a single
/// bottom navigation bar and smooth IndexedStack transitions.
class PatientShell extends StatefulWidget {
  final int initialIndex;

  const PatientShell({super.key, this.initialIndex = 0});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  late int _currentIndex;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _pages = const [
      PatientHomePage(),
      PatientSymptomsPage(),
      PatientWeightProgressPage(),
      PatientProfilePage(),
    ];
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: PatientBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
