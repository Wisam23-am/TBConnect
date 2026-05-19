import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/auth_service.dart';
import '../../../services/patient_service.dart';
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
  double? _previousWeight;
  DateTime? _previousWeightDate;
  List<Map<String, dynamic>> _weightHistory = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _previousWeight = widget.initialWeight;
    _previousWeightDate = widget.previousWeightDate;
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
          setState(() {
            _weightHistory = weightHistory;
            _previousWeight = (latest['weight_kg'] as num?)?.toDouble();
            _previousWeightDate = latest['log_date'] != null
                ? DateTime.tryParse(latest['log_date'] as String)
                : null;
          });
        }
      }
    } catch (e) {
      setState(() => _error = 'Gagal memuat riwayat berat badan: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitWeight() async {
    if (!_formKey.currentState!.validate()) return;

    final weight = double.parse(_weightController.text.trim());
    final session = await _authService.getPatientSession();

    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesi login tidak valid'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      await _patientService.logWeight(
        patientId: session.patientId,
        weightKg: weight,
      );

      if (mounted) {
        await WeightSubmitSuccessDialog.show(context);
        if (mounted) {
          Navigator.pop(context, weight);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime dt) {
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final weight = (item['weight_kg'] as num?)?.toDouble();
    final date = item['log_date'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E3E4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.monitor_weight_rounded,
              color: Color(0xFF112D4E),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BERAT SEBELUMNYA',
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF43474E),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${weight?.toStringAsFixed(1) ?? '-'} kg${date != null ? '  (${_formatDate(DateTime.parse(date))})' : ''}',
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF001833),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF001833),
            size: 24,
          ),
        ),
        title: Text(
          'Input Berat Badan',
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // ─────────────────────────────────────────────────────────
                  // Description
                  // ─────────────────────────────────────────────────────────
                  Text(
                    'Catat berat badan Anda untuk memantau kemajuan pemulihan.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF43474E),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ─────────────────────────────────────────────────────────
                  // Input Form
                  // ─────────────────────────────────────────────────────────
                  Form(
                    key: _formKey,
                    child: Container(
                      padding: const EdgeInsets.all(32),
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
                        children: [
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: false,
                            ),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 48,
                              fontWeight: FontWeight.w300,
                              color: const Color(0xFFB0B7C6),
                              letterSpacing: -0.48,
                            ),
                            decoration: InputDecoration(
                              hintText: '00.0',
                              hintStyle: GoogleFonts.manrope(
                                fontSize: 48,
                                fontWeight: FontWeight.w300,
                                color: const Color(0xFFD5D8DD),
                                letterSpacing: -0.48,
                              ),
                              border: InputBorder.none,
                              suffixText: 'kg',
                              suffixStyle: GoogleFonts.manrope(
                                fontSize: 28,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF001833),
                                letterSpacing: -0.28,
                              ),
                              contentPadding: const EdgeInsets.only(bottom: 8),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Berat badan wajib diisi';
                              }
                              final weight = double.tryParse(value.trim());
                              if (weight == null) {
                                return 'Format angka tidak valid';
                              }
                              if (weight <= 0) {
                                return 'Berat badan harus lebih dari 0';
                              }
                              if (weight > 200) {
                                return 'Berat badan tidak wajar';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 1,
                            color: const Color(0xFFE1E3E4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─────────────────────────────────────────────────────────
                  // Previous weight card
                  // ─────────────────────────────────────────────────────────
                  if (_previousWeight != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE1E3E4)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0C000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EEF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              color: Color(0xFF112D4E),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BERAT SEBELUMNYA',
                                  style: GoogleFonts.manrope(
                                    color: const Color(0xFF43474E),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_previousWeight!.toStringAsFixed(1)} kg${_previousWeightDate != null ? '  (${_formatDate(_previousWeightDate!)})' : ''}',
                                  style: GoogleFonts.manrope(
                                    color: const Color(0xFF001833),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Text(
                    'Riwayat Berat Badan',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF001833),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_weightHistory.isNotEmpty)
                    Column(
                      children: [
                        for (final item in _weightHistory) ...[
                          _buildHistoryItem(item),
                          const SizedBox(height: 10),
                        ],
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE1E3E4)),
                      ),
                      child: Text(
                        'Belum ada history berat badan sebelumnya.',
                        style: GoogleFonts.manrope(
                          color: const Color(0xFF43474E),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ─────────────────────────────────────────────────────────
                  // Submit button
                  // ─────────────────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitWeight,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF001833),
                        disabledBackgroundColor: const Color(0xFFCED4DB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Simpan Berat Badan',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.60,
                              ),
                            ),
                    ),
                  ),

                  // Error message (jika ada)
                  if (_error != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF5350)),
                      ),
                      child: Text(
                        _error!,
                        style: GoogleFonts.manrope(
                          color: const Color(0xFFC62828),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
