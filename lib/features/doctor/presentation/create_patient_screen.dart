import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/auth_service.dart';
import '../../../pages/doctor/patient_qr_page.dart';

class CreatePatientScreen extends StatefulWidget {
  const CreatePatientScreen({super.key});

  @override
  State<CreatePatientScreen> createState() => _CreatePatientScreenState();
}

class _CreatePatientScreenState extends State<CreatePatientScreen> {
  final _formKey = GlobalKey<FormState>();

  final _namaController = TextEditingController();
  final _tempatLahirController = TextEditingController();
  final _tanggalLahirController = TextEditingController();
  final _nikController = TextEditingController();
  final _alamatController = TextEditingController();
  final _phoneController = TextEditingController();
  final _faskesController = TextEditingController();
  final _tanggalMasukController = TextEditingController();
  final _beratAwalController = TextEditingController();
  
  String? _gender;
  bool _isLoading = false;

  int _selectedIndex = 1; // 1 for Register based on the mockup

  @override
  void dispose() {
    _namaController.dispose();
    _tempatLahirController.dispose();
    _tanggalLahirController.dispose();
    _nikController.dispose();
    _alamatController.dispose();
    _phoneController.dispose();
    _faskesController.dispose();
    _tanggalMasukController.dispose();
    _beratAwalController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Handle navigation here
  }

  Future<void> _submitPatient() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jenis kelamin terlebih dahulu')),
      );
      return;
    }
    
    double? beratBadan = double.tryParse(_beratAwalController.text);
    if (beratBadan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format berat badan salah')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Parse dates safely
      final birthDate = DateTime.parse(_tanggalLahirController.text);
      final startDate = DateTime.parse(_tanggalMasukController.text);

      final doctorService = DoctorService(); // Use DoctorService
      final response = await doctorService.addPatient(
        nik: _nikController.text.trim(),
        fullName: _namaController.text.trim(),
        birthPlace: _tempatLahirController.text.trim(),
        birthDate: birthDate,
        gender: _gender!,
        initialWeightKg: beratBadan,
        treatmentStartDate: startDate,
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _alamatController.text.trim().isEmpty ? null : _alamatController.text.trim(),
        faskesName: _faskesController.text.trim().isEmpty ? null : _faskesController.text.trim(),
      );

      if (mounted) {
        // Navigasi ke halaman QR dengan data yang baru dibuat
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
            content: Text('Gagal menambahkan pasien: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                    Text(
                      'Identitas Pribadi',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF112D4E),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: _nikController,
                      label: 'Nomor NIK',
                      hintText: '16 digit nomor induk kependudukan',
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: _namaController,
                      label: 'Nama Lengkap',
                      hintText: 'Masukkan nama lengkap pasien',
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: _tempatLahirController,
                      label: 'Tempat Lahir',
                      hintText: 'Contoh: Jakarta',
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: _tanggalLahirController,
                      label: 'Tanggal Lahir',
                      hintText: 'Pilih tanggal',
                      keyboardType: TextInputType.datetime,
                      suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF6B7280)),
                      readOnly: true,
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime(1990),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null) {
                          String formattedDate = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                          setState(() {
                            _tanggalLahirController.text = formattedDate;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jenis Kelamin',
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF191C1D),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.60,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _gender,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                          ),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('Laki-laki')),
                            DropdownMenuItem(value: 'female', child: Text('Perempuan')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _gender = value;
                            });
                          },
                          validator: (value) => value == null ? 'Pilih jenis kelamin' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: _phoneController,
                      label: 'Nomor Handphone',
                      hintText: 'Contoh: 08123456789',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: _alamatController,
                      label: 'Alamat Lengkap',
                      hintText: 'Masukkan alamat tempat tinggal saat ini',
                      maxLines: 3,
                    ),
                  ],
                ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Medis & Pengobatan',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF112D4E),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: _faskesController,
                    label: 'Nama Rumah Sakit / Faskes',
                    hintText: 'Nama fasilitas kesehatan terdaftar',
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: _tanggalMasukController,
                    label: 'Tanggal Mulai Perawatan',
                    hintText: 'Pilih tanggal',
                    keyboardType: TextInputType.datetime,
                    suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF6B7280)),
                    readOnly: true,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (pickedDate != null) {
                        String formattedDate = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                        setState(() {
                          _tanggalMasukController.text = formattedDate;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: _beratAwalController,
                    label: 'Berat Badan Awal (kg)',
                    hintText: 'Misal: 55.5',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
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
            const SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x0A112D4E),
              blurRadius: 20,
              offset: Offset(0, -4),
            )
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF112D4E),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          onTap: _onItemTapped,
          items: [
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(Icons.people_outline, color: _selectedIndex == 0 ? const Color(0xFF112D4E) : const Color(0xFF94A3B8)),
              ),
              label: 'Patients',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: _selectedIndex == 1 ? const Color(0xFFEFF6FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.person_add_alt_1_outlined, color: _selectedIndex == 1 ? const Color(0xFF112D4E) : const Color(0xFF94A3B8)),
              ),
              label: 'Register',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(Icons.bar_chart_outlined, color: _selectedIndex == 2 ? const Color(0xFF112D4E) : const Color(0xFF94A3B8)),
              ),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(Icons.person_outline, color: _selectedIndex == 3 ? const Color(0xFF112D4E) : const Color(0xFF94A3B8)),
              ),
              label: 'Account',
            ),
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
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label wajib diisi';
            }
            if (label == 'Nomor NIK' && value.length != 16) {
              return 'NIK harus 16 digit';
            }
            return null;
          },
        ),
      ],
    );
  }
}
