import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';

class PatientLoginPage extends StatefulWidget {
  const PatientLoginPage({super.key});

  @override
  State<PatientLoginPage> createState() => _PatientLoginPageState();
}

class _PatientLoginPageState extends State<PatientLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Tab: 0 = login, 1 = aktivasi
  int _tabIndex = 0;

  // Untuk tab aktivasi
  final _qrCodeController = TextEditingController();
  final _newUsernameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _activateFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _qrCodeController.dispose();
    _newUsernameController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final session = await _authService.loginPatient(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (session != null && mounted) {
        _showSuccess('Selamat datang, ${session.fullName}! (Dashboard pasien belum tersedia di MVP ini)');
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _activate() async {
    if (!_activateFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final result = await _authService.activatePatient(
        qrCode: _qrCodeController.text.trim().toUpperCase(),
        username: _newUsernameController.text.trim(),
        password: _newPasswordController.text,
      );

      if (result['success'] == true && mounted) {
        _showSuccess('Akun berhasil diaktifkan! Selamat datang, ${result['full_name']}. Silakan login.');
        setState(() => _tabIndex = 0);
        _qrCodeController.clear();
        _newUsernameController.clear();
        _newPasswordController.clear();
      } else if (mounted) {
        _showError(result['error'] ?? 'Aktivasi gagal');
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: const Color(0xFF2E8B57),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF2E8B57)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF2E8B57),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              'Halaman Pasien',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A3A4A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Login atau aktivasi akun pasien Anda',
              style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF5A8DA0)),
            ),
            const SizedBox(height: 28),

            // Tab selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD8EDF4)),
              ),
              child: Row(
                children: [
                  _TabButton(
                    label: 'Login',
                    isActive: _tabIndex == 0,
                    color: const Color(0xFF2E8B57),
                    onTap: () => setState(() => _tabIndex = 0),
                  ),
                  _TabButton(
                    label: 'Aktivasi Akun',
                    isActive: _tabIndex == 1,
                    color: const Color(0xFF2E8B57),
                    onTap: () => setState(() => _tabIndex = 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            if (_tabIndex == 0) _buildLoginForm() else _buildActivationForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _usernameController,
            label: 'Username',
            hint: 'Username Anda',
            icon: Icons.person_outline_rounded,
            accentColor: const Color(0xFF2E8B57),
            validator: (v) => (v == null || v.isEmpty) ? 'Username wajib diisi' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            accentColor: const Color(0xFF2E8B57),
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: const Color(0xFF5A8DA0),
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E8B57),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Login', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum punya akun? Minta kode aktivasi kepada dokter Anda,\nlalu tap "Aktivasi Akun" di atas.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5A8DA0)),
          ),
        ],
      ),
    );
  }

  Widget _buildActivationForm() {
    return Form(
      key: _activateFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2E8B57).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2E8B57).withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF2E8B57), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Masukkan kode aktivasi dari dokter Anda (format: TBC-XXXXX), lalu buat username & password.',
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF2E8B57)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildTextField(
            controller: _qrCodeController,
            label: 'Kode Aktivasi dari Dokter',
            hint: 'Contoh: TBC-8AB3F',
            icon: Icons.qr_code_rounded,
            accentColor: const Color(0xFF2E8B57),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Kode aktivasi wajib diisi';
              if (!v.trim().toUpperCase().startsWith('TBC-')) return 'Format kode harus TBC-XXXXX';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _newUsernameController,
            label: 'Buat Username',
            hint: 'Minimal 4 karakter',
            icon: Icons.person_outline_rounded,
            accentColor: const Color(0xFF2E8B57),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Username wajib diisi';
              if (v.length < 4) return 'Username minimal 4 karakter';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _newPasswordController,
            label: 'Buat Password',
            hint: 'Minimal 6 karakter',
            icon: Icons.lock_outline_rounded,
            accentColor: const Color(0xFF2E8B57),
            obscureText: true,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password wajib diisi';
              if (v.length < 6) return 'Password minimal 6 karakter';
              return null;
            },
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _activate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E8B57),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Aktivasi & Daftar', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color accentColor,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A3A4A)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1A3A4A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: const Color(0xFFACC8D4), fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF5A8DA0), size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD8EDF4), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accentColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF5A8DA0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
