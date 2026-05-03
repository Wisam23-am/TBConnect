import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../../../pages/doctor/doctor_dashboard_page.dart';
import 'doctor_login_screen.dart';

class DoctorRegisterScreen extends StatefulWidget {
  const DoctorRegisterScreen({super.key});

  @override
  State<DoctorRegisterScreen> createState() => _DoctorRegisterScreenState();
}

class _DoctorRegisterScreenState extends State<DoctorRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _strController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _strController.dispose();
    _hospitalController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFC4C6CF).withValues(alpha: 0.4),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 24, 51, 0.06),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Color(0xFF112D4E),
                          child: Icon(
                            Icons.medical_services_rounded,
                            size: 30,
                            color: Color(0xFFD4E3FF),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'TBConnect',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF001833),
                        ),
                      ),
                      const Text(
                        'Doctor Portal',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF43474E)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const DoctorLoginScreen(),
                                  ),
                                );
                              },
                              child: const Text('SIGN IN'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFF001833),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(999)),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  'REGISTER',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _Field(
                        controller: _nameController,
                        label: 'Nama Lengkap',
                        icon: Icons.person_outline_rounded,
                        hint: 'Dr. John Doe',
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _strController,
                        label: 'Nomor STR',
                        icon: Icons.badge_outlined,
                        hint: 'XX X X XXXXXXX XXXXXXX',
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _hospitalController,
                        label: 'Nama Rumah Sakit',
                        icon: Icons.apartment_rounded,
                        hint: 'Nama Rumah Sakit / Klinik',
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.mail_outline_rounded,
                        hint: 'email@example.com',
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _passwordController,
                        label: 'Kata Sandi',
                        icon: Icons.lock_outline_rounded,
                        hint: 'Minimal 8 karakter',
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _confirmPasswordController,
                        label: 'Konfirmasi Kata Sandi',
                        icon: Icons.lock_outline_rounded,
                        hint: 'Ulangi kata sandi',
                        obscureText: true,
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
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _termsAccepted,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() {
                            _termsAccepted = value ?? false;
                          });
                        },
                        title: const Text(
                          'Saya menyetujui Syarat & Ketentuan serta Kebijakan Privasi TBConnect.',
                          style: TextStyle(fontSize: 13),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: const Text('DAFTAR SEKARANG'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap setujui syarat dan ketentuan terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    _authService
        .registerDoctor(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
      strNumber: _strController.text.trim(),
    )
        .then((response) {
      if (!mounted) return;
      if (response.user != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const DoctorDashboardPage(),
          ),
          (route) => false,
        );
      }
    }).onError<AuthException>((error, stackTrace) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message,
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
            'Terjadi kesalahan. Coba lagi.',
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

class _Field extends StatefulWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.hint,
    this.obscureText = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String hint;
  final bool obscureText;
  final String? Function(String?)? validator;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF43474E),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon),
            suffixIcon: widget.obscureText
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        _obscure = !_obscure;
                      });
                    },
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  )
                : null,
          ),
          validator: widget.validator ??
              (value) {
                if (value == null || value.trim().isEmpty) {
                  return '${widget.label} wajib diisi';
                }
                return null;
              },
        ),
      ],
    );
  }
}
