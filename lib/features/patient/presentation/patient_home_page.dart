import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../../../services/notification_realtime_service.dart';
import '../../../services/patient_service.dart';
import '../../auth/presentation/portal_role_screen.dart';
import 'patient_weight_input_page.dart';
import 'patient_notification_page.dart';

// ---------------------------------------------------------------------------
// Medication slot status  (mirrors RPC return values)
// ---------------------------------------------------------------------------
enum MedicationStatus {
  completed, // 'taken'
  active, // 'active'
  late, // 'late'
  missed, // 'missed'
  locked, // 'locked'
}

// ---------------------------------------------------------------------------
// Data model for one medication slot
// ---------------------------------------------------------------------------
class _MedicationSlot {
  final String session; // 'morning' | 'afternoon' | 'evening'
  final String label;
  final String timeRange;
  final List<String> medications;
  final MedicationStatus status;
  final DateTime? takenAt;
  final String? lateReason;

  const _MedicationSlot({
    required this.session,
    required this.label,
    required this.timeRange,
    required this.medications,
    required this.status,
    this.takenAt,
    this.lateReason,
  });
}

// ---------------------------------------------------------------------------
// Main screen  –  fully integrated with Supabase
// ---------------------------------------------------------------------------
class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key, this.allowGuestMode = false});

  final bool allowGuestMode;

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  final _authService = AuthService();
  final _patientService = PatientDataService();
  final _supabase = Supabase.instance.client; // untuk RPC calls
  final _realtimeService = NotificationRealtimeService.instance;

  // ── Session & data ──
  PatientSession? _session;
  List<_MedicationSlot> _slots = [];
  DateTime? _treatmentStartDate;
  Map<String, dynamic>? _nextVisit;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  final Map<String, DateTime> _guestConfirmedAt = {};
  final Set<String> _justConfirmedSessions =
      {}; // tracked locally for instant visual feedback
  DateTime _selectedDate = DateTime.now();

  // Medication names per session – bisa diperkaya dari DB nanti
  // ── Indonesian day/month names (avoid locale init issues) ──
  static const _dayNames = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  static const _monthNames = [
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

  static const Map<String, List<String>> _defaultMeds = {
    'morning': [
      'Isoniazid, Rifampicin, Pyrazinamide',
      'Ethambutol (Total 4 Tablet)'
    ],
    'afternoon': [
      'Isoniazid, Rifampicin, Pyrazinamide',
      'Ethambutol (Total 4 Tablet)'
    ],
    'evening': [
      'Isoniazid, Rifampicin, Pyrazinamide',
      'Ethambutol (Total 4 Tablet)'
    ],
  };

  // ────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!_isLoading) setState(() => _isRefreshing = true);

    try {
      // 1. Ambil session pasien dari SharedPreferences
      final session = await _authService.getPatientSession();
      if (session == null) {
        if (!widget.allowGuestMode) {
          _realtimeService.stop();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const PortalRoleScreen()),
              (route) => false,
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _session = PatientSession(
              patientId: 'guest',
              fullName: 'Pasien',
              doctorId: '-',
              qrCode: '-',
              treatmentStartDate: DateTime.now(),
              initialWeightKg: 0,
            );
            _slots = _buildGuestMedicationSlots(_guestConfirmedAt);
            _treatmentStartDate = DateTime.now();
            _nextVisit = {
              'scheduled_date': DateTime.now()
                  .add(const Duration(days: 5))
                  .toIso8601String()
                  .split('T')
                  .first,
              'location': 'RSUD Dr. Soetomo',
            };
            _isLoading = false;
            _isRefreshing = false;
            _error = null;
          });
        }
        return;
      }

      // 2. Status obat hari ini dari RPC (SECURITY DEFINER → bypass RLS)
      final medResult = await _patientService.getTodayMedications(
          patientId: session.patientId, date: _selectedDate);
      final sessions =
          List<Map<String, dynamic>>.from(medResult['sessions'] ?? []);

      // 3. Kunjungan berikutnya
      // Gunakan RPC: get_upcoming_visits (kalau sudah ada) atau null dulu
      // karena query langsung ke clinic_visits diblokir RLS untuk pasien
      Map<String, dynamic>? nextVisit;
      try {
        final visits = await _supabase.rpc('get_upcoming_visits', params: {
          'p_patient_id': session.patientId,
        });
        final visitsList = List<Map<String, dynamic>>.from(visits as List);
        if (visitsList.isNotEmpty) nextVisit = visitsList.first;
      } catch (_) {
        // RPC mungkin belum ada di database — skip, tidak kritis
        nextVisit = null;
      }

      if (mounted) {
        setState(() {
          _session = session;
          _slots = sessions.map(_parseSlot).toList();
          // treatment_start_date dan initial_weight_kg sudah dari session
          _treatmentStartDate = session.treatmentStartDate;
          _nextVisit = nextVisit;
          _isLoading = false;
          _isRefreshing = false;
          _error = null;
        });
      }

      await _realtimeService.start(session.patientId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _error = 'Gagal memuat data: $e';
        });
      }
    }
  }

  List<_MedicationSlot> _buildGuestMedicationSlots(
      [Map<String, DateTime> confirmedAt = const {}]) {
    return [
      _buildGuestSlot(
        session: 'morning',
        label: 'Pagi',
        startHour: 6,
        endHour: 9,
        confirmedAt: confirmedAt['morning'],
      ),
      _buildGuestSlot(
        session: 'afternoon',
        label: 'Siang',
        startHour: 13,
        endHour: 15,
        confirmedAt: confirmedAt['afternoon'],
      ),
      _buildGuestSlot(
        session: 'evening',
        label: 'Malam',
        startHour: 18,
        endHour: 21,
        confirmedAt: confirmedAt['evening'],
      ),
    ];
  }

  _MedicationSlot _buildGuestSlot({
    required String session,
    required String label,
    required int startHour,
    required int endHour,
    DateTime? confirmedAt,
  }) {
    final now = DateTime.now();
    final status = _resolveGuestStatus(
      now: now,
      startHour: startHour,
      endHour: endHour,
      confirmedAt: confirmedAt,
    );

    return _MedicationSlot(
      session: session,
      label: label,
      timeRange:
          '${startHour.toString().padLeft(2, '0')}:00 - ${endHour.toString().padLeft(2, '0')}:00',
      medications: const [
        'Isoniazid, Rifampicin, Pyrazinamide',
        'Ethambutol (Total 4 Tablet)',
      ],
      status: status,
      takenAt: confirmedAt,
    );
  }

  MedicationStatus _resolveGuestStatus({
    required DateTime now,
    required int startHour,
    required int endHour,
    DateTime? confirmedAt,
  }) {
    // Jika sudah dikonfirmasi (baik tepat waktu maupun telat),
    // tampilkan sebagai completed. Alasan keterlambatan sudah
    // dicatat terpisah melalui dialog.
    if (confirmedAt != null) {
      return MedicationStatus.completed;
    }

    if (now.hour < startHour) {
      return MedicationStatus.locked;
    }
    if (now.hour >= startHour && now.hour < endHour) {
      return MedicationStatus.active;
    }
    return MedicationStatus.missed;
  }

  // ────────────────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────────────────

  static MedicationStatus _fromRpcStatus(String status) {
    switch (status) {
      case 'taken':
        return MedicationStatus.completed;
      case 'active':
        return MedicationStatus.active;
      case 'late':
        return MedicationStatus.late;
      case 'missed':
        return MedicationStatus.missed;
      default:
        return MedicationStatus.locked;
    }
  }

  _MedicationSlot _parseSlot(Map<String, dynamic> s) {
    final session = s['session'] as String? ?? '';
    return _MedicationSlot(
      session: session,
      label: s['label'] as String? ?? '',
      timeRange: s['window'] as String? ?? '',
      medications: _defaultMeds[session] ?? [],
      status: _fromRpcStatus(s['status'] as String? ?? 'locked'),
      takenAt: s['taken_at'] != null ? DateTime.tryParse(s['taken_at']) : null,
      lateReason: s['late_reason'] as String?,
    );
  }

  int get _treatmentMonth {
    if (_treatmentStartDate == null) return 1;
    final diff = DateTime.now().difference(_treatmentStartDate!);
    return (diff.inDays / 30).floor().clamp(1, 6);
  }

  String get _formattedDate {
    return '${_dayNames[_selectedDate.weekday - 1]}, ${_selectedDate.day} ${_monthNames[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_monthNames[dt.month - 1]} ${dt.year}';
  }

  // ────────────────────────────────────────────────────────────────────────
  // Actions  (DB write)
  // ────────────────────────────────────────────────────────────────────────

  Future<void> _confirmMedication(_MedicationSlot slot,
      {String? reason}) async {
    if (_session == null) return;

    if (_session!.patientId == 'guest') {
      setState(() {
        _guestConfirmedAt[slot.session] = DateTime.now();
        _slots = _buildGuestMedicationSlots(_guestConfirmedAt);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Obat ${slot.label.toLowerCase()} berhasil dicatat',
              style: GoogleFonts.manrope(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    try {
      await _patientService.logMedication(
        patientId: _session!.patientId,
        session: slot.session,
        reason: reason,
        date: _selectedDate,
      );

      // Track locally so the card instantly shows as completed
      // even if the server RPC still returns 'late' status.
      setState(() {
        _justConfirmedSessions.add(slot.session);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Obat ${slot.label.toLowerCase()} berhasil dicatat',
              style: GoogleFonts.manrope(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _loadData(); // refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _navigateToWeightInput() async {
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => const PatientWeightInputPage(),
        ),
      );

      // Refresh data setelah kembali dari halaman berat badan
      _loadData();
    }
  }

  Future<void> _showLateReasonDialog(_MedicationSlot slot) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Alasan Terlambat',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ceritakan alasan Anda terlambat minum obat...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF001833),
              foregroundColor: Colors.white,
            ),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      // Log medication taken with the late reason attached
      await _confirmMedication(slot, reason: reason);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Error view
  // ────────────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 64, color: Color(0xFFC4C6CF)),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF112D4E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: const Color(0xFF5A8DA0),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                _realtimeService.stop();
                await _authService.logoutPatient();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const PortalRoleScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text('Kembali ke Halaman Awal'),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // BUILD  –  home content only (no profile, no bottom nav)
  // ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF112D4E)),
      );
    }

    if (_error != null) {
      return _buildError();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF112D4E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isRefreshing)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Color(0xFFE5F0FF),
                  color: Color(0xFF112D4E),
                ),
              ),
            _buildHeader(),
            const SizedBox(height: 24),
            _buildScheduleHeader(),
            const SizedBox(height: 16),
            _buildProgressCard(),
            const SizedBox(height: 16),
            if (_nextVisit != null) ...[
              _buildControlReminder(),
              const SizedBox(height: 24),
            ],
            ..._slots.map((slot) {
              // Override status if user just confirmed this session
              // (instant visual feedback before server refresh)
              final effectiveStatus =
                  _justConfirmedSessions.contains(slot.session)
                      ? MedicationStatus.completed
                      : slot.status;
              final effectiveSlot = _MedicationSlot(
                session: slot.session,
                label: slot.label,
                timeRange: slot.timeRange,
                medications: slot.medications,
                status: effectiveStatus,
                takenAt: slot.takenAt,
                lateReason: slot.lateReason,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _MedicationCard(
                  slot: effectiveSlot,
                  onConfirm: () => _confirmMedication(slot),
                  onLateReason: () => _showLateReasonDialog(slot),
                ),
              );
            }),
            const SizedBox(height: 8),
            _buildWeightCard(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Header
  // ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final name = _session?.fullName ?? 'Pasien';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFE1E3E4),
          child: Text(initial,
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700, color: const Color(0xFF112D4E))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Halo, $name',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: const Color(0xFF112D4E),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.45,
            ),
          ),
        ),
        const Spacer(),
        StreamBuilder<NotificationSnapshot>(
          stream: _realtimeService.stream,
          builder: (context, snapshot) {
            final unreadCount = snapshot.data?.unreadCount ?? 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: const Color(0xFF2A609C),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PatientNotificationPage(),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.notifications,
                          size: 24, color: Colors.white),
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Schedule header
  // ──────────────────────────────────────────────────────────────
  Widget _buildScheduleHeader() {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    // Batas mundur maksimal 3 hari
    final today = DateTime(now.year, now.month, now.day);
    final selected =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final daysDifference = today.difference(selected).inDays;
    final isMaxPast = daysDifference >= 3;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isToday ? 'Jadwal Hari Ini' : 'Jadwal Sebelumnya',
              style: GoogleFonts.manrope(
                color: const Color(0xFF001833),
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formattedDate,
              style: GoogleFonts.manrope(
                color: const Color(0xFF43474E),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left,
                  color: isMaxPast ? Colors.grey : const Color(0xFF112D4E)),
              onPressed: isMaxPast
                  ? null
                  : () {
                      setState(() {
                        _selectedDate =
                            _selectedDate.subtract(const Duration(days: 1));
                        _loadData();
                      });
                    },
            ),
            IconButton(
              icon: Icon(Icons.chevron_right,
                  color: isToday ? Colors.grey : const Color(0xFF112D4E)),
              onPressed: isToday
                  ? null
                  : () {
                      setState(() {
                        _selectedDate =
                            _selectedDate.add(const Duration(days: 1));
                        _loadData();
                      });
                    },
            ),
          ],
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Progress card  –  "Bulan X dari 6"
  // ──────────────────────────────────────────────────────────────
  Widget _buildProgressCard() {
    final month = _treatmentMonth;
    final progress = month / 6;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PROGRESS PENGOBATAN',
                style: GoogleFonts.manrope(
                  color: const Color(0xFF43474E),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.60,
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Bulan $month ',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF001833),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: 'dari 6',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF43474E),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: const Color(0xFFEDEEEF),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF2A609C)),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Control reminder  –  dari tabel clinic_visits
  // ──────────────────────────────────────────────────────────────
  Widget _buildControlReminder() {
    if (_nextVisit == null) return const SizedBox.shrink();

    final scheduleDate = DateTime.parse(_nextVisit!['scheduled_date']);
    final daysLeft = scheduleDate.difference(DateTime.now()).inDays;
    final formattedDate = _formatDate(scheduleDate);
    final location = _nextVisit!['location'] ?? 'Klinik / Puskesmas';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDBE2EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x19112D4E)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notification_important_rounded,
              color: Color(0xFF112D4E), size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  daysLeft > 0
                      ? 'Pengingat Kontrol: $daysLeft Hari Lagi'
                      : daysLeft == 0
                          ? '🔔 Jadwal Kontrol Hari Ini!'
                          : '⚠️ Jadwal kontrol terlewat',
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF112D4E),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$location\n$formattedDate',
                  style: GoogleFonts.manrope(
                    color: const Color(0xCC112D4E),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.43,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Weight update card
  // ──────────────────────────────────────────────────────────────
  Widget _buildWeightCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFD3E3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8BBBFD)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF004882),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.monitor_weight_outlined,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update Berat\nBadan',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF001C39),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.56,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pantau perkembangan\nfisik Anda',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF004882),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.60,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: _navigateToWeightInput,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                'Input',
                style: GoogleFonts.manrope(
                  color: const Color(0xFF2A609C),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Medication card – renders differently based on MedicationStatus
// Clean OOP: uses a shared card shell with Strategy-like button injection
// ===========================================================================

/// Shared visual properties for each card variant.
class _CardVariant {
  final Color accentColor;
  final Color borderColor;
  final List<BoxShadow> shadows;
  final Color? bgColor;

  const _CardVariant({
    required this.accentColor,
    required this.borderColor,
    required this.shadows,
    this.bgColor,
  });
}

/// Shared card shell – every variant uses this same layout.
class _MedicationCard extends StatelessWidget {
  final _MedicationSlot slot;
  final VoidCallback? onConfirm;
  final VoidCallback? onLateReason;

  const _MedicationCard({
    required this.slot,
    this.onConfirm,
    this.onLateReason,
  });

  static const _cardVariants = {
    MedicationStatus.completed: _CardVariant(
      accentColor: Color(0xFF2A609C),
      borderColor: Color(0x4CC4C6CF),
      shadows: [
        BoxShadow(
          color: Color(0x0C000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    ),
    MedicationStatus.active: _CardVariant(
      accentColor: Color(0xFF001833),
      borderColor: Color(0xFF001833),
      shadows: [
        BoxShadow(
          color: Color(0x14001833),
          blurRadius: 30,
          offset: Offset(0, 8),
        ),
      ],
    ),
    MedicationStatus.late: _CardVariant(
      accentColor: Color(0xFFE4A700),
      borderColor: Color(0xFFE19200),
      shadows: [
        BoxShadow(
          color: Color(0x14001833),
          blurRadius: 30,
          offset: Offset(0, 8),
        ),
      ],
    ),
    MedicationStatus.missed: _CardVariant(
      accentColor: Color(0xFFC50000),
      borderColor: Color(0xFFA60000),
      shadows: [
        BoxShadow(
          color: Color(0x14001833),
          blurRadius: 30,
          offset: Offset(0, 8),
        ),
      ],
    ),
    MedicationStatus.locked: _CardVariant(
      accentColor: Color(0xFF43474E),
      borderColor: Color(0xFFE1E3E4),
      shadows: [],
      bgColor: Color(0xFFF8F9FA),
    ),
  };

  @override
  Widget build(BuildContext context) {
    // If medication was already taken, always show as completed
    if (slot.takenAt != null) {
      return _buildCompleted();
    }

    switch (slot.status) {
      case MedicationStatus.completed:
        return _buildCompleted();
      case MedicationStatus.active:
        return _buildActionable(
          variant: _cardVariants[MedicationStatus.active]!,
          button: _FilledButton(
            label: 'Konfirmasi Minum Obat',
            onPressed: onConfirm,
          ),
        );
      case MedicationStatus.late:
        return _buildActionable(
          variant: _cardVariants[MedicationStatus.late]!,
          badge: _CornerBadge(
            label: 'Terlambat',
            bgColor: const Color(0xFFBA7600),
          ),
          button: _OutlinedButton(
            label: 'Catat Alasan Terlambat',
            onPressed: onLateReason,
          ),
        );
      case MedicationStatus.missed:
        return _buildActionable(
          variant: _cardVariants[MedicationStatus.missed]!,
          badge: _CornerBadge(
            label: 'Belum Minum Obat',
            bgColor: const Color(0xFFBA0000),
          ),
          button: _FilledButton(
            label: 'Konfirmasi Minum Obat',
            onPressed: onConfirm,
          ),
        );
      case MedicationStatus.locked:
        return _buildLocked();
    }
  }

  // ── Completed (no accent, no badge, no button) ──
  Widget _buildCompleted() {
    final v = _cardVariants[MedicationStatus.completed]!;
    return _CardFrame(
      borderColor: v.borderColor,
      shadows: v.shadows,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(label: slot.label, timeRange: slot.timeRange),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2A609C), size: 20),
              const SizedBox(width: 8),
              Text(
                'Selesai diminum',
                style: GoogleFonts.manrope(
                  color: const Color(0xFF2A609C),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Actionable (accent bar + optional badge + meds + button) ──
  Widget _buildActionable({
    required _CardVariant variant,
    _CornerBadge? badge,
    required Widget button,
  }) {
    return _CardFrame(
      borderColor: variant.borderColor,
      shadows: variant.shadows,
      clip: true,
      padding: const EdgeInsets.all(24),
      stackChildren: [
        // Left accent bar
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 4,
            color: variant.accentColor,
          ),
        ),
        // Corner badge (if any)
        if (badge != null)
          Positioned(
            right: 0,
            top: 0,
            child: badge,
          ),
        // Content
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderRow(
                  label: slot.label, timeRange: slot.timeRange, dark: true),
              const SizedBox(height: 16),
              _MedicationList(medications: slot.medications),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: button),
            ],
          ),
        ),
      ],
    );
  }

  // ── Locked (muted, no interaction) ──
  Widget _buildLocked() {
    final v = _cardVariants[MedicationStatus.locked]!;
    return Opacity(
      opacity: 0.60,
      child: _CardFrame(
        borderColor: v.borderColor,
        shadows: v.shadows,
        bgColor: v.bgColor,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderRow(label: slot.label, timeRange: slot.timeRange),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.lock_rounded,
                    color: Color(0xFF43474E), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Terkunci',
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF43474E),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared card frame –  the outer container for all variants
// ═══════════════════════════════════════════════════════════════════════════
class _CardFrame extends StatelessWidget {
  final Color borderColor;
  final List<BoxShadow> shadows;
  final EdgeInsets padding;
  final bool clip;
  final Color? bgColor;
  final Widget? child;
  final List<Widget>? stackChildren;

  const _CardFrame({
    required this.borderColor,
    required this.shadows,
    required this.padding,
    this.clip = false,
    this.bgColor,
    this.child,
    this.stackChildren,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: double.infinity,
      padding: child != null ? padding : EdgeInsets.zero,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (stackChildren != null) {
      return Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: shadows,
        ),
        child: Stack(children: stackChildren!),
      );
    }

    return container;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Corner badge  –  "Terlambat" / "Belum Minum Obat"
// ═══════════════════════════════════════════════════════════════════════════
class _CornerBadge extends StatelessWidget {
  final String label;
  final Color bgColor;

  const _CornerBadge({required this.label, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.60,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Medication list  –  shared between actionable cards
// ═══════════════════════════════════════════════════════════════════════════
class _MedicationList extends StatelessWidget {
  final List<String> medications;
  const _MedicationList({required this.medications});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: medications
          .map((med) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  med,
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF43474E),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Button variants  –  filled (dark) / outlined
// ═══════════════════════════════════════════════════════════════════════════
class _FilledButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _FilledButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF001833),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.60,
        ),
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _OutlinedButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFC4C6CF)),
        foregroundColor: const Color(0xFF191C1D),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.60,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared header row  –  label + time range pill
// ═══════════════════════════════════════════════════════════════════════════
class _HeaderRow extends StatelessWidget {
  final String label;
  final String timeRange;
  final bool dark;

  const _HeaderRow({
    required this.label,
    required this.timeRange,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? const Color(0xFF001833) : const Color(0xFF43474E);
    final fontSize = dark ? 24.0 : 18.0;
    final fontWeight = dark ? FontWeight.w600 : FontWeight.w400;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time_rounded,
                size: 22, color: Color(0xFF43474E)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: textColor,
                fontSize: fontSize,
                fontWeight: fontWeight,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFFD4E3FF) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            timeRange,
            style: GoogleFonts.manrope(
              color: dark ? const Color(0xFF001833) : const Color(0xFF43474E),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.60,
            ),
          ),
        ),
      ],
    );
  }
}
