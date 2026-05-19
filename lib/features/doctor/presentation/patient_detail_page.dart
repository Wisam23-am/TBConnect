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

  // ── Helpers ──

  List<Map<String, dynamic>> _todayMedicationLogs() {
    final logs = _patientData?['medication_logs'];
    if (logs is! List) return [];
    final today = DateTime.now().toIso8601String().split('T').first;
    return logs
        .where((l) => (l['log_date'] as String?)?.startsWith(today) == true)
        .map((l) => Map<String, dynamic>.from(l as Map))
        .toList();
  }

  int get _totalDosesToday => 3;

  int get _takenDosesToday => _todayMedicationLogs().length;

  double get _adherencePercent {
    if (_totalDosesToday == 0) return 0;
    return (_takenDosesToday / _totalDosesToday * 100).clamp(0, 100);
  }

  String _medSessionIcon(String session) {
    switch (session) {
      case 'morning':
        return '🌅';
      case 'afternoon':
        return '☀️';
      case 'evening':
        return '🌙';
      default:
        return '💊';
    }
  }

  String _medSessionLabel(String session) {
    switch (session) {
      case 'morning':
        return 'Pagi';
      case 'afternoon':
        return 'Siang';
      case 'evening':
        return 'Malam';
      default:
        return session;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'taken':
        return const Color(0xFF2E7D32);
      case 'late':
        return const Color(0xFFE19200);
      case 'missed':
        return const Color(0xFFC50000);
      default:
        return const Color(0xFF43474E);
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'taken':
        return 'Diminum';
      case 'late':
        return 'Terlambat';
      case 'missed':
        return 'Terlewat';
      default:
        return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.patientName,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF112D4E),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF112D4E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _patientData == null
              ? Center(
                  child: Text(
                    'Data pasien tidak tersedia',
                    style: GoogleFonts.manrope(color: const Color(0xFF5A8DA0)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPatientDetail,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildInfoSection('Informasi Pasien', [
                        _infoRow('Nama', _patientData!['full_name'] ?? '-'),
                        _infoRow('Umur', '${_patientData!['age'] ?? '-'} tahun'),
                        _infoRow(
                            'Gender',
                            _patientData!['gender'] == 'male'
                                ? 'Laki-laki'
                                : 'Perempuan'),
                        _infoRow('NIK', _patientData!['nik'] ?? '-'),
                        _infoRow('QR Code', _patientData!['qr_code'] ?? '-'),
                      ]),
                      const SizedBox(height: 16),

                      // ── Medication Adherence for Today ──
                      _buildMedicationAdherenceSection(),

                      const SizedBox(height: 16),
                      _buildInfoSection('Data Pengobatan', [
                        _infoRow(
                            'Berat Awal',
                            '${_patientData!['initial_weight_kg'] ?? '-'} kg'),
                        _infoRow('Mulai Berobat',
                            _patientData!['treatment_start_date'] ?? '-'),
                        _infoRow('Status', _patientData!['status'] ?? '-'),
                      ]),
                      const SizedBox(height: 16),

                      // ── Latest Weight Logs ──
                      _buildWeightSection(),

                      const SizedBox(height: 16),

                      // ── Latest Symptoms ──
                      _buildSymptomSection(),

                      const SizedBox(height: 16),
                      _buildInfoSection('Klinis', [
                        _infoRow('Faskes', _patientData!['faskes_name'] ?? '-'),
                        _infoRow('Alamat', _patientData!['address'] ?? '-'),
                        _infoRow(
                            'No. Telepon', _patientData!['phone_number'] ?? '-'),
                      ]),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Medication Adherence Section
  // ──────────────────────────────────────────────────────────────
  Widget _buildMedicationAdherenceSection() {
    final todayLogs = _todayMedicationLogs();
    final sessions = ['morning', 'afternoon', 'evening'];

    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kepatuhan Minum Obat Hari Ini',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: const Color(0xFF112D4E),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _adherencePercent >= 66
                      ? const Color(0xFF2E7D32).withOpacity(0.1)
                      : const Color(0xFFE19200).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_adherencePercent.toInt()}%',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _adherencePercent >= 66
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE19200),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _adherencePercent / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFEDEEEF),
              valueColor: AlwaysStoppedAnimation<Color>(
                _adherencePercent >= 66
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFE19200),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(sessions.length, (i) {
            final session = sessions[i];
            final log = todayLogs.cast<Map<String, dynamic>?>().firstWhere(
                  (l) => l?['session'] == session,
                  orElse: () => null,
                );
            final status = log?['status'] as String?;
            final takenAt = log?['taken_at'] as String?;
            final reason = log?['late_reason'] as String?;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: status == 'taken'
                      ? const Color(0xFF2E7D32).withOpacity(0.05)
                      : status == 'late'
                          ? const Color(0xFFE19200).withOpacity(0.08)
                          : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: status == 'taken'
                        ? const Color(0xFF2E7D32).withOpacity(0.2)
                        : status == 'late'
                            ? const Color(0xFFE19200).withOpacity(0.3)
                            : const Color(0xFFE1E3E4),
                  ),
                ),
                child: Row(
                  children: [
                    Text(_medSessionIcon(session),
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _medSessionLabel(session),
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: const Color(0xFF112D4E),
                            ),
                          ),
                          if (takenAt != null)
                            Text(
                              '⏱ ${takenAt.substring(11, 19)}',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: const Color(0xFF5A8DA0),
                              ),
                            ),
                          if (reason != null && reason.isNotEmpty)
                            Text(
                              reason,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFFBA7600),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: _statusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Latest Weight Section
  // ──────────────────────────────────────────────────────────────
  Widget _buildWeightSection() {
    final logs = _patientData?['weight_logs'];
    final List<Map<String, dynamic>> weightLogs = logs is List
        ? logs.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];

    final initialWt = _patientData!['initial_weight_kg'];
    final latestWt =
        weightLogs.isNotEmpty ? weightLogs.first['weight_kg'] : null;

    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            'Riwayat Berat Badan',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: const Color(0xFF112D4E),
            ),
          ),
          const SizedBox(height: 12),
          if (initialWt != null) _infoRow('Berat Awal', '$initialWt kg'),
          if (latestWt != null) ...[
            _infoRow('Berat Terbaru', '$latestWt kg'),
            if (initialWt != null) _buildWeightChangeRow(initialWt, latestWt),
          ],
          if (weightLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Belum ada data berat badan.',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: const Color(0xFF5A8DA0),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (weightLogs.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: weightLogs.length.clamp(0, 5),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final log = weightLogs[i];
                    final date =
                        (log['log_date'] as String?)?.substring(5, 10) ?? '';
                    final wt = log['weight_kg'];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$date: $wt kg',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Latest Symptom Section
  // ──────────────────────────────────────────────────────────────
  Widget _buildSymptomSection() {
    final logs = _patientData?['symptom_logs'];
    final List<Map<String, dynamic>> symptomLogs = logs is List
        ? logs.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];

    final dailyReports = _patientData?['daily_symptom_reports'];
    final List<Map<String, dynamic>> dailySymptomReports =
        dailyReports is List
            ? dailyReports
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
            : [];

    final hasEmergency =
        symptomLogs.any((l) => l['is_emergency'] == true) ||
            dailySymptomReports.any(
                (r) => (r['emergency_symptoms'] as List?)?.isNotEmpty == true);

    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gejala Terkini',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: const Color(0xFF112D4E),
                ),
              ),
              if (hasEmergency)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '⚠️ Darurat',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (symptomLogs.isEmpty && dailySymptomReports.isEmpty)
            Text(
              'Belum ada laporan gejala.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: const Color(0xFF5A8DA0),
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            if (dailySymptomReports.isNotEmpty) ...[
              _buildDailySymptomReportCard(dailySymptomReports.first),
              if (dailySymptomReports.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${dailySymptomReports.length} laporan harian tersedia',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: const Color(0xFF5A8DA0),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            if (symptomLogs.isNotEmpty) ...[
              Text(
                'Riwayat Gejala (Lama)',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A8DA0),
                ),
              ),
              const SizedBox(height: 8),
              _buildSymptomCard(symptomLogs.first),
              if (symptomLogs.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${symptomLogs.length} laporan tersedia',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: const Color(0xFF5A8DA0),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildWeightChangeRow(dynamic initialWt, dynamic latestWt) {
    final init = (initialWt as num).toDouble();
    final latest = (latestWt as num).toDouble();
    final diff = latest - init;
    return _infoRow(
      'Perubahan',
      '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg',
    );
  }

  Widget _buildDailySymptomReportCard(Map<String, dynamic> report) {
    final moodLevel = report['mood_level'] as String? ?? '';
    final symptoms = (report['symptoms'] as List?)?.cast<String>() ?? [];
    final emergencySymptoms =
        (report['emergency_symptoms'] as List?)?.cast<String>() ?? [];
    final notes = report['notes'] as String?;
    final reportDate = report['report_date'] as String? ?? '';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reportDate.isNotEmpty)
          Text(
            reportDate,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF5A8DA0),
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(moodIcons[moodLevel] ?? '😐',
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                moodLabels[moodLevel] ?? moodLevel,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF112D4E),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (symptoms.isNotEmpty) ...[
          Text(
            'Gejala:',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5A8DA0),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: symptoms
                .map((s) => Chip(
                      visualDensity: VisualDensity.compact,
                      labelStyle: GoogleFonts.manrope(
                          fontSize: 12, color: const Color(0xFF112D4E)),
                      backgroundColor: const Color(0xFFEAF2FF),
                      label: Text(s),
                    ))
                .toList(),
          ),
        ],
        if (emergencySymptoms.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '⚠️ Gejala Darurat:',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: emergencySymptoms
                .map((s) => Chip(
                      visualDensity: VisualDensity.compact,
                      labelStyle: GoogleFonts.manrope(
                          fontSize: 12, color: Colors.redAccent.shade700),
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      label: Text(s),
                    ))
                .toList(),
          ),
        ],
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              notes,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: const Color(0xFF43474E),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSymptomCard(Map<String, dynamic> symptom) {
    final nausea = symptom['nausea_level'] ?? 0;
    final dizziness = symptom['dizziness_level'] ?? 0;
    final fatigue = symptom['fatigue_level'] ?? 0;
    final hemoptysis = symptom['hemoptysis'] == true;
    final chestPain = symptom['chest_pain'] == true;
    final sob = symptom['shortness_of_breath'] == true;
    final logDate = symptom['log_date'] as String? ?? '';

    final symptoms = <String>[];
    if (nausea is int && nausea > 0) symptoms.add('Mual ($nausea/3)');
    if (dizziness is int && dizziness > 0) symptoms.add('Pusing ($dizziness/3)');
    if (fatigue is int && fatigue > 0) symptoms.add('Lelah ($fatigue/3)');
    if (hemoptysis) symptoms.add('Batuk Darah');
    if (chestPain) symptoms.add('Nyeri Dada');
    if (sob) symptoms.add('Sesak Nafas');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (logDate.isNotEmpty)
          Text(
            logDate.length > 10 ? logDate.substring(0, 10) : logDate,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF5A8DA0),
            ),
          ),
        const SizedBox(height: 8),
        if (symptoms.isEmpty)
          Text(
            'Tidak ada gejala',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: const Color(0xFF2E7D32),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: symptoms
                .map((s) => Chip(
                      visualDensity: VisualDensity.compact,
                      labelStyle: GoogleFonts.manrope(
                          fontSize: 12, color: const Color(0xFF112D4E)),
                      backgroundColor: const Color(0xFFEAF2FF),
                      label: Text(s),
                    ))
                .toList(),
          ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Shared section builder
  // ──────────────────────────────────────────────────────────────
  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            title,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: const Color(0xFF112D4E),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF5A8DA0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: const Color(0xFF112D4E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
