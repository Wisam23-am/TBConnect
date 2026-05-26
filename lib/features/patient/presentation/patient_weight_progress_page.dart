import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/auth_service.dart';
import '../../../services/patient_service.dart';
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
        limit: 20,
      );

      try {
        final profile =
            await _patientService.getPatientProfile(session.patientId);
        final initialWeight =
            (profile['initial_weight_kg'] as num?)?.toDouble();
        final startDate = profile['treatment_start_date'] as String?;

        if (initialWeight != null && startDate != null) {
          // Check if there's already a log for this exact date to prevent duplicates
          final exists = logs.any((l) => l['log_date'] == startDate);
          if (!exists) {
            logs.add({
              'weight_kg': initialWeight,
              'log_date': startDate,
              'is_initial': true,
            });
            // Re-sort descending
            logs.sort((a, b) =>
                (b['log_date'] as String).compareTo(a['log_date'] as String));
          }
        }
      } catch (e) {
        print('Gagal mengambil initial weight: $e');
      }

      if (logs.isNotEmpty) {
        setState(() {
          _weightLogs = logs;
          _currentWeek = _calculateWeekLabel(
              DateTime.tryParse(logs.first['log_date'] as String? ?? ''));
        });
      } else {
        setState(() {
          _weightLogs = [];
        });
      }
    } catch (e) {
      setState(() => _error = 'Gagal memuat riwayat: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        'Des'
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
        builder: (ctx) => PatientWeightInputPage(
          initialWeight: _weightLogs.isNotEmpty
              ? (_weightLogs.first['weight_kg'] as num?)?.toDouble()
              : null,
          previousWeightDate: _weightLogs.isNotEmpty
              ? DateTime.tryParse(
                  _weightLogs.first['log_date'] as String? ?? '')
              : null,
        ),
      ),
    );

    if (result != null && mounted) {
      _loadWeightHistory();
    } else {
      _loadWeightHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF3F5F9), // Lighter background for modern look
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF112D4E)))
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadWeightHistory,
                  color: const Color(0xFF112D4E),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      _buildSliverAppBar(),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildActionCard(),
                              const SizedBox(height: 32),
                              Text(
                                'Riwayat Berat Badan',
                                style: GoogleFonts.manrope(
                                  color: const Color(0xFF112D4E),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildWeightTimeline(),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
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
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
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
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.monitor_weight_outlined,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Progres Berat Badan',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pantau terus perkembangan fisik Anda',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A112D4E), blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JADWAL TIMBANG',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF5A8DA0),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentWeek ?? 'Minggu Ini',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF112D4E),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F0FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add_chart,
                    color: Color(0xFF3F72AF), size: 30),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToWeightInput,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF112D4E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Catat Berat Badan',
                    style: GoogleFonts.manrope(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightTimeline() {
    if (_weightLogs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE1E3E4)),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Belum ada riwayat berat badan',
              style: GoogleFonts.manrope(
                  color: const Color(0xFF5A8DA0),
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(_weightLogs.length, (i) {
        final log = _weightLogs[i];
        final weight = (log['weight_kg'] as num).toDouble();
        final date = log['log_date'] as String? ?? '';
        final isInitial = log['is_initial'] == true;

        // Calculate difference with previous entry (which is i+1 because sorted descending)
        double diff = 0;
        bool hasDiff = false;
        if (i < _weightLogs.length - 1) {
          final prevWeight =
              (_weightLogs[i + 1]['weight_kg'] as num).toDouble();
          diff = weight - prevWeight;
          hasDiff = true;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isInitial ? const Color(0xFFF9FAFB) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border:
                isInitial ? Border.all(color: const Color(0xFFE1E3E4)) : null,
            boxShadow: isInitial
                ? null
                : const [
                    BoxShadow(
                        color: Color(0x05112D4E),
                        blurRadius: 10,
                        offset: Offset(0, 2))
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isInitial
                            ? const Color(0xFFE1E3E4)
                            : const Color(0xFFF3F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                          isInitial ? Icons.flag_rounded : Icons.calendar_month,
                          color: isInitial
                              ? const Color(0xFF43474E)
                              : const Color(0xFF5A8DA0),
                          size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(date),
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF112D4E),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isInitial)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Berat Awal',
                                style: GoogleFonts.manrope(
                                  color: const Color(0xFF5A8DA0),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else if (hasDiff && diff != 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                diff > 0
                                    ? '+${diff.toStringAsFixed(1)} kg dari sblmnya'
                                    : '${diff.toStringAsFixed(1)} kg dari sblmnya',
                                style: GoogleFonts.manrope(
                                  color: diff > 0
                                      ? Colors.redAccent
                                      : const Color(0xFF2E7D32),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${weight.toStringAsFixed(1)} kg',
                style: GoogleFonts.manrope(
                  color: const Color(0xFF3F72AF),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
