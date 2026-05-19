import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_patient_page.dart';
import 'doctor_feedback_page.dart';
import 'doctor_profile_page.dart';
import 'patient_detail_page.dart';
import 'package:tbconnect/widgets/doctor_bottom_nav_bar.dart';
import 'package:tbconnect/services/doctor_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.embedded = false});

  /// When [embedded] is true, the page renders without its own [Scaffold]
  /// or [DoctorBottomNavBar] so it can be placed inside [DoctorMainShell].
  final bool embedded;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DoctorService _doctorService = DoctorService();

  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _expandedPatients = {};

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTriageData();
  }

  Future<void> _loadTriageData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _doctorService.getTriageBoard();
      if (mounted) {
        setState(() {
          _patients = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data: $e';
        });
      }
    }
  }

  String get _dayLabel {
    final weekday = _selectedDate.weekday;
    const names = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return names[weekday - 1];
  }

  String get _monthLabel {
    const names = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return names[_selectedDate.month - 1];
  }

  Future<void> _pickLogDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF112D4E)),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tanggal log dipilih: ${picked.day} $_monthLabel ${picked.year}'),
        ),
      );
    }
  }

  void _handleNavTap(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddPatientPage()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DoctorProfilePage()),
      );
    }
  }

  // ──────────────────────────────────────────────
  // Helper: ambil status & warna berdasarkan triage
  // ──────────────────────────────────────────────
  ({String label, Color color, String subtitle}) _resolveStatus(
      Map<String, dynamic> patient) {
    final hasEmergency = patient['has_emergency_symptom'] == true;
    final hasMissed = patient['has_missed_medication'] == true;
    final priority = patient['priority_level'] as int? ?? 3;

    if (hasEmergency || priority == 1) {
      return (
        label: 'Segera',
        color: const Color(0xFFDE2C2C),
        subtitle: 'Gejala darurat terdeteksi',
      );
    } else if (hasMissed || priority == 2) {
      return (
        label: 'Terlambat',
        color: const Color(0xFF527BBF),
        subtitle: 'Belum lapor minum obat hari ini',
      );
    } else {
      return (
        label: 'Stabil',
        color: const Color(0xFF4B7DD8),
        subtitle: 'Tidak ada gejala berat',
      );
    }
  }

  // ──────────────────────────────────────────────
  // Helper: teks log harian
  // ──────────────────────────────────────────────
  String _dailyLogText(Map<String, dynamic> patient) {
    final adherence = patient['adherence_7d_pct'];
    final weight = patient['latest_weight_kg'];

    final parts = <String>[];
    if (adherence != null) {
      parts.add('Kepatuhan 7 hari: $adherence%');
    }
    if (weight != null) {
      parts.add('Berat terbaru: $weight kg');
    }
    if (parts.isEmpty) {
      return 'Belum ada data laporan harian.';
    }
    return parts.join(' | ');
  }

  // ──────────────────────────────────────────────
  // Helper: gejala yang terdeteksi
  // ──────────────────────────────────────────────
  List<String> _symptoms(Map<String, dynamic> patient) {
    final list = <String>[];
    if (patient['has_emergency_symptom'] == true) {
      list.add('Gejala Darurat');
    }
    if (patient['has_missed_medication'] == true) {
      list.add('Obat Terlewat');
    }
    final adherence = patient['adherence_7d_pct'];
    if (adherence != null && (adherence as num) < 80) {
      list.add('Kepatuhan Rendah');
    }
    if (list.isEmpty) {
      list.add('Tidak ada gejala');
    }
    return list;
  }

  // ──────────────────────────────────────────────
  // Helper: catatan tambahan
  // ──────────────────────────────────────────────
  String _additionalNote(Map<String, dynamic> patient) {
    final hasEmergency = patient['has_emergency_symptom'] == true;
    final hasMissed = patient['has_missed_medication'] == true;
    final adherence = patient['adherence_7d_pct'];

    if (hasEmergency) {
      return '⚠️ Pasien melaporkan gejala darurat. Segera lakukan evaluasi dan konfirmasi kondisi pasien.';
    }
    if (hasMissed) {
      return 'Hubungi pasien untuk memastikan kondisi dan mengingatkan minum obat.';
    }
    if (adherence != null && (adherence as num) < 80) {
      return 'Kepatuhan minum obat perlu ditingkatkan. Berikan edukasi dan motivasi ke pasien.';
    }
    return 'Pasien dalam kondisi stabil. Pantau secara rutin.';
  }

  // ──────────────────────────────────────────────
  // Helper: inisial
  // ──────────────────────────────────────────────
  String _initials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadTriageData,
        color: const Color(0xFF112D4E),
        child: _buildBody(),
      ),
    );

    // When embedded in DoctorMainShell, return just the body (no Scaffold/BottomNav)
    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE5F0FF),
              ),
              child: const Icon(Icons.dashboard, color: Color(0xFF112D4E)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dasbor Triase',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF112D4E),
                    )),
                Text('Pantau pasien Anda secara real-time',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: const Color(0xFF5A8DA0),
                    )),
              ],
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Color(0xFFE5F0FF),
              child: Icon(Icons.person, color: Color(0xFF112D4E)),
            ),
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: _pickLogDate,
        backgroundColor: const Color(0xFF112D4E),
        child: const Icon(Icons.calendar_today),
      ),
      bottomNavigationBar: DoctorBottomNavBar(
        currentIndex: 0,
        onTap: _handleNavTap,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF112D4E)),
      );
    }

    if (_errorMessage != null) {
      return Center(
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
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: const Color(0xFF5A8DA0),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadTriageData,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      children: [
        _buildDateCard(),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('Daftar Prioritas',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF112D4E),
                )),
            const Spacer(),
            Text('${_patients.length} pasien',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: const Color(0xFF5A8DA0),
                )),
          ],
        ),
        const SizedBox(height: 14),
        if (_patients.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.people_outline_rounded,
                      size: 64, color: Color(0xFFC4C6CF)),
                  const SizedBox(height: 12),
                  Text('Belum ada pasien',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF112D4E),
                      )),
                  const SizedBox(height: 4),
                  Text('Tambahkan pasien baru untuk memulai',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: const Color(0xFF5A8DA0),
                      )),
                ],
              ),
            ),
          )
        else
          ..._patients.map((patient) => _buildPatientCard(patient)),
      ],
    );
  }

  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A112D4E),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hari ini',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF5A8DA0),
              )),
          const SizedBox(height: 8),
          Text('$_dayLabel, ${_selectedDate.day} $_monthLabel ${_selectedDate.year}',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF112D4E),
              )),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final name = patient['full_name'] as String? ?? 'Pasien';
    final patientId = patient['patient_id'] as String?;
    final initials = _initials(name);
    final status = _resolveStatus(patient);
    final dailyLog = _dailyLogText(patient);
    final symptomsList = _symptoms(patient);
    final note = _additionalNote(patient);
    final isExpanded = _expandedPatients.contains(patientId);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A112D4E),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header (always visible + tappable) ──
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedPatients.remove(patientId);
                } else {
                  _expandedPatients.add(patientId!);
                }
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: ShapeDecoration(
                color: const Color(0xFFF8F9FA),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: 1,
                    color: const Color(0xFFE7E8E9),
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isExpanded ? 0 : 20),
                    topRight: Radius.circular(isExpanded ? 0 : 20),
                    bottomLeft: Radius.circular(isExpanded ? 0 : 20),
                    bottomRight: Radius.circular(isExpanded ? 0 : 20),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Avatar (fixed)
                  Container(
                    width: 47.8,
                    height: 48,
                    decoration: ShapeDecoration(
                      color: const Color(0xFF112D4E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.w700,
                          height: 1.50,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Name + status (flexible, with marquee for overflow)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Color(0xFF001833),
                            fontSize: 18,
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                            height: 1.56,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        _MarqueeText(
                          text: status.subtitle,
                          style: const TextStyle(
                            color: Color(0xFF43474E),
                            fontSize: 12,
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w600,
                            height: 1.33,
                            letterSpacing: 0.60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: ShapeDecoration(
                      color: status.color.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        color: status.color,
                        fontSize: 12,
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w600,
                        height: 1.33,
                        letterSpacing: 0.60,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Animated dropdown arrow
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF43474E),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded Detail (animated) ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: _buildExpandedContent(
                dailyLog: dailyLog,
                symptomsList: symptomsList,
                note: note,
                name: name,
                patientId: patientId,
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeIn,
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent({
    required String dailyLog,
    required List<String> symptomsList,
    required String note,
    required String name,
    required String? patientId,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        // LOG HARIAN TERAKHIR
        const Text(
          'LOG HARIAN TERAKHIR',
          style: TextStyle(
            color: Color(0xFF43474E),
            fontSize: 12,
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w600,
            height: 1.33,
            letterSpacing: 0.60,
          ),
        ),

        // ── Medication / Daily log ──
        _DailyLogRow(
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF2A609C),
          title: 'Log Harian',
          description: dailyLog,
        ),

        // ── Symptoms ──
        if (symptomsList.isNotEmpty) ...[
          const Divider(height: 1, color: Color(0xFFEDEEEF)),
          _DailyLogRow(
            icon: Icons.healing_rounded,
            iconColor: const Color(0xFFE19200),
            title: 'Gejala Terdeteksi',
            trailing: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: symptomsList
                  .map((s) => _SymptomChip(
                        label: s,
                        bgColor: s == 'Gejala Darurat'
                            ? Colors.redAccent.withValues(alpha: 0.1)
                            : const Color(0xFFF3F4F5),
                        textColor: s == 'Gejala Darurat'
                            ? Colors.redAccent
                            : const Color(0xFF43474E),
                        borderColor: s == 'Gejala Darurat'
                            ? Colors.redAccent.withValues(alpha: 0.3)
                            : const Color(0x7FC4C6CF),
                      ))
                  .toList(),
            ),
          ),
        ],

        // ── Notes / Additional ──
        const Divider(height: 1, color: Color(0xFFEDEEEF)),
        _DailyLogRow(
          icon: Icons.edit_note_rounded,
          iconColor: const Color(0xFF5A8DA0),
          title: 'Catatan Tambahan',
          description: note,
        ),

        // ── Action Buttons ──
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorFeedbackPage(
                          patientName: name,
                          patientId: patientId,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF001833),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Berikan Feedback',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                      height: 1.33,
                      letterSpacing: 0.60,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientDetailPage(
                          patientName: name,
                          patientId: patientId,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      width: 2,
                      color: Color(0x33001833),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Detail Pasien',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF001833),
                      fontSize: 12,
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                      height: 1.33,
                      letterSpacing: 0.60,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Reusable Widgets for Patient Cards
// =============================================================================

/// A text widget that auto-scrolls (marquee) when content overflows.
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _MarqueeText({
    required this.text,
    required this.style,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with TickerProviderStateMixin {
  late ScrollController _controller;
  bool _overflowing = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback(_checkOverflow);
  }

  void _checkOverflow(_) {
    if (!mounted) return;
    final textWidth = _measureTextWidth();
    final availableWidth = context.size?.width ?? 200;
    if (textWidth > availableWidth && !_overflowing) {
      setState(() => _overflowing = true);
      _startScrolling(textWidth, availableWidth);
    }
  }

  double _measureTextWidth() {
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width;
  }

  void _startScrolling(double textWidth, double availableWidth) {
    const pause = Duration(seconds: 2);
    const scrollDur = Duration(seconds: 8);
    final scrollDistance = textWidth - availableWidth + 20;

    Future.delayed(pause, () {
      if (!mounted) return;
      _controller
          .animateTo(scrollDistance, duration: scrollDur, curve: Curves.linear)
          .then((_) {
        if (!mounted) return;
        Future.delayed(pause, () {
          if (!mounted) return;
          _controller
              .animateTo(0, duration: scrollDur, curve: Curves.linear)
              .then((_) {
            if (!mounted) return;
            _startScrolling(textWidth, availableWidth);
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: (widget.style.fontSize ?? 12) * 1.4,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          style: widget.style,
          maxLines: 1,
        ),
      ),
    );
  }
}

class _DailyLogRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? description;
  final Widget? trailing;

  const _DailyLogRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.description,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF191C1D),
                  fontSize: 16,
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w500,
                  height: 1.50,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: const TextStyle(
                    color: Color(0xFF43474E),
                    fontSize: 14,
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w400,
                    height: 1.43,
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(height: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SymptomChip extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;

  const _SymptomChip({
    required this.label,
    this.bgColor = const Color(0xFFF3F4F5),
    this.textColor = const Color(0xFF43474E),
    this.borderColor = const Color(0x7FC4C6CF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: ShapeDecoration(
        color: bgColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1, color: borderColor),
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w600,
          height: 1.33,
          letterSpacing: 0.60,
        ),
      ),
    );
  }
}
