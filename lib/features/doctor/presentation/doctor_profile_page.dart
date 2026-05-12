import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tbconnect/services/auth_service.dart';
import 'package:tbconnect/features/auth/presentation/portal_role_screen.dart';

class DoctorProfilePage extends StatefulWidget {
  const DoctorProfilePage({super.key});

  @override
  State<DoctorProfilePage> createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  final _authService = AuthService();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getDoctorProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
        content: Text('Yakin ingin keluar?', style: GoogleFonts.manrope()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.manrope(color: const Color(0xFF5A8DA0))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Logout', style: GoogleFonts.manrope(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logoutDoctor();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PortalRoleScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Profil Dokter',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF112D4E),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDE2C2C)),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
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
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFFE5F0FF),
                          child: Text(
                            _getInitials(_profile?['full_name'] ?? 'D'),
                            style: GoogleFonts.manrope(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF112D4E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _profile?['full_name'] ?? '-',
                          style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF112D4E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _profile?['specialization'] ?? 'Dokter Paru-Paru',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: const Color(0xFF5A8DA0),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        _buildInfoRow('Email', _profile?['email'] ?? '-'),
                        _buildInfoRow('STR', _profile?['str_number'] ?? '-'),
                        _buildInfoRow('Rumah Sakit', _profile?['hospital_name'] ?? '-'),
                        _buildInfoRow('No. Telepon', _profile?['phone_number'] ?? '-'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF5A8DA0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: const Color(0xFF112D4E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }
}
