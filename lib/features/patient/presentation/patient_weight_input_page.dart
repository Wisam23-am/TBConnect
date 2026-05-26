import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/auth_service.dart';
import '../../../services/patient_service.dart';
import 'patient_shell.dart';
import '../../../widgets/weight_submit_success_dialog.dart';

class PatientWeightInputPage extends StatefulWidget {
  final double? initialWeight;
  final DateTime? previousWeightDate;

  const PatientWeightInputPage({
    super.key,
    this.initialWeight,
    this.previousWeightDate,
  });

  @override
  State<PatientWeightInputPage> createState() => _PatientWeightInputPageState();
}

class _PatientWeightInputPageState extends State<PatientWeightInputPage> {
  final _weightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _patientService = PatientDataService();

  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _canSubmitWeight = true;
  double? _previousWeight;
  DateTime? _previousWeightDate;
  DateTime? _nextAllowedWeightDate;
  List<Map<String, dynamic>> _weightHistory = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _previousWeight = widget.initialWeight;
    _previousWeightDate = widget.previousWeightDate;
    _syncWeeklySubmissionLimit(_previousWeightDate);
    _loadPreviousWeight();
  }

  Future<void> _loadPreviousWeight() async {
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);
      final session = await _authService.getPatientSession();
      if (session != null) {
        final weightHistory = await _patientService.getWeightHistory(
          patientId: session.patientId,
          limit: 8,
        );

        if (weightHistory.isNotEmpty) {
          final latest = weightHistory.first;
          final latestDate = latest['log_date'] != null
              ? DateTime.tryParse(latest['log_date'] as String)
              : null;
          setState(() {
            _weightHistory = weightHistory;
            _previousWeight = (latest['weight_kg'] as num?)?.toDouble();
            _previousWeightDate = latestDate;
            _syncWeeklySubmissionLimit(latestDate);
          });
        } else {
          setState(() {
            _canSubmitWeight = true;
            _nextAllowedWeightDate = null;
          });
        }
      }
    } catch (e) {
      setState(() => _error = 'Gagal memuat riwayat berat badan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncWeeklySubmissionLimit(DateTime? latestDate) {
    if (latestDate == null) {
      _canSubmitWeight = true;
      _nextAllowedWeightDate = null;
      return;
    }

    final now = DateTime.now();
    final latestWeekStart = _startOfWeek(latestDate);
    final currentWeekStart = _startOfWeek(now);

    final isSameWeek = latestWeekStart.year == currentWeekStart.year &&
        latestWeekStart.month == currentWeekStart.month &&
        latestWeekStart.day == currentWeekStart.day;

    if (isSameWeek) {
      _canSubmitWeight = false;
      _nextAllowedWeightDate = currentWeekStart.add(const Duration(days: 7));
    } else {
      _canSubmitWeight = true;
      _nextAllowedWeightDate = null;
    }
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  String _formatLongDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _handleSubmitWeight() async {
    if (!_canSubmitWeight) return;
    await _submitWeight();
  }

  Future<void> _submitWeight() async {
    if (!_formKey.currentState!.validate()) return;

    final weight = double.parse(_weightController.text.trim());
    final session = await _authService.getPatientSession();

    if (session == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesi login tidak valid')));
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      await _patientService.logWeight(
        patientId: session.patientId,
        weightKg: weight,
      );

      final now = DateTime.now();
      setState(() {
        _previousWeight = weight;
        _previousWeightDate = now;
        _weightHistory = [
          {'weight_kg': weight, 'log_date': now.toIso8601String().split('T').first},
          ..._weightHistory,
        ];
        _syncWeeklySubmissionLimit(now);
      });

      if (mounted) {
        await WeightSubmitSuccessDialog.show(context);
        if (mounted) {
          Navigator.pop(context, weight);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF112D4E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Catat Berat Badan',
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        // Circular icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                          ),
                          child: const Icon(Icons.monitor_weight_outlined, color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Berapa berat badan\nAnda hari ini?',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Form input
                        Form(
                          key: _formKey,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 32),
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: _canSubmitWeight ? Colors.white.withOpacity(0.08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _canSubmitWeight ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                                width: 1.5,
                              ),
                              boxShadow: _canSubmitWeight
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _weightController,
                                  enabled: _canSubmitWeight,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w800,
                                    color: _canSubmitWeight ? Colors.white : Colors.white.withOpacity(0.4),
                                    letterSpacing: -2.0,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0.0',
                                    hintStyle: GoogleFonts.manrope(
                                      fontSize: 64,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                    border: InputBorder.none,
                                    suffixText: 'kg',
                                    suffixStyle: GoogleFonts.manrope(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: _canSubmitWeight ? Colors.white70 : Colors.white30,
                                    ),
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Wajib diisi';
                                    final weight = double.tryParse(value.trim());
                                    if (weight == null) return 'Format salah';
                                    if (weight <= 0 || weight > 300) return 'Tidak wajar';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 48),

                        if (!_canSubmitWeight && _nextAllowedWeightDate != null)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_clock_rounded, color: Colors.orangeAccent, size: 32),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Terjadwal Minggu Depan',
                                        style: GoogleFonts.manrope(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Anda sudah mengisi minggu ini. Tunggu hari Senin, ${_formatLongDate(_nextAllowedWeightDate!)}.',
                                        style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                        const SizedBox(height: 48), // Padding bawah agar tidak mepet dengan tombol
                      ],
                    ),
                  ),
                ),
                
                // Bottom Button Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_previousWeight != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.history, color: Color(0xFF5A8DA0), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Berat sebelumnya: ${_previousWeight!.toStringAsFixed(1)} kg',
                                  style: GoogleFonts.manrope(
                                    color: const Color(0xFF5A8DA0),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ElevatedButton(
                          onPressed: (_isSubmitting || !_canSubmitWeight) ? null : _handleSubmitWeight,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF112D4E),
                            disabledBackgroundColor: const Color(0xFFCED4DB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 8,
                            shadowColor: const Color(0xFF112D4E).withOpacity(0.5),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : Text(
                                  'Simpan Sekarang',
                                  style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
