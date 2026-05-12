import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../../../features/doctor/presentation/home_page.dart';

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Register specific controllers
  final _nameController = TextEditingController();
  final _strController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _isLogin = true;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _strController.dispose();
    _hospitalController.dispose();
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
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _isLogin
                                  ? DecoratedBox(
                                      key: const ValueKey('decor_login'),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF001833),
                                        borderRadius: BorderRadius.all(Radius.circular(999)),
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Center(
                                          child: Text(
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
                                    )
                                  : TextButton(
                                      key: const ValueKey('btn_login'),
                                      onPressed: () {
                                        setState(() {
                                          _isLogin = true;
                                          _formKey.currentState?.reset();
                                        });
                                      },
                                      child: const Text('SIGN IN'),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: !_isLogin
                                  ? DecoratedBox(
                                      key: const ValueKey('decor_register'),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF001833),
                                        borderRadius: BorderRadius.all(Radius.circular(999)),
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Center(
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
                                    )
                                  : TextButton(
                                      key: const ValueKey('btn_register'),
                                      onPressed: () {
                                        setState(() {
                                          _isLogin = false;
                                          _formKey.currentState?.reset();
                                        });
                                      },
                                      child: const Text('REGISTER'),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      
                      // Email field (shared)
                      _Field(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.mail_outline_rounded,
                        hint: 'email@example.com',
                      ),
                      const SizedBox(height: 12),
                      
                      // Password field (shared)
                      _Field(
                        controller: _passwordController,
                        label: 'Kata Sandi',
                        icon: Icons.lock_outline_rounded,
                        hint: 'Minimal 8 karakter',
                        obscureText: true,
                      ),
                      
                      // Extra fields for Register
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _isLogin
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 12),
                                  _Field(
                                    controller: _confirmPasswordController,
                                    label: 'Konfirmasi Kata Sandi',
                                    icon: Icons.lock_outline_rounded,
                                    hint: 'Ulangi kata sandi',
                                    obscureText: true,
                                    validator: (value) {
                                      if (!_isLogin) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Konfirmasi wajib diisi';
                                        }
                                        if (value != _passwordController.text) {
                                          return 'Password tidak sama';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _Field(
                                    controller: _nameController,
                                    label: 'Nama Lengkap',
                                    icon: Icons.person_outline_rounded,
                                    hint: 'Dr. John Doe',
                                    validator: (value) {
                                      if (!_isLogin && (value == null || value.trim().isEmpty)) {
                                        return 'Nama Lengkap wajib diisi';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _Field(
                                    controller: _strController,
                                    label: 'Nomor STR',
                                    icon: Icons.badge_outlined,
                                    hint: 'XX X X XXXXXXX XXXXXXX',
                                    validator: (value) {
                                      if (!_isLogin && (value == null || value.trim().isEmpty)) {
                                        return 'Nomor STR wajib diisi';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _Field(
                                    controller: _hospitalController,
                                    label: 'Nama Rumah Sakit',
                                    icon: Icons.apartment_rounded,
                                    hint: 'Nama Rumah Sakit / Klinik',
                                    validator: (value) {
                                      if (!_isLogin && (value == null || value.trim().isEmpty)) {
                                        return 'Nama Rumah Sakit wajib diisi';
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
                                ],
                              ),
                      ),
                      
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: FilledButton(
                          key: ValueKey(_isLogin ? 'btn_login' : 'btn_register'),
                          onPressed: _isLoading ? null : _submit,
                          child: Text(_isLogin ? 'MASUK SEKARANG' : 'DAFTAR SEKARANG'),
                        ),
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

    if (!_isLogin && !_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap setujui syarat dan ketentuan terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_isLogin) {
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
              builder: (_) => const HomePage(),
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
    } else {
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
              builder: (_) => const HomePage(),
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
