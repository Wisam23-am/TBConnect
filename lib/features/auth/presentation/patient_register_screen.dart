import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/auth_service.dart';
import 'patient_login_screen.dart';

class PatientRegisterScreen extends StatefulWidget {
  const PatientRegisterScreen({super.key, this.qrCode = ''});

  final String qrCode;

  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends State<PatientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _qrCodeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _qrCodeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_qrCodeController.text.isEmpty && widget.qrCode.isNotEmpty) {
      _qrCodeController.text = widget.qrCode;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Account Setup')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Verifikasi Data Pasien',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF001833),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Silakan periksa kembali data klinis Anda dan buat akun untuk mengakses sistem monitoring.',
                    style: TextStyle(
                      color: Color(0xFF43474E),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SectionCard(
                    icon: Icons.medical_information_rounded,
                    title: 'Data Klinis',
                    child: const Column(
                      children: [
                        _DataTile(
                            label: 'NIK',
                            value: '3174012345678901'),
                        _DataTile(
                            label: 'Nama Lengkap',
                            value: 'Budi Santoso'),
                        _DataTile(
                            label: 'Tempat, Tgl Lahir',
                            value: 'Jakarta, 15 Agustus 1985'),
                        _DataTile(
                          label: 'Alamat',
                          value: 'Jl. Kebon Jeruk Raya No. 12, Jakarta Barat',
                        ),
                        _DataTile(
                          label: 'Faskes',
                          value: 'RSUD Kebon Jeruk',
                        ),
                        _DataTile(
                          label: 'Tanggal Mulai Perawatan',
                          value: '01 Oktober 2023',
                        ),
                        _DataTile(
                          label: 'Berat Badan Awal',
                          value: '55.5 kg',
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    icon: Icons.lock_rounded,
                    title: 'Keamanan Akun',
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _qrCodeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Kode Aktivasi / QR Code',
                              hintText: 'Contoh: TBC-8AB3F',
                              prefixIcon: Icon(Icons.qr_code_rounded),
                            ),
                            validator: _required('Kode aktivasi wajib diisi'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Buat Username',
                              hintText: 'Masukkan username pilihan Anda',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: _required('Username wajib diisi'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Buat Kata Sandi',
                              hintText: 'Minimal 8 karakter',
                              prefixIcon: Icon(Icons.key_rounded),
                            ),
                            validator: _required('Password wajib diisi'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Konfirmasi Kata Sandi',
                              hintText: 'Ulangi kata sandi Anda',
                              prefixIcon: Icon(Icons.key_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Konfirmasi wajib diisi';
                              }
                              if (value != _passwordController.text) {
                                return 'Password tidak sama';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 220,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('SIMPAN & LANJUTKAN'),
                      ),
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

  String? Function(String?) _required(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    _authService
        .activatePatient(
      qrCode: _qrCodeController.text.trim().toUpperCase(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    )
        .then((result) {
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Akun pasien berhasil diaktifkan. Silakan login.',
              style: GoogleFonts.manrope(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF2E8B57),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const PatientLoginScreen(),
          ),
          (route) => route.isFirst,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['error'] ?? 'Aktivasi gagal',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }).catchError((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceAll('Exception: ', ''),
            style: GoogleFonts.manrope(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }).whenComplete(() {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E3E4)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 24, 51, 0.04),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2A609C)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF001833),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DataTile extends StatelessWidget {
  const _DataTile({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFF3F4F5)))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: Color(0xFF43474E),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191C1D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
