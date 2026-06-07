import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/auth_service.dart';
import '../../../services/patient_service.dart';
import 'widgets/patient_visit_timeline_item.dart';

class PatientControlSchedulePage extends StatefulWidget {
  const PatientControlSchedulePage({super.key});

  @override
  State<PatientControlSchedulePage> createState() =>
      _PatientControlSchedulePageState();
}

class _PatientControlSchedulePageState
    extends State<PatientControlSchedulePage> {
  final _authService = AuthService();
  final _patientService = PatientDataService();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _visits = [];
  PatientSession? _session;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await _authService.getPatientSession();
      if (session == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final visits = await _patientService.getClinicVisits(
          patientId: session.patientId);

      if (mounted) {
        setState(() {
          _session = session;
          _visits = visits;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Gagal memuat jadwal: $e';
        });
      }
    }
  }

  String _formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _requestReschedule(Map<String, dynamic> visit) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(visit['scheduled_date']),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF112D4E),
              onPrimary: Colors.white,
              onSurface: Color(0xFF001833),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null && _session != null && mounted) {
      try {
        await _patientService.requestReschedule(
          patientId: _session!.patientId,
          visitId: visit['id'],
          newDate: selectedDate,
          reason: 'Diminta oleh pasien',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Permintaan perubahan jadwal berhasil dikirim',
                style: GoogleFonts.manrope(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF2E7D32),
            ),
          );
          _loadSchedule(); // Refresh data
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal mengirim permintaan: $e',
                style: GoogleFonts.manrope(color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF112D4E)),
        title: Text(
          'Jadwal Kontrol',
          style: GoogleFonts.manrope(
            color: const Color(0xFF001833),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF112D4E)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: GoogleFonts.manrope()),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSchedule,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_visits.isEmpty) {
      return Center(
        child: Text(
          'Belum ada jadwal kontrol.',
          style: GoogleFonts.manrope(
            color: const Color(0xFF64748B),
            fontSize: 16,
          ),
        ),
      );
    }

    // Determine the active visit: first one that is NOT 'done'
    int activeIndex = _visits.indexWhere((v) => v['status'] != 'done');
    if (activeIndex == -1) activeIndex = _visits.length;

    return RefreshIndicator(
      onRefresh: _loadSchedule,
      color: const Color(0xFF112D4E),
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _visits.length,
        itemBuilder: (context, index) {
          final visit = _visits[index];
          final isLast = index == _visits.length - 1;

          String visualStatus;
          if (visit['status'] == 'done') {
            visualStatus = 'done';
          } else if (index == activeIndex) {
            visualStatus = 'active';
          } else {
            visualStatus = 'locked';
          }

          return PatientVisitTimelineItem(
            visit: visit,
            visualStatus: visualStatus,
            isLast: isLast,
            formatDateString: _formatDateString,
            onReschedule: _requestReschedule,
          );
        },
      ),
    );
  }
}
