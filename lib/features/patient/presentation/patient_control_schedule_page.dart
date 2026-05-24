// ============================================================
// TBConnect - Patient Control Schedule Page
// File: lib/features/patient/presentation/patient_control_schedule_page.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/auth_service.dart';
import '../../../services/patient_service.dart';

class PatientControlSchedulePage extends StatefulWidget {
  const PatientControlSchedulePage({super.key});

  @override
  State<PatientControlSchedulePage> createState() => _PatientControlSchedulePageState();
}

class _PatientControlSchedulePageState extends State<PatientControlSchedulePage> {
  final _authService = AuthService();
  final _patientService = PatientDataService();

  PatientSession? _session;
  List<Map<String, dynamic>> _visits = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!_isLoading) {
      setState(() => _isRefreshing = true);
    }

    try {
      final session = await _authService.getPatientSession();
      if (session == null || session.patientId == 'guest') {
        // Mode Guest (Uji Coba / Simulasi)
        _session = session ??
            PatientSession(
              patientId: 'guest',
              fullName: 'Pasien Uji Coba',
              doctorId: 'guest-doctor',
              qrCode: 'GUEST-1234',
              treatmentStartDate: DateTime.now().subtract(const Duration(days: 45)),
              initialWeightKg: 60.0,
            );
        _visits = _buildGuestVisits(_session!.treatmentStartDate);
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _error = null;
        });
        return;
      }

      // Ambil data asli dari Supabase via RPC bypass RLS
      final visitsData = await _patientService.getClinicVisits(patientId: session.patientId);

      if (mounted) {
        setState(() {
          _session = session;
          _visits = visitsData;
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
          _error = 'Gagal memuat jadwal kontrol: $e';
        });
      }
    }
  }

  List<Map<String, dynamic>> _buildGuestVisits(DateTime startDate) {
    return List.generate(6, (i) {
      final visitDate = DateTime(startDate.year, startDate.month + (i + 1), startDate.day);
      String status = 'upcoming';
      if (i == 0) {
        status = 'done'; // Bulan 1 selesai
      }

      return {
        'id': 'guest-visit-$i',
        'visit_number': i + 1,
        'scheduled_date': visitDate.toIso8601String().split('T').first,
        'location': 'Puskesmas Kenjeran',
        'status': status,
        'reschedule_requested': false,
        'reschedule_reason': null,
        'reschedule_to_date': null,
      };
    });
  }

  String _formatDateString(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return _formatDate(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // Menentukan index kunjungan aktif terdekat (yang belum done)
  int _getActiveVisitNumber() {
    for (var visit in _visits) {
      final status = visit['status']?.toString().toLowerCase();
      if (status != 'done' && status != 'completed') {
        return visit['visit_number'] as int? ?? 1;
      }
    }
    return 7; // Semua sudah selesai
  }

  Future<void> _showRescheduleSheet(Map<String, dynamic> visit) async {
    final session = _session;
    if (session == null) return;

    DateTime? selectedDate;
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ajukan Pindah Jadwal',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF001833),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pilih tanggal baru dan berikan alasan logis untuk perpindahan jadwal kontrol ke dokter.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'TANGGAL BARU',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now.add(const Duration(days: 1)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 90)),
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
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: Color(0xFF112D4E), size: 20),
                          const SizedBox(width: 12),
                          Text(
                            selectedDate == null ? 'Pilih Tanggal Baru' : _formatDate(selectedDate!),
                            style: GoogleFonts.manrope(
                              color: selectedDate == null ? const Color(0xFF94A3B8) : const Color(0xFF001833),
                              fontWeight: selectedDate == null ? FontWeight.w400 : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ALASAN PERPINDAHAN',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: GoogleFonts.manrope(color: const Color(0xFF001833)),
                    decoration: InputDecoration(
                      hintText: 'Tulis alasan Anda (misal: ada keperluan dinas luar kota)...',
                      hintStyle: GoogleFonts.manrope(color: const Color(0xFF94A3B8)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF112D4E), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(context);

                              if (selectedDate == null) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Silakan pilih tanggal baru terlebih dahulu.'),
                                    backgroundColor: Colors.orangeAccent,
                                  ),
                                );
                                return;
                              }
                              if (reasonController.text.trim().isEmpty) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Silakan isi alasan pengajuan perpindahan jadwal.'),
                                    backgroundColor: Colors.orangeAccent,
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => isSubmitting = true);

                              try {
                                if (session.patientId == 'guest') {
                                  // Simulasi guest
                                  await Future.delayed(const Duration(seconds: 1));
                                  final idx = _visits.indexWhere((v) => v['id'] == visit['id']);
                                  if (idx != -1) {
                                    setState(() {
                                      _visits[idx]['reschedule_requested'] = true;
                                      _visits[idx]['reschedule_to_date'] =
                                          selectedDate!.toIso8601String().split('T').first;
                                      _visits[idx]['reschedule_reason'] = reasonController.text.trim();
                                    });
                                  }
                                } else {
                                  // Kirim riil ke Supabase RPC
                                  await _patientService.requestReschedule(
                                    visitId: visit['id'],
                                    patientId: session.patientId,
                                    newDate: selectedDate!,
                                    reason: reasonController.text.trim(),
                                  );
                                  await _loadData(); // Segarkan data
                                }

                                if (mounted) {
                                  navigator.pop();
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '✅ Pengajuan berhasil dikirim',
                                        style: GoogleFonts.manrope(color: Colors.white),
                                      ),
                                      backgroundColor: const Color(0xFF2E7D32),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSubmitting = false);
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal mengirim pengajuan: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF001833),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Kirim Pengajuan',
                              style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF112D4E)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 64, color: Color(0xFFC4C6CF)),
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
                  style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF5A8DA0)),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF001833),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeVisitNumber = _getActiveVisitNumber();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF112D4E),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
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
                const SizedBox(height: 28),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _visits.length,
                  itemBuilder: (ctx, index) {
                    final visit = _visits[index];
                    final visitNum = visit['visit_number'] as int? ?? (index + 1);

                    // Menentukan status visual
                    String visualStatus = 'locked';
                    if (visit['status']?.toString().toLowerCase() == 'done' ||
                        visit['status']?.toString().toLowerCase() == 'completed') {
                      visualStatus = 'done';
                    } else if (visitNum == activeVisitNumber) {
                      visualStatus = 'active';
                    }

                    return _buildTimelineItem(visit, visualStatus, index == _visits.length - 1);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jadwal Kontrol',
          style: GoogleFonts.manrope(
            color: const Color(0xFF001833),
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pantau jadwal kontrol bulanan Anda untuk memastikan pemulihan yang optimal.',
          style: GoogleFonts.manrope(
            color: const Color(0xFF64748B),
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> visit, String visualStatus, bool isLast) {
    final visitNum = visit['visit_number'] as int? ?? 1;

    Widget leftTimeline;
    Widget cardChild;

    if (visualStatus == 'done') {
      // Selesai (Month 1)
      leftTimeline = Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFF112D4E), width: 2),
            ),
            child: const Center(
              child: Icon(Icons.done_rounded, color: Color(0xFF112D4E), size: 16),
            ),
          ),
          if (!isLast)
            Expanded(
              child: Container(width: 2, color: const Color(0xFFE2E8F0)),
            ),
        ],
      );

      cardChild = Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bulan $visitNum',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F8E8),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Selesai',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E824C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Text(
                  'Selesai pada ${_formatDateString(visit['scheduled_date'])}',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  visit['location'] ?? 'Puskesmas',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (visualStatus == 'active') {
      // Mendatang / Aktif (Month 2)
      final rescheduleRequested = visit['reschedule_requested'] == true;

      leftTimeline = Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFDBE2EF),
            ),
            child: Center(
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF112D4E),
                ),
              ),
            ),
          ),
          if (!isLast)
            Expanded(
              child: Container(width: 2, color: const Color(0xFFE2E8F0)),
            ),
        ],
      );

      cardChild = Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C112D4E),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Garis kiri biru vertikal penanda kartu aktif
              Container(
                width: 4,
                color: const Color(0xFF112D4E),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Bulan $visitNum',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF001833),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5F0FF),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              rescheduleRequested ? 'Pindah Diajukan' : 'Mendatang',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF112D4E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF112D4E)),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateString(visit['scheduled_date']),
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF001833),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              visit['location'] ?? 'Puskesmas',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFEDF2F7)),
                      const SizedBox(height: 16),

                      // Cek jika sudah diajukan reschedule
                      if (rescheduleRequested)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFEAA7)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Perpindahan jadwal diajukan ke: ${_formatDateString(visit['reschedule_to_date'] ?? '')}. Menunggu persetujuan dokter.',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFD68F00),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showRescheduleSheet(visit),
                            icon: const Icon(Icons.calendar_month_rounded, size: 16),
                            label: Text(
                              'Ajukan Perpindahan Jadwal Kontrol',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF112D4E),
                              side: const BorderSide(color: Color(0xFF112D4E), width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Terkunci (Months 3 - 6)
      leftTimeline = Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
            ),
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ),
          ),
          if (!isLast)
            Expanded(
              child: Container(width: 2, color: const Color(0xFFE2E8F0)),
            ),
        ],
      );

      cardChild = Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulan $visitNum',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Estimasi ${_formatDateString(visit['scheduled_date'])}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      );
    }

    return SizedBox(
      height: visualStatus == 'active' ? 245 : 125,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leftTimeline,
          const SizedBox(width: 16),
          Expanded(child: cardChild),
        ],
      ),
    );
  }
}
