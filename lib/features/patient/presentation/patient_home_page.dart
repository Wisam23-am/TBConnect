import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../../auth/presentation/patient_login_screen.dart';

// ---------------------------------------------------------------------------
// Medication slot status  (mirrors RPC return values)
// ---------------------------------------------------------------------------
enum MedicationStatus {
  completed,   // 'taken'
  active,      // 'active'
  late,        // 'late'
  missed,      // 'missed'
  locked,      // 'locked'
}

// ---------------------------------------------------------------------------
// Data model for one medication slot
// ---------------------------------------------------------------------------
class _MedicationSlot {
  final String session;   // 'morning' | 'afternoon' | 'evening'
  final String label;
  final String timeRange;
  final List<String> medications;
  final MedicationStatus status;
  final DateTime? takenAt;

  const _MedicationSlot({
    required this.session,
    required this.label,
    required this.timeRange,
    required this.medications,
    required this.status,
    this.takenAt,
  });
}

// ---------------------------------------------------------------------------
// Main screen  –  fully integrated with Supabase
// ---------------------------------------------------------------------------
class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  final _authService = AuthService();
  final _patientService = PatientDataService();
  final _supabase = Supabase.instance.client; // untuk RPC calls

  int _selectedNavIndex = 0;

  // ── Session & data ──
  PatientSession? _session;
  List<_MedicationSlot> _slots = [];
  DateTime? _treatmentStartDate;
  Map<String, dynamic>? _nextVisit;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  // Medication names per session – bisa diperkaya dari DB nanti
  // ── Indonesian day/month names (avoid locale init issues) ──
  static const _dayNames = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];
  static const _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  static const Map<String, List<String>> _defaultMeds = {
    'morning':   ['Isoniazid, Rifampicin, Pyrazinamide', 'Ethambutol (Total 4 Tablet)'],
    'afternoon': ['Isoniazid, Rifampicin, Pyrazinamide', 'Ethambutol (Total 4 Tablet)'],
    'evening':   ['Isoniazid, Rifampicin, Pyrazinamide', 'Ethambutol (Total 4 Tablet)'],
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
        if (mounted) _redirectToLogin();
        return;
      }

      // 2. Status obat hari ini dari RPC (SECURITY DEFINER → bypass RLS)
      final medResult =
          await _patientService.getTodayMedications(patientId: session.patientId);
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

  void _redirectToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PatientLoginScreen()),
      (route) => false,
    );
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
    );
  }

  int get _treatmentMonth {
    if (_treatmentStartDate == null) return 1;
    final diff = DateTime.now().difference(_treatmentStartDate!);
    return (diff.inDays / 30).floor().clamp(1, 6);
  }

  String get _formattedDate {
    final now = DateTime.now();
    return '${_dayNames[now.weekday - 1]}, ${now.day} ${_monthNames[now.month - 1]}';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_monthNames[dt.month - 1]} ${dt.year}';
  }

  // ────────────────────────────────────────────────────────────────────────
  // Actions  (DB write)
  // ────────────────────────────────────────────────────────────────────────

  Future<void> _confirmMedication(_MedicationSlot slot) async {
    if (_session == null) return;

    try {
      await _patientService.logMedication(
        patientId: _session!.patientId,
        session: slot.session,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Obat ${slot.label.toLowerCase()} berhasil dicatat',
              style: GoogleFonts.manrope(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Future<void> _showWeightDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final weight = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Input Berat Badan',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Berat badan (kg)',
              hintText: 'Contoh: 55.5',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixText: 'kg',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Wajib diisi';
              if (double.tryParse(v) == null) return 'Format angka salah';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, double.parse(controller.text.trim()));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF001833),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (weight != null && _session != null) {
      try {
        await _patientService.logWeight(
          patientId: _session!.patientId,
          weightKg: weight,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Berat badan $weight kg tersimpan',
                  style: GoogleFonts.manrope(color: Colors.white)),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Gagal: $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
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
      // Log medication taken (status will be 'late' from server)
      await _confirmMedication(slot);
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
                await _authService.logoutPatient();
                if (mounted) _redirectToLogin();
              },
              child: const Text('Login Ulang'),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF112D4E)),
              )
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: const Color(0xFF112D4E),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                          top: 24, left: 24, right: 24, bottom: 100),
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
                          ..._slots.map((slot) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _MedicationCard(
                                  slot: slot,
                                  onConfirm: () => _confirmMedication(slot),
                                  onLateReason: () =>
                                      _showLateReasonDialog(slot),
                                ),
                              )),
                          const SizedBox(height: 8),
                          _buildWeightCard(),
                        ],
                      ),
                    ),
                  ),
      ),
      bottomNavigationBar: _buildBottomNav(),
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF0F4F8),
          ),
          child: const Icon(Icons.notifications_outlined,
              size: 20, color: Color(0xFF112D4E)),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Schedule header
  // ──────────────────────────────────────────────────────────────
  Widget _buildScheduleHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jadwal Hari Ini',
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
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2A609C)),
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
            onTap: _showWeightDialog,
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

  // ──────────────────────────────────────────────────────────────
  // Bottom navigation  (4 items as in the mockup)
  // ──────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
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
        currentIndex: _selectedNavIndex,
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
        onTap: (i) => setState(() => _selectedNavIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.track_changes_rounded),
            label: 'Tracker',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up_rounded),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Medication card – renders differently based on MedicationStatus
// ===========================================================================
class _MedicationCard extends StatelessWidget {
  final _MedicationSlot slot;
  final VoidCallback? onConfirm;
  final VoidCallback? onLateReason;

  const _MedicationCard({
    required this.slot,
    this.onConfirm,
    this.onLateReason,
  });

  @override
  Widget build(BuildContext context) {
    switch (slot.status) {
      case MedicationStatus.completed:
        return _CompletedCard(slot: slot);
      case MedicationStatus.active:
        return _ActiveCard(slot: slot, onConfirm: onConfirm);
      case MedicationStatus.late:
        return _LateCard(slot: slot, onLateReason: onLateReason);
      case MedicationStatus.missed:
        return _MissedCard(slot: slot, onConfirm: onConfirm);
      case MedicationStatus.locked:
        return _LockedCard(slot: slot);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 1.  COMPLETED   –  "Selesai diminum"   (design #3 – Pagi)
// ═══════════════════════════════════════════════════════════════════════════
class _CompletedCard extends StatelessWidget {
  final _MedicationSlot slot;
  const _CompletedCard({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x4CC4C6CF)),
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
}

// ═══════════════════════════════════════════════════════════════════════════
// 2.  ACTIVE      –  ready to take  (design #3 – Siang)
// ═══════════════════════════════════════════════════════════════════════════
class _ActiveCard extends StatelessWidget {
  final _MedicationSlot slot;
  final VoidCallback? onConfirm;
  const _ActiveCard({required this.slot, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF001833)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14001833),
            blurRadius: 30,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Left accent bar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: const Color(0xFF001833)),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderRow(label: slot.label, timeRange: slot.timeRange, dark: true),
                const SizedBox(height: 16),
                // medication list
                ...slot.medications.map(
                  (med) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      med,
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF43474E),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // CTA
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF001833),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      'Konfirmasi Minum Obat',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.60,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3.  LATE        –  "Terlambat"  (design #4 – Pagi variant)
// ═══════════════════════════════════════════════════════════════════════════
class _LateCard extends StatelessWidget {
  final _MedicationSlot slot;
  final VoidCallback? onLateReason;
  const _LateCard({required this.slot, this.onLateReason});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE19200)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14001833),
            blurRadius: 30,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Left accent bar – orange
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: const Color(0xFFE4A700)),
          ),
          // Badge – Terlambat
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFBA7600),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
              ),
              child: Text(
                'Terlambat',
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.60,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderRow(label: slot.label, timeRange: slot.timeRange, dark: true),
                const SizedBox(height: 16),
                ...slot.medications.map(
                  (med) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      med,
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF43474E),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Outlined CTA – "Catat Alasan Terlambat"
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onLateReason,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC4C6CF)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      'Catat Alasan Terlambat',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF191C1D),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.60,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 4.  MISSED      –  "Belum Minum Obat"  (design #4 – Siang variant)
// ═══════════════════════════════════════════════════════════════════════════
class _MissedCard extends StatelessWidget {
  final _MedicationSlot slot;
  final VoidCallback? onConfirm;
  const _MissedCard({required this.slot, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA60000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14001833),
            blurRadius: 30,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Left accent bar – red
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: const Color(0xFFC50000)),
          ),
          // Badge – "Belum Minum Obat"
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFBA0000),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
              ),
              child: Text(
                'Belum Minum Obat',
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.60,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderRow(label: slot.label, timeRange: slot.timeRange, dark: true),
                const SizedBox(height: 16),
                ...slot.medications.map(
                  (med) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      med,
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF43474E),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // CTA – same as active
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF001833),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      'Konfirmasi Minum Obat',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.60,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5.  LOCKED      –  "Terkunci"  (design #3 – Malam)
// ═══════════════════════════════════════════════════════════════════════════
class _LockedCard extends StatelessWidget {
  final _MedicationSlot slot;
  const _LockedCard({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.60,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E3E4)),
        ),
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

// ===========================================================================
// Shared header row used by all card variants
// ===========================================================================
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
