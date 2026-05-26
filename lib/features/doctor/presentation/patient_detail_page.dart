import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tbconnect/services/doctor_service.dart';

class PatientDetailPage extends StatefulWidget {
  final String patientName;
  final String? patientId;

  const PatientDetailPage({
    super.key,
    required this.patientName,
    this.patientId,
  });

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  final _doctorService = DoctorService();
  Map<String, dynamic>? _patientData;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.patientId != null) {
      _loadPatientDetail();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadPatientDetail() async {
    try {
      final data = await _doctorService.getPatientDetail(widget.patientId!);
      if (mounted) {
        setState(() {
          _patientData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  List<Map<String, dynamic>> _dateMedicationLogs() {
    final logs = _patientData?['medication_logs'];
    if (logs is! List) return [];
    final selectedDateStr = _selectedDate.toIso8601String().split('T').first;
    return logs
        .where((l) => (l['log_date'] as String?)?.startsWith(selectedDateStr) == true)
        .map((l) => Map<String, dynamic>.from(l as Map))
        .toList();
  }

  int get _totalDosesForDate => 3;
  int get _takenDosesForDate {
    final logs = _dateMedicationLogs();
    return logs.where((l) => l['status'] == 'taken' || l['status'] == 'late').length;
  }

  double get _adherencePercent {
    if (_totalDosesForDate == 0) return 0;
    return (_takenDosesForDate / _totalDosesForDate * 100).clamp(0, 100);
  }

  String _medSessionIcon(String session) {
    switch (session) {
      case 'morning': return '🌅';
      case 'afternoon': return '☀️';
      case 'evening': return '🌙';
      default: return '💊';
    }
  }

  String _medSessionLabel(String session) {
    switch (session) {
      case 'morning': return 'Pagi';
      case 'afternoon': return 'Siang';
      case 'evening': return 'Malam';
      default: return session;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'taken': return const Color(0xFF2E7D32);
      case 'late': return const Color(0xFFE19200);
      case 'missed': return const Color(0xFFC50000);
      default: return const Color(0xFF43474E);
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'taken': return 'Diminum';
      case 'late': return 'Terlambat';
      case 'missed': return 'Terlewat';
      default: return 'Menunggu';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF112D4E)))
          : _patientData == null
              ? Center(
                  child: Text(
                    'Data pasien tidak tersedia',
                    style: GoogleFonts.manrope(color: const Color(0xFF5A8DA0)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPatientDetail,
                  child: CustomScrollView(
                    slivers: [
                      _buildSliverAppBar(),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildGlobalDateSelector(),
                              const SizedBox(height: 24),
                              _buildMedicationAdherenceSection(),
                              const SizedBox(height: 24),
                              _buildWeightSection(),
                              const SizedBox(height: 24),
                              _buildSymptomSection(),
                              const SizedBox(height: 24),
                              _buildInfoSection(),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSliverAppBar() {
    final gender = _patientData!['gender'] == 'male' ? 'Laki-laki' : 'Perempuan';
    final age = _patientData!['age'] ?? '-';
    final nik = _patientData!['nik'] ?? '-';
    final initWeight = _patientData!['initial_weight_kg'] ?? '-';
    final name = _patientData!['full_name'] ?? widget.patientName;
    final encodedName = Uri.encodeComponent(name);

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF112D4E),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF112D4E), Color(0xFF3F72AF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                      image: DecorationImage(
                        image: NetworkImage("https://ui-avatars.com/api/?name=$encodedName&background=DBE2EF&color=112D4E&size=128"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ID: $nik',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeaderTag('$age Thn'),
                      const SizedBox(width: 8),
                      _buildHeaderTag(gender),
                      const SizedBox(width: 8),
                      _buildHeaderTag('Berat Awal: $initWeight kg'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          color: Colors.white.withOpacity(0.95),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGlobalDateSelector() {
    final now = DateTime.now();
    final isToday = _selectedDate.day == now.day &&
                    _selectedDate.month == now.month &&
                    _selectedDate.year == now.year;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A112D4E), blurRadius: 15, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tanggal Laporan',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A8DA0),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isToday ? 'Hari Ini (${_formatDate(_selectedDate)})' : _formatDate(_selectedDate),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF112D4E),
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _selectGlobalDate(context),
            icon: const Icon(Icons.calendar_month, size: 18),
            label: const Text('Ubah'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5F0FF),
              foregroundColor: const Color(0xFF112D4E),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectGlobalDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF112D4E),
              onPrimary: Colors.white,
              onSurface: Color(0xFF112D4E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildMedicationAdherenceSection() {
    final logs = _dateMedicationLogs();
    final sessions = ['morning', 'afternoon', 'evening'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x05112D4E), blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE5F0FF), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.medication, color: Color(0xFF3F72AF), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Kepatuhan Obat',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF112D4E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: _totalDosesForDate > 0 ? (_takenDosesForDate / _totalDosesForDate) : 0,
                      strokeWidth: 8,
                      backgroundColor: const Color(0xFFEDEEEF),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _adherencePercent >= 66 ? const Color(0xFF2E7D32) : const Color(0xFFE19200),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${_adherencePercent.toInt()}%',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: const Color(0xFF112D4E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Telah diminum:',
                      style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF5A8DA0)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_takenDosesForDate dari $_totalDosesForDate dosis',
                      style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF112D4E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...sessions.map((session) {
            final log = logs.cast<Map<String, dynamic>?>().firstWhere(
                  (l) => l?['session'] == session,
                  orElse: () => null,
                );
            return _buildMedicationSessionTile(session, log);
          }),
        ],
      ),
    );
  }

  Widget _buildMedicationSessionTile(String session, Map<String, dynamic>? log) {
    final status = log?['status'] as String?;
    final takenAt = log?['taken_at'] as String?;
    final reason = log?['late_reason'] as String?;
    
    Color bgColor = const Color(0xFFF8F9FA);
    Color borderColor = const Color(0xFFE1E3E4);
    
    if (status == 'taken') {
      bgColor = const Color(0xFFF2F9F3);
      borderColor = const Color(0xFF81C784).withOpacity(0.5);
    } else if (status == 'late') {
      bgColor = const Color(0xFFFFF9F0);
      borderColor = const Color(0xFFFFB74D).withOpacity(0.5);
    } else if (status == 'missed') {
      bgColor = const Color(0xFFFFF2F2);
      borderColor = const Color(0xFFE57373).withOpacity(0.5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
            ),
            child: Text(_medSessionIcon(session), style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _medSessionLabel(session),
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF112D4E)),
                ),
                if (takenAt != null)
                  Text(
                    '⏱ ${takenAt.substring(11, 19)}',
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF5A8DA0)),
                  ),
                if (reason != null && reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Alasan: $reason',
                      style: GoogleFonts.manrope(fontSize: 12, fontStyle: FontStyle.italic, color: const Color(0xFFBA7600)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel(status),
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 12, color: _statusColor(status)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightSection() {
    final logs = _patientData?['weight_logs'];
    final List<Map<String, dynamic>> weightLogs = logs is List
        ? logs.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x05112D4E), blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.monitor_weight_outlined, color: Color(0xFF2E7D32), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Log Berat Badan',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: const Color(0xFF112D4E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (weightLogs.isEmpty)
            Text(
              'Belum ada data berat badan.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: const Color(0xFF5A8DA0),
                fontStyle: FontStyle.italic,
              ),
            )
          else
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: weightLogs.length > 5 ? 5 : weightLogs.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final log = weightLogs[index];
                  final dateStr = log['log_date'] as String? ?? '';
                  final date = dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
                  final wt = log['weight_kg'];
                  return Container(
                    width: 110,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE1E3E4)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$wt kg',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF112D4E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5A8DA0),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSymptomSection() {
    final logs = _patientData?['symptom_logs'];
    final List<Map<String, dynamic>> allSymptomLogs = logs is List
        ? logs.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];

    final dailyReports = _patientData?['daily_symptom_reports'];
    final List<Map<String, dynamic>> allDailyReports = dailyReports is List
        ? dailyReports.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];

    final selectedDateStr = _selectedDate.toIso8601String().split('T').first;
    final filteredSymptomLogs = allSymptomLogs
        .where((l) => (l['log_date'] as String?)?.startsWith(selectedDateStr) == true)
        .toList();
    final filteredDailyReports = allDailyReports
        .where((r) => (r['report_date'] as String?)?.startsWith(selectedDateStr) == true)
        .toList();

    final hasEmergency =
        filteredSymptomLogs.any((l) => l['is_emergency'] == true) ||
        filteredDailyReports.any((r) => (r['emergency_symptoms'] as List?)?.isNotEmpty == true);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05112D4E),
            blurRadius: 20,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.health_and_safety_outlined, color: Color(0xFFE19200), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Riwayat Gejala',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: const Color(0xFF112D4E),
                    ),
                  ),
                ],
              ),
              if (hasEmergency)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '⚠️ Darurat',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          if (filteredSymptomLogs.isEmpty && filteredDailyReports.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E3E4)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.sentiment_satisfied_alt, color: Color(0xFFC4C6CF), size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada laporan gejala pada tanggal ini.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: const Color(0xFF5A8DA0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (filteredDailyReports.isNotEmpty) ...[
              ...filteredDailyReports.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDailySymptomReportCard(r),
              )),
            ],
            if (filteredSymptomLogs.isNotEmpty) ...[
              if (filteredDailyReports.isNotEmpty) const SizedBox(height: 12),
              ...filteredSymptomLogs.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSymptomCard(l),
              )),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildModernTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDailySymptomReportCard(Map<String, dynamic> report) {
    final moodLevel = report['mood_level'] as String? ?? '';
    final symptoms = (report['symptoms'] as List?)?.cast<String>() ?? [];
    final emergencySymptoms = (report['emergency_symptoms'] as List?)?.cast<String>() ?? [];
    final notes = report['notes'] as String?;

    final moodLabels = {
      'sangat_buruk': 'Sangat Buruk',
      'kurang_baik': 'Kurang Baik',
      'cukup_baik': 'Cukup Baik',
      'sangat_baik': 'Sangat Baik',
    };

    final moodIcons = {
      'sangat_buruk': '😞',
      'kurang_baik': '😐',
      'cukup_baik': '🙂',
      'sangat_baik': '😊',
    };

    final moodColors = {
      'sangat_buruk': Colors.redAccent,
      'kurang_baik': const Color(0xFFE19200),
      'cukup_baik': const Color(0xFF2E7D32),
      'sangat_baik': const Color(0xFF3F72AF),
    };

    final moodColor = moodColors[moodLevel] ?? const Color(0xFF5A8DA0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBE2EF)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: moodColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(moodIcons[moodLevel] ?? '😐', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Text(
                  'Perasaan: ${moodLabels[moodLevel] ?? moodLevel}',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: moodColor.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (symptoms.isNotEmpty) ...[
                  Text('Gejala Terdeteksi', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF5A8DA0))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: symptoms.map((s) => _buildModernTag(s, const Color(0xFFE5F0FF), const Color(0xFF112D4E))).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (emergencySymptoms.isNotEmpty) ...[
                  Text('Gejala Darurat', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.redAccent)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: emergencySymptoms.map((s) => _buildModernTag(s, Colors.redAccent.withOpacity(0.1), Colors.redAccent)).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (notes != null && notes.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE1E3E4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Catatan Pasien:', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF5A8DA0))),
                        const SizedBox(height: 4),
                        Text(
                          notes,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: const Color(0xFF112D4E),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (symptoms.isEmpty && emergencySymptoms.isEmpty && (notes == null || notes.isEmpty))
                  Text(
                    'Hanya melaporkan perasaan.',
                    style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF5A8DA0), fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomCard(Map<String, dynamic> symptom) {
    final nausea = symptom['nausea_level'] ?? 0;
    final dizziness = symptom['dizziness_level'] ?? 0;
    final fatigue = symptom['fatigue_level'] ?? 0;
    final hemoptysis = symptom['hemoptysis'] == true;
    final chestPain = symptom['chest_pain'] == true;
    final sob = symptom['shortness_of_breath'] == true;

    final symptoms = <String>[];
    if (nausea is int && nausea > 0) symptoms.add('Mual ($nausea/3)');
    if (dizziness is int && dizziness > 0) symptoms.add('Pusing ($dizziness/3)');
    if (fatigue is int && fatigue > 0) symptoms.add('Lelah ($fatigue/3)');
    if (hemoptysis) symptoms.add('Batuk Darah');
    if (chestPain) symptoms.add('Nyeri Dada');
    if (sob) symptoms.add('Sesak Nafas');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDBE2EF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Laporan Gejala Tambahan',
            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF5A8DA0)),
          ),
          const SizedBox(height: 8),
          if (symptoms.isEmpty)
            Text(
              'Tidak ada gejala spesifik',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: symptoms
                  .map((s) => _buildModernTag(s, const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05112D4E),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE5F0FF), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.info_outline, color: Color(0xFF3F72AF), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Informasi Klinis',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: const Color(0xFF112D4E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _infoRow(Icons.local_hospital_outlined, 'Faskes', _patientData!['faskes_name'] ?? '-'),
          const Divider(color: Color(0xFFF3F5F9), height: 24),
          _infoRow(Icons.location_on_outlined, 'Alamat', _patientData!['address'] ?? '-'),
          const Divider(color: Color(0xFFF3F5F9), height: 24),
          _infoRow(Icons.phone_outlined, 'No. Telepon', _patientData!['phone_number'] ?? '-'),
          const Divider(color: Color(0xFFF3F5F9), height: 24),
          _infoRow(Icons.verified_user_outlined, 'Status', _patientData!['status'] ?? '-'),
          const Divider(color: Color(0xFFF3F5F9), height: 24),
          _infoRow(Icons.event_available_outlined, 'Mulai Berobat', _patientData!['treatment_start_date'] ?? '-'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF5A8DA0), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: const Color(0xFF5A8DA0),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF112D4E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
