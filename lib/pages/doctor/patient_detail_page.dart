import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tbconnect/services/auth_service.dart';

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
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildInfoSection('Informasi Pasien', [
                      _infoRow('Nama', _patientData!['full_name'] ?? '-'),
                      _infoRow('Umur', '${_patientData!['age'] ?? '-'} tahun'),
                      _infoRow('Gender', _patientData!['gender'] == 'male' ? 'Laki-laki' : 'Perempuan'),
                      _infoRow('NIK', _patientData!['nik'] ?? '-'),
                      _infoRow('QR Code', _patientData!['qr_code'] ?? '-'),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoSection('Data Pengobatan', [
                      _infoRow('Berat Awal', '${_patientData!['initial_weight_kg'] ?? '-'} kg'),
                      _infoRow('Mulai Berobat', _patientData!['treatment_start_date'] ?? '-'),
                      _infoRow('Status', _patientData!['status'] ?? '-'),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoSection('Klinis', [
                      _infoRow('Faskes', _patientData!['faskes_name'] ?? '-'),
                      _infoRow('Alamat', _patientData!['address'] ?? '-'),
                      _infoRow('No. Telepon', _patientData!['phone_number'] ?? '-'),
                    ]),
                  ],
                ),
    );
  }

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
