import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/doctor_service.dart';
import '../../../widgets/doctor_bottom_nav_bar.dart';
import 'doctor_profile_page.dart';
import 'patient_qr_page.dart';

class CreatePatientScreen extends StatefulWidget {
  const CreatePatientScreen({super.key, this.embedded = false});

  /// When [embedded] is true, the page renders without its own [Scaffold]
  /// or [DoctorBottomNavBar] so it can be placed inside [DoctorMainShell].
  final bool embedded;

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
  bool _isSubmitting = false;

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

  void _handleNavTap(int index) {
    if (index == 1) return;
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DoctorProfilePage()),
      );
    } else {
      Navigator.pop(context); // Go back to Dasbor
    }
  }

  Future<void> _submitPatient() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_gender == null) {
      _showSnackBar('Pilih jenis kelamin terlebih dahulu', Colors.orange);
      return;
    }

    double? beratBadan = double.tryParse(_beratAwalController.text);
    if (beratBadan == null) {
      _showSnackBar('Format berat badan tidak valid', Colors.orange);
      return;
    }

    if (_tanggalLahirController.text.isEmpty) {
      _showSnackBar('Pilih tanggal lahir terlebih dahulu', Colors.orange);
      return;
    }
    if (_tanggalMasukController.text.isEmpty) {
      _showSnackBar('Pilih tanggal mulai perawatan', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final birthDate = DateTime.parse(_tanggalLahirController.text);
      final startDate = DateTime.parse(_tanggalMasukController.text);

      final doctorService = DoctorService();
      final response = await doctorService.addPatient(
        nik: _nikController.text.trim(),
        fullName: _namaController.text.trim(),
        birthPlace: _tempatLahirController.text.trim(),
        birthDate: birthDate,
        gender: _gender!,
        initialWeightKg: beratBadan,
        treatmentStartDate: startDate,
        phoneNumber:
            _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address:
            _alamatController.text.trim().isEmpty ? null : _alamatController.text.trim(),
        faskesName:
            _faskesController.text.trim().isEmpty ? null : _faskesController.text.trim(),
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
        _showSnackBar('Gagal menambahkan pasien: $e', Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickDate(TextEditingController controller,
      {DateTime? initialDate, DateTime? firstDate, DateTime? lastDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(1900),
      lastDate: lastDate ?? DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF112D4E),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      controller.text = formatted;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWide = screenWidth > 600;
    final isSmall = screenWidth < 360;
    // Dynamic horizontal padding: more on wide screens, less on small
    final horizontalPadding = isWide ? 48.0 : (isSmall ? 16.0 : 24.0);
    // Bottom padding accounts for bottom nav bar
    final bottomPadding = screenHeight * 0.15;

    final formBody = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header description ──
          Text(
            'Lengkapi data pasien',
            style: GoogleFonts.manrope(
              color: const Color(0xFF001833),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Isi formulir di bawah untuk mendaftarkan pasien TB baru ke dalam sistem.',
            style: GoogleFonts.manrope(
              color: const Color(0xFF5A8DA0),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.50,
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 1: Identitas Pribadi ──
          _FormSectionCard(
            icon: Icons.person_outline_rounded,
            title: 'Identitas Pribadi',
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildFormField(
                    controller: _nikController,
                    label: 'Nomor NIK',
                    hintText: '16 digit nomor induk kependudukan',
                    keyboardType: TextInputType.number,
                    maxLength: 16,
                  ),
                  const SizedBox(height: 18),
                  _buildFormField(
                    controller: _namaController,
                    label: 'Nama Lengkap',
                    hintText: 'Masukkan nama lengkap pasien',
                  ),
                  const SizedBox(height: 18),
                  _buildFormField(
                    controller: _tempatLahirController,
                    label: 'Tempat Lahir',
                    hintText: 'Contoh: Jakarta',
                  ),
                  const SizedBox(height: 18),
                  _buildFormField(
                    controller: _tanggalLahirController,
                    label: 'Tanggal Lahir',
                    hintText: 'Pilih tanggal lahir',
                    readOnly: true,
                    suffixIcon: const Icon(Icons.calendar_month_rounded,
                        size: 20, color: Color(0xFF112D4E)),
                    onTap: () => _pickDate(
                      _tanggalLahirController,
                      initialDate: DateTime(1990),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Gender selector
                  _buildGenderSelector(),
                  const SizedBox(height: 18),
                  _buildFormField(
                    controller: _phoneController,
                    label: 'Nomor Handphone',
                    hintText: 'Contoh: 08123456789',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 18),
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
          const SizedBox(height: 20),

          // ── Section 2: Data Medis & Pengobatan ──
          _FormSectionCard(
            icon: Icons.medical_services_outlined,
            title: 'Data Medis & Pengobatan',
            child: Column(
              children: [
                _buildFormField(
                  controller: _faskesController,
                  label: 'Nama Rumah Sakit / Faskes',
                  hintText: 'Nama fasilitas kesehatan terdaftar',
                ),
                const SizedBox(height: 18),
                _buildFormField(
                  controller: _tanggalMasukController,
                  label: 'Tanggal Mulai Perawatan',
                  hintText: 'Pilih tanggal mulai',
                  readOnly: true,
                  suffixIcon: const Icon(Icons.calendar_month_rounded,
                      size: 20, color: Color(0xFF112D4E)),
                  onTap: () => _pickDate(
                    _tanggalMasukController,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  ),
                ),
                const SizedBox(height: 18),
                _buildFormField(
                  controller: _beratAwalController,
                  label: 'Berat Badan Awal (kg)',
                  hintText: 'Misal: 55.5',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  suffixIcon: const Icon(Icons.monitor_weight_rounded,
                      size: 20, color: Color(0xFF112D4E)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Submit Button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitPatient,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001833),
                disabledBackgroundColor: const Color(0xFFCED4DB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_rounded, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Simpan & Buat Kode QR',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.60,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Data pasien akan tersimpan dan menghasilkan kode QR untuk aktivasi akun.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: const Color(0xFF9CA3AF),
                height: 1.50,
              ),
            ),
          ),
        ],
      ),
    );

    // When embedded in DoctorMainShell, return just the form body
    if (widget.embedded) return formBody;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF112D4E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE5F0FF),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded,
                  color: Color(0xFF112D4E), size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Tambah Pasien',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF112D4E),
                        )),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Registrasi pasien TB baru',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: const Color(0xFF5A8DA0),
                        )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Wrap body in SafeArea for devices with notches
      body: SafeArea(child: formBody),
      bottomNavigationBar: DoctorBottomNavBar(
        currentIndex: 1,
        onTap: _handleNavTap,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Gender Selector – ToggleButtons style
  // ─────────────────────────────────────────────────────────────

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Jenis Kelamin',
            style: GoogleFonts.manrope(
              color: const Color(0xFF191C1D),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.60,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _GenderChip(
                icon: Icons.male_rounded,
                label: 'Laki-laki',
                value: 'male',
                selected: _gender == 'male',
                onSelected: () => setState(() => _gender = 'male'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GenderChip(
                icon: Icons.female_rounded,
                label: 'Perempuan',
                value: 'female',
                selected: _gender == 'female',
                onSelected: () => setState(() => _gender = 'female'),
              ),
            ),
          ],
        ),
        if (_gender == null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              'Pilih jenis kelamin',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: Colors.redAccent,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Form Field
  // ─────────────────────────────────────────────────────────────

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
            color: const Color(0xFF001833),
            fontSize: 13,
            fontWeight: FontWeight.w600,
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
            color: const Color(0xFF001833),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.40,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.manrope(
              color: const Color(0xFF9CA3AF),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: suffixIcon,
                  )
                : null,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF112D4E), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Colors.redAccent, width: 1.5),
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

// =============================================================================
// Reusable Widgets
// =============================================================================

/// Card container for a form section with an icon header.
class _FormSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _FormSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F0FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF112D4E), size: 18),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF112D4E),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

/// A selectable gender chip (male / female).
class _GenderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  const _GenderChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF112D4E)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF112D4E)
                : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        // FittedBox scales the entire row (icon + text) down proportionally
        // when it exceeds the chip width, preventing "Perempuan" from
        // overflowing or being truncated with ellipsis on narrow screens.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.manrope(
                  color: selected
                      ? Colors.white
                      : const Color(0xFF001833),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
