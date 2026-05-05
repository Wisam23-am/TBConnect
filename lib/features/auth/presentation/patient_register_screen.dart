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

  Map<String, dynamic>? _patientData;
  String? _fetchError;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    if (widget.qrCode.isNotEmpty) {
      _qrCodeController.text = widget.qrCode;
      _fetchPatientData(widget.qrCode);
    }
  }

  Future<void> _fetchPatientData(String qrCode) async {
    if (qrCode.trim().isEmpty) return;
    setState(() {
      _isFetching = true;
      _fetchError = null;
      _patientData = null;
    });

    try {
      final data = await _authService.getPatientByQr(qrCode.trim().toUpperCase());
      if (mounted) {
        if (data['success'] == true) {
          setState(() {
            _patientData = data;
          });
        } else {
          setState(() {
            _fetchError = data['error'] ?? 'Data tidak ditemukan';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchError = 'Gagal memuat data: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

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
                    child: _isFetching
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _fetchError != null
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  _fetchError!,
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                              )
                            : _patientData != null
                                ? Column(
                                    children: [
                                      _DataTile(
                                          label: 'NIK',
                                          value: _patientData!['nik'] ?? '-'),
                                      _DataTile(
                                          label: 'Nama Lengkap',
                                          value: _patientData!['full_name'] ?? '-'),
                                      _DataTile(
                                          label: 'Tempat, Tgl Lahir',
                                          value: '${_patientData!['birth_place'] ?? '-'}, ${_patientData!['birth_date'] ?? '-'}'),
                                      _DataTile(
                                        label: 'Alamat',
                                        value: _patientData!['address'] ?? '-',
                                      ),
                                      _DataTile(
                                        label: 'Faskes',
                                        value: _patientData!['faskes_name'] ?? '-',
                                      ),
                                      _DataTile(
                                        label: 'Mulai Perawatan',
                                        value: _patientData!['treatment_start_date'] ?? '-',
                                      ),
                                      _DataTile(
                                        label: 'Berat Badan Awal',
                                        value: '${_patientData!['initial_weight_kg'] ?? '-'} kg',
                                        showDivider: false,
                                      ),
                                    ],
                                  )
                                : const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Masukkan atau scan QR Code untuk memuat data pasien.',
                                      style: TextStyle(color: Color(0xFF43474E)),
                                    ),
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
                            decoration: InputDecoration(
                              labelText: 'Kode Aktivasi / QR Code',
                              hintText: 'Contoh: TBC-8AB3F',
                              prefixIcon: const Icon(Icons.qr_code_rounded),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search_rounded),
                                onPressed: () {
                                  if (_qrCodeController.text.isNotEmpty) {
                                    _fetchPatientData(_qrCodeController.text);
                                  }
                                },
                              ),
                            ),
                            validator: _required('Kode aktivasi wajib diisi'),
                            onFieldSubmitted: (value) {
                              if (value.isNotEmpty) {
                                _fetchPatientData(value);
                              }
                            },
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
