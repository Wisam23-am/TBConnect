import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/patient_bottom_nav_bar.dart';
import 'patient_home_page.dart';
import 'patient_symptoms_page.dart';
import 'patient_weight_input_page.dart';

class PatientWeightProgressPage extends StatefulWidget {
  const PatientWeightProgressPage({super.key});

  @override
  State<PatientWeightProgressPage> createState() =>
      _PatientWeightProgressPageState();
}

class _PatientWeightProgressPageState extends State<PatientWeightProgressPage> {
  final _authService = AuthService();
  final _patientService = PatientDataService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _weightLogs = [];
  String? _currentWeek;
  String? _error;
  int _selectedNavIndex = 2; // Berat tab

  @override
  void initState() {
    super.initState();
    _loadWeightHistory();
  }

  Future<void> _loadWeightHistory() async {
    try {
      setState(() => _isLoading = true);

      final session = await _authService.getPatientSession();
      if (session == null) {
        setState(() => _error = 'Session not found');
        return;
      }

      final logs = await _patientService.getWeightHistory(
        patientId: session.patientId,
        limit: 20, // Get more to calculate weeks
      );

      if (logs.isNotEmpty) {
        setState(() {
          _weightLogs = logs;
          _currentWeek = _calculateWeekLabel(
              DateTime.tryParse(logs.first['recorded_at'] as String? ?? ''));
        });
      }
    } catch (e) {
      setState(() => _error = 'Gagal memuat riwayat: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _calculateWeekLabel(DateTime? date) {
    if (date == null) return 'Minggu Ini';
    final now = DateTime.now();
    final daysDiff = now.difference(date).inDays;

    if (daysDiff == 0) {
      return 'Minggu Ini';
    } else if (daysDiff <= 7) {
      return 'Minggu Lalu';
    } else if (daysDiff <= 14) {
      return '2 Minggu Lalu';
    } else if (daysDiff <= 21) {
      return '3 Minggu Lalu';
    } else {
      return '4+ Minggu Lalu';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
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
        'Des',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  void _navigateToWeightInput() async {
    final result = await Navigator.push<double>(
      context,
      MaterialPageRoute(
        builder: (ctx) => const PatientWeightInputPage(),
      ),
    );

    if (result != null && mounted) {
      _loadWeightHistory();
    }
  }

  void _handleBottomNavTap(int index) {
    if (index == _selectedNavIndex) return;

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PatientHomePage(
            initialNavIndex: 3,
            allowGuestMode: true,
          ),
        ),
      );
      return;
    }

    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PatientSymptomsPage()),
      );
      return;
    }

    setState(() => _selectedNavIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF001833),
            size: 24,
          ),
        ),
        title: Text(
          'Progres Berat Badan',
          style: GoogleFonts.manrope(
            color: const Color(0xFF001833),
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.22,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF112D4E)),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(fontSize: 14)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadWeightHistory,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWeightHistory,
                  color: const Color(0xFF112D4E),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─────────────────────────────────────────────────
                        // Weight Schedule Card
                        // ─────────────────────────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
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
                              Text(
                                'JADWAL TIMBANG',
                                style: GoogleFonts.manrope(
                                  color: const Color(0xFF43474E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.60,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentWeek ?? 'Minggu Ini',
                                        style: GoogleFonts.manrope(
                                          color: const Color(0xFF001833),
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.24,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today,
                                              size: 16,
                                              color: Color(0xFF43474E)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Tanggal: Hari Ini',
                                            style: GoogleFonts.manrope(
                                              color: const Color(0xFF43474E),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4E3FF),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Icon(
                                      Icons.monitor_weight_outlined,
                                      color: Color(0xFF2A609C),
                                      size: 28,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _navigateToWeightInput,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2A609C),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Catat Berat Minggu Ini',
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ─────────────────────────────────────────────────
                        // Weight Log History
                        // ─────────────────────────────────────────────────
                        Text(
                          'Log Berat Badan',
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF001833),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.18,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_weightLogs.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                Icon(Icons.inbox_rounded,
                                    size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  'Belum ada catatan berat badan',
                                  style: GoogleFonts.manrope(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: List.generate(_weightLogs.length, (i) {
                              final log = _weightLogs[i];
                              final weight =
                                  (log['weight_kg'] as num).toDouble();
                              final date = log['recorded_at'] as String? ?? '';

                              return Container(
                                margin: EdgeInsets.only(
                                  bottom: i < _weightLogs.length - 1 ? 12 : 0,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: const Color(0xFFE1E3E4),
                                      width: i < _weightLogs.length - 1 ? 1 : 0,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDate(date),
                                      style: GoogleFonts.manrope(
                                        color: const Color(0xFF43474E),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${weight.toStringAsFixed(1)} kg',
                                      style: GoogleFonts.manrope(
                                        color: const Color(0xFF2A609C),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),

                        const SizedBox(height: 24),

                        // ─────────────────────────────────────────────────
                        // Footer note
                        // ─────────────────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Mencatat berat badan secara rutin membantu tenaga medis memantau efektivitas pengobatan Anda.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: PatientBottomNavBar(
        currentIndex: _selectedNavIndex,
        onTap: _handleBottomNavTap,
      ),
    );
  }
}
