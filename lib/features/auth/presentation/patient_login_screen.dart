import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/auth_service.dart';
import 'patient_qr_screen.dart';
import 'patient_register_screen.dart';

class PatientLoginScreen extends StatefulWidget {
  const PatientLoginScreen({super.key});

  @override
  State<PatientLoginScreen> createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends State<PatientLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'TBConnect',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Patient Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF43474E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD4E3FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 36,
                            color: Color(0xFF001833),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'New Patient?',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF001833),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Connect your account to your clinic to begin your guided treatment plan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Color(0xFF43474E),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const PatientQrScreen(),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text("SCAN DOCTOR'S QR CODE"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Welcome Back',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF001833),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const _FieldLabel('Username'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              hintText: 'Enter your username',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Username wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          const _FieldLabel('Password'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Enter your password',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Password wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton(
                            onPressed: _isLoading ? null : _submitLogin,
                            child: const Text('LOGIN'),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PatientRegisterScreen(),
                                ),
                              );
                            },
                            child: const Text(
                                'Belum punya akun? Buat akun pasien'),
                          ),
                        ],
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

  void _submitLogin() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    _authService
        .loginPatient(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    )
        .then((session) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selamat datang, ${session?.fullName ?? 'pasien'}!',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
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

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: const Color(0xFFC4C6CF).withValues(alpha: 0.4)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 24, 51, 0.06),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
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
        fontSize: 11,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
        color: Color(0xFF43474E),
      ),
    );
  }
}
