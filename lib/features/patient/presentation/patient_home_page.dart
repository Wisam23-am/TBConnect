import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/auth_service.dart';
import '../../../services/notification_realtime_service.dart';
import '../../../services/patient_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/presentation/portal_role_screen.dart';
import 'patient_control_schedule_page.dart';
import 'patient_weight_input_page.dart';
import 'widgets/patient_home_header.dart';
import 'widgets/patient_schedule_header.dart';
import 'widgets/patient_progress_card.dart';
import 'widgets/patient_control_reminder_card.dart';
import 'widgets/patient_weight_card.dart';
import 'widgets/patient_medication_card.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  final _authService = AuthService();
  final _patientService = PatientDataService();

  final _realtimeService = NotificationRealtimeService.instance;

  bool _isLoading = true;
  String? _error;
  PatientSession? _session;
  Map<String, dynamic>? _dbProfile;

  List<MedicationSlot> _medicationSchedule = [];

  // Data jadwal kontrol
  List<Map<String, dynamic>> _controlVisits = [];
  Map<String, dynamic>? _nextControlVisit;

  // Track the currently viewed date offset from today.
  // 0 = today, -1 = yesterday, -2 = day before yesterday.
  int _viewedDateOffset = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _realtimeService.stop();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final session = await _authService.getPatientSession();
      if (session == null) {
        if (mounted) _redirectToLogin();
        return;
      }
      _session = session;

      // Initialize real-time notifications
      await _realtimeService.start(session.patientId);

      // Load profile
      _dbProfile = await _patientService.getPatientProfile(session.patientId);

      // Load schedules for the selected date
      await _fetchMedicationSchedule(session.patientId, _viewedDateOffset);

      // Load control schedule visits
      final visits =
          await _patientService.getClinicVisits(patientId: session.patientId);

      Map<String, dynamic>? nextVisit;
      if (visits.isNotEmpty) {
        // Find the next visit (first one whose scheduled_date is not in the past relative to today,
        // or the next 'active' one. Assuming sorted by visit_number)
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        try {
          nextVisit = visits.firstWhere((v) {
            final status = v['status'] as String? ?? 'active';
            if (status == 'done') return false;
            final dateStr = v['scheduled_date'] as String?;
            if (dateStr == null) return false;
            final date = DateTime.tryParse(dateStr);
            if (date == null) return false;
            // Return true if date is >= today
            return date.isAfter(today) || date.isAtSameMomentAs(today);
          });
        } catch (e) {
          nextVisit = null; // No upcoming visit found
        }
      }

      if (mounted) {
        setState(() {
          _controlVisits = visits;
          _nextControlVisit = nextVisit;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Gagal memuat data: $e';
        });
      }
    }
  }

  Future<void> _fetchMedicationSchedule(
      String patientId, int daysOffset) async {
    final now = DateTime.now();
    final targetDate = now.add(Duration(days: daysOffset));
    final targetDay =
        DateTime(targetDate.year, targetDate.month, targetDate.day);

    final medResult = await _patientService.getTodayMedications(
      patientId: patientId,
      date: targetDate,
    );

    final logs = List<Map<String, dynamic>>.from(medResult['sessions'] ?? []);

    // Map DB logs to UI slots and normalize status thresholds for today's and past reminder history.
    final today = DateTime(now.year, now.month, now.day);

    List<MedicationSlot> slots = [];
    for (var s in logs) {
      final session = s['session'] as String? ?? '';

      MedicationStatus status = MedicationStatus.locked;
      final statusStr = s['status'] as String? ?? 'locked';
      if (statusStr == 'taken')
        status = MedicationStatus.completed;
      else if (statusStr == 'active')
        status = MedicationStatus.active;
      else if (statusStr == 'late')
        status = MedicationStatus.late;
      else if (statusStr == 'missed')
        status = MedicationStatus.missed;
      else
        status = MedicationStatus.locked;

      final lateReason = s['late_reason'] as String?;
      if (status != MedicationStatus.completed) {
        status = _resolveMedicationStatusForDate(
          session: session,
          rawStatus: status,
          lateReason: lateReason,
          now: now,
          targetDate: targetDay,
          today: today,
        );
      }

      slots.add(MedicationSlot(
        session: session,
        label: s['label'] as String? ?? '',
        timeRange: s['window'] as String? ?? '',
        medications: [
          'Isoniazid, Rifampicin, Pyrazinamide',
          'Ethambutol (Total 4 Tablet)'
        ],
        status: status,
        takenAt:
            s['taken_at'] != null ? DateTime.tryParse(s['taken_at']) : null,
        lateReason: lateReason,
      ));
    }

    // If user had previously recorded a late reason locally (prefs) but server
    // hasn't persisted it yet, show a placeholder so the UI hides the button.
    try {
      final prefs = await SharedPreferences.getInstance();
      for (var i = 0; i < slots.length; i++) {
        final s = slots[i];
        final key =
            'late_reason_recorded:${patientId}:${targetDate.toIso8601String().split('T').first}:${s.session}';
        if ((s.lateReason == null || s.lateReason!.isEmpty) &&
            prefs.getBool(key) == true) {
          slots[i] = MedicationSlot(
            session: s.session,
            label: s.label,
            timeRange: s.timeRange,
            medications: s.medications,
            status: MedicationStatus.late,
            takenAt: s.takenAt,
            lateReason: 'Alasan telah dikirim',
          );
        }
      }
    } catch (e) {
      // ignore prefs errors
    }

    setState(() {
      _medicationSchedule = slots;
    });
  }

  // --- Helper methods for time logic ---

  String _getSessionLabel(String session) {
    switch (session) {
      case 'morning':
        return 'Pagi';
      case 'afternoon':
        return 'Siang';
      case 'evening':
        return 'Malam';
      default:
        return 'Sesi Lainnya';
    }
  }

  String _getTimeRange(String session) {
    switch (session) {
      case 'morning':
        return '06:00 - 09:00';
      case 'afternoon':
        return '13:00 - 15:00';
      case 'evening':
        return '18:00 - 21:00';
      default:
        return 'Waktu bebas';
    }
  }

  int _getSessionOrder(String session) {
    switch (session) {
      case 'morning':
        return 1;
      case 'afternoon':
        return 2;
      case 'evening':
        return 3;
      default:
        return 4;
    }
  }

  MedicationStatus _calculateStatusForToday(String session) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _resolveMedicationStatusForDate(
      session: session,
      rawStatus: MedicationStatus.locked,
      lateReason: null,
      now: now,
      targetDate: today,
      today: today,
    );
  }

  MedicationStatus _resolveMedicationStatusForDate({
    required String session,
    required MedicationStatus rawStatus,
    required String? lateReason,
    required DateTime now,
    required DateTime targetDate,
    required DateTime today,
  }) {
    // Keep completed state exact.
    if (rawStatus == MedicationStatus.completed)
      return MedicationStatus.completed;

    // If server already knows the slot is truly late with a recorded reason,
    // preserve the yellow late state.
    if (rawStatus == MedicationStatus.late &&
        lateReason != null &&
        lateReason.isNotEmpty) return MedicationStatus.late;

    if (targetDate.isAfter(today)) {
      return MedicationStatus.locked;
    }

    if (targetDate.isBefore(today)) {
      return MedicationStatus.lateLocked;
    }

    final start = _sessionStart(targetDate, session);
    final end = _sessionEnd(targetDate, session);
    final nextStart = _nextSessionStart(targetDate, session);

    if (now.isBefore(start)) {
      return MedicationStatus.locked;
    }

    if (!now.isAfter(end)) {
      return MedicationStatus.active;
    }

    if (now.isBefore(nextStart)) {
      return MedicationStatus.late;
    }

    return MedicationStatus.lateLocked;
  }

  DateTime _sessionStart(DateTime date, String session) {
    switch (session) {
      case 'morning':
        return DateTime(date.year, date.month, date.day, 6, 0);
      case 'afternoon':
        return DateTime(date.year, date.month, date.day, 13, 0);
      case 'evening':
        return DateTime(date.year, date.month, date.day, 18, 0);
      default:
        return DateTime(date.year, date.month, date.day);
    }
  }

  DateTime _sessionEnd(DateTime date, String session) {
    switch (session) {
      case 'morning':
        return DateTime(date.year, date.month, date.day, 9, 0);
      case 'afternoon':
        return DateTime(date.year, date.month, date.day, 15, 0);
      case 'evening':
        return DateTime(date.year, date.month, date.day, 21, 0);
      default:
        return DateTime(date.year, date.month, date.day, 23, 59, 59);
    }
  }

  DateTime _nextSessionStart(DateTime date, String session) {
    switch (session) {
      case 'morning':
        return DateTime(date.year, date.month, date.day, 13, 0);
      case 'afternoon':
        return DateTime(date.year, date.month, date.day, 18, 0);
      case 'evening':
        return DateTime(date.year, date.month, date.day + 1, 6, 0);
      default:
        return DateTime(date.year, date.month, date.day, 23, 59, 59);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _calculateTreatmentPhase(DateTime startDate) {
    final now = DateTime.now();
    final difference = now.difference(startDate).inDays;
    final months = (difference / 30).floor() + 1;
    return months > 6 ? '6' : months.toString();
  }

  DateTime _viewedTargetDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .add(Duration(days: _viewedDateOffset));
  }

  // --- Handlers ---

  void _redirectToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PortalRoleScreen()),
      (route) => false,
    );
  }

  void _handlePreviousDay() {
    if (_viewedDateOffset > -2) {
      setState(() => _viewedDateOffset--);
      if (_session != null) {
        _fetchMedicationSchedule(_session!.patientId, _viewedDateOffset);
      }
    }
  }

  void _handleNextDay() {
    if (_viewedDateOffset < 0) {
      setState(() => _viewedDateOffset++);
      if (_session != null) {
        _fetchMedicationSchedule(_session!.patientId, _viewedDateOffset);
      }
    }
  }

  Future<void> _handleConfirmMedication(MedicationSlot slot) async {
    if (_session == null) return;
    try {
      final logDate = _viewedTargetDate();

      await _patientService.logMedication(
        patientId: _session!.patientId,
        date: logDate,
        session: slot.session,
      );

      _showSnackBar('✅ Obat sesi ${slot.label} berhasil dicatat.',
          const Color(0xFF2E7D32));
      _fetchMedicationSchedule(_session!.patientId, _viewedDateOffset);
    } catch (e) {
      _showSnackBar('Gagal mencatat obat: $e', Colors.redAccent);
    }
  }

  Future<void> _handleLateMedication(MedicationSlot slot) async {
    if (_session == null) return;

    final logDate = _viewedTargetDate();

    // 1) Check server-side status (best effort). If RPC fails, we proceed to check local cache.
    bool serverHasReason = false;
    try {
      final serverData = await _patientService.getTodayMedications(
        patientId: _session!.patientId,
        date: logDate,
      );
      final sessions =
          List<Map<String, dynamic>>.from(serverData['sessions'] ?? []);
      final matched = sessions.firstWhere(
        (s) => (s['session'] as String? ?? '') == slot.session,
        orElse: () => {},
      );
      if (matched.isNotEmpty) {
        final late = matched['late_reason'] as String?;
        if (late != null && late.isNotEmpty) serverHasReason = true;
      }
    } catch (e) {
      // ignore - RPC may be missing or network error; we'll fall back to local check
      print('Warning: server check for late reason failed: $e');
    }

    if (serverHasReason) {
      _showSnackBar('Alasan terlambat sudah tercatat di server.',
          const Color(0xFF616161));
      // Refresh to show server state
      _fetchMedicationSchedule(_session!.patientId, _viewedDateOffset);
      return;
    }

    // 2) Check local persistent cache to avoid double-entry across restarts
    final prefs = await SharedPreferences.getInstance();
    final key =
        'late_reason_recorded:${_session!.patientId}:${logDate.toIso8601String().split('T').first}:${slot.session}';
    if (prefs.getBool(key) == true) {
      _showSnackBar('Alasan terlambat sudah dicatat sebelumnya (lokal).',
          const Color(0xFF616161));
      return;
    }

    // 3) Prompt user for reason
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alasan Terlambat'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Masukkan alasan...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      try {
        await _patientService.logMedication(
          patientId: _session!.patientId,
          date: logDate,
          session: slot.session,
          reason: reason,
        );

        // mark local cache so user can't re-enter even if server migration not applied yet
        await prefs.setBool(key, true);

        _showSnackBar(
            '✅ Obat dicatat dengan alasan terlambat.', const Color(0xFF2E7D32));
        _fetchMedicationSchedule(_session!.patientId, _viewedDateOffset);
      } catch (e) {
        _showSnackBar('Gagal mencatat obat: $e', Colors.redAccent);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF112D4E))),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAllData,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final String name = _dbProfile?['full_name'] ?? 'Pasien';
    final targetDate = DateTime.now().add(Duration(days: _viewedDateOffset));
    final dateString = _viewedDateOffset == 0
        ? '${_formatDate(targetDate)} (Hari Ini)'
        : _formatDate(targetDate);

    // Hitung progress bulan
    final startDateStr = _dbProfile?['treatment_start_date'];
    int currentMonth = 1;
    if (startDateStr != null) {
      final startDate = DateTime.tryParse(startDateStr);
      if (startDate != null) {
        currentMonth = int.tryParse(_calculateTreatmentPhase(startDate)) ?? 1;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          PatientHomeHeader(
            name: name,
            realtimeService: _realtimeService,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAllData,
              color: const Color(0xFF112D4E),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                    bottom: 100), // padding for bottom nav
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Progress Card ---
                      PatientProgressCard(treatmentMonth: currentMonth),
                      const SizedBox(height: 16),

                      // --- Control Reminder Card (jika ada) ---
                      if (_nextControlVisit != null) ...[
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const PatientControlSchedulePage()),
                            ).then((_) => _loadAllData()); // refresh on return
                          },
                          child: PatientControlReminderCard(
                            scheduledDate: DateTime.parse(
                                _nextControlVisit!['scheduled_date']),
                            formattedDate: _formatDate(DateTime.parse(
                                _nextControlVisit!['scheduled_date'])),
                            location: _nextControlVisit!['location'] ??
                                'Fasilitas Kesehatan',
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // --- Weight Input Card ---
                      PatientWeightCard(
                        onInputTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PatientWeightInputPage()),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // --- Jadwal Minum Obat Header ---
                      PatientScheduleHeader(
                        isToday: _viewedDateOffset == 0,
                        isMaxPast: _viewedDateOffset <= -2,
                        formattedDate: dateString,
                        onPrevious: _handlePreviousDay,
                        onNext: _handleNextDay,
                      ),

                      const SizedBox(height: 16),

                      // --- Medication List ---
                      if (_medicationSchedule.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'Tidak ada jadwal obat untuk hari ini.',
                              style: GoogleFonts.manrope(
                                  color: const Color(0xFF64748B)),
                            ),
                          ),
                        )
                      else
                        ..._medicationSchedule.map((slot) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: MedicationCard(
                                slot: slot,
                                onConfirm: () => _handleConfirmMedication(slot),
                                onLateReason: () => _handleLateMedication(slot),
                              ),
                            )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
