import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../../../pages/doctor/doctor_dashboard_page.dart';
import 'doctor_register_screen.dart';

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const Text(
                    'Selamat Datang',
                    style: TextStyle(
                      fontSize: 40,
                      height: 1.2,
                      letterSpacing: -0.8,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF112D4E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Silakan masuk ke akun Clinical Portal Anda.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF43474E),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
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
                          color: Color.fromRGBO(17, 45, 78, 0.06),
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
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF112D4E),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'SIGN IN',
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
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const DoctorRegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('REGISTER'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const _FieldLabel('Email'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              hintText: 'Masukkan email Anda',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          const _FieldLabel('Kata Sandi'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Masukkan kata sandi Anda',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Password wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text('Lupa Kata Sandi?'),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _isLoading ? null : _submit,
                            iconAlignment: IconAlignment.end,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('MASUK SEKARANG'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.security_rounded,
                        size: 16,
                        color: Color(0xFF2A609C),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Aman & Terenkripsi',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF43474E),
                        ),
                      ),
                    ],
                  ),
                ],
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

    setState(() => _isLoading = true);

    _authService
        .loginDoctor(
      email: _emailController.text.trim(),
      password: _passwordController.text,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF43474E),
      ),
    );
  }
}
