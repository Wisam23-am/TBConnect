import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import 'patient_qr_page.dart';

class AddPatientPage extends StatefulWidget {
  const AddPatientPage({super.key});

  @override
  State<AddPatientPage> createState() => _AddPatientPageState();
}

class _AddPatientPageState extends State<AddPatientPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _doctorService = DoctorService();

  String _selectedGender = 'male';
  DateTime _treatmentStartDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _treatmentStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF001833)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _treatmentStartDate = picked);
  }

  Future<void> _submitPatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await _doctorService.addPatient(
        fullName: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        gender: _selectedGender,
        initialWeightKg: double.parse(_weightController.text.trim()),
        treatmentStartDate: _treatmentStartDate,
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PatientQRPage(
              patientName: response['full_name'],
              qrCode: response['qr_code'],
              isActivated: false,
              fromAddPatient: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambahkan pasien: $e', style: GoogleFonts.manrope(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA),
            border: Border(
              bottom: BorderSide(
                width: 1,
                color: Color(0xFFDBE2EF),
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF112D4E)),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Patient Management',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF112D4E),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.40,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC4C6CF)),
                    image: const DecorationImage(
                      image: NetworkImage("https://placehold.co/30x30"),
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registrasi Baru',
              style: GoogleFonts.manrope(
                color: const Color(0xFF191C1D),
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Silakan lengkapi formulir di bawah ini untuk\nmendaftarkan pasien TB baru ke dalam sistem.',
              style: GoogleFonts.manrope(
                color: const Color(0xFF43474E),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x4CC4C6CF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A001833),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormField(
                      controller: _nameController,
                      label: 'Nama Lengkap *',
                      hintText: 'Masukkan nama lengkap pasien',
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildFormField(
                            controller: _ageController,
                            label: 'Usia *',
                            hintText: 'Tahun',
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                              final age = int.tryParse(v);
                              if (age == null || age <= 0 || age >= 150) return 'Usia tidak valid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jenis Kelamin *',
                                style: GoogleFonts.manrope(
                                  color: const Color(0xFF191C1D),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.60,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedGender = 'male'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          color: _selectedGender == 'male' ? const Color(0xFF001833) : const Color(0xFFF8F9FA),
                                          border: Border.all(
                                            color: _selectedGender == 'male' ? const Color(0xFF001833) : const Color(0xFFC4C6CF),
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Laki-laki',
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: _selectedGender == 'male' ? FontWeight.w700 : FontWeight.w400,
                                              color: _selectedGender == 'male' ? Colors.white : const Color(0xFF191C1D),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedGender = 'female'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          color: _selectedGender == 'female' ? const Color(0xFF001833) : const Color(0xFFF8F9FA),
                                          border: Border.all(
                                            color: _selectedGender == 'female' ? const Color(0xFF001833) : const Color(0xFFC4C6CF),
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Perempuan',
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: _selectedGender == 'female' ? FontWeight.w700 : FontWeight.w400,
                                              color: _selectedGender == 'female' ? Colors.white : const Color(0xFF191C1D),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: _phoneController,
                      label: 'Nomor HP',
                      hintText: 'Opsional',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: _addressController,
                      label: 'Alamat',
                      hintText: 'Opsional',
                      maxLines: 3,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(color: Color(0xFFE1E3E4), height: 1),
                    ),
                    _buildFormField(
                      controller: _weightController,
                      label: 'Berat Badan Awal (kg) *',
                      hintText: 'Contoh: 58.5',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Berat badan wajib diisi';
                        final w = double.tryParse(v);
                        if (w == null || w <= 0) return 'Berat tidak valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tanggal Mulai Pengobatan *',
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF191C1D),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.60,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFC4C6CF), width: 2),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  DateFormat('dd/MM/yyyy').format(_treatmentStartDate),
                                  style: GoogleFonts.manrope(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF191C1D),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF6B7280)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPatient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF001833),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0x26001833),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        'Simpan & Buat Kode QR',
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
    Widget? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            color: const Color(0xFF191C1D),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.60,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          style: GoogleFonts.manrope(
            color: const Color(0xFF191C1D),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.manrope(
              color: const Color(0xFF6B7280),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: suffixIcon,
            counterText: "", // Hide character counter for maxLength
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFC4C6CF), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFC4C6CF), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF001833), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
