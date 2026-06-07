// ============================================================
// TBConnect - Auth Service
// File: lib/services/auth_service.dart
// ============================================================

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// KONSTANTA
// ============================================================

const String _kPatientSessionKey = 'tbconnect_patient_session';

// ============================================================
// MODEL: Patient Session (disimpan lokal setelah login)
// ============================================================

class PatientSession {
  final String patientId;
  final String fullName;
  final String doctorId;
  final String qrCode;
  final DateTime treatmentStartDate;
  final double initialWeightKg;

  PatientSession({
    required this.patientId,
    required this.fullName,
    required this.doctorId,
    required this.qrCode,
    required this.treatmentStartDate,
    required this.initialWeightKg,
  });

  factory PatientSession.fromJson(Map<String, dynamic> json) {
    return PatientSession(
      patientId: json['patient_id'],
      fullName: json['full_name'],
      doctorId: json['doctor_id'],
      qrCode: json['qr_code'],
      treatmentStartDate: DateTime.parse(json['treatment_start_date']),
      initialWeightKg: (json['initial_weight_kg'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'patient_id': patientId,
        'full_name': fullName,
        'doctor_id': doctorId,
        'qr_code': qrCode,
        'treatment_start_date': treatmentStartDate.toIso8601String(),
        'initial_weight_kg': initialWeightKg,
      };
}

// ============================================================
// AUTH SERVICE
// ============================================================

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ----------------------------------------------------------
  // DOKTER: Register (via Supabase Auth)
  // Metadata role='doctor' akan trigger auto-insert ke doctors table
  // ----------------------------------------------------------
  Future<AuthResponse> registerDoctor({
    required String email,
    required String password,
    required String fullName,
    required String strNumber,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'role': 'doctor', // Penting! Trigger cek metadata ini
        'full_name': fullName,
        'str_number': strNumber,
      },
    );
    return response;
  }

  // ----------------------------------------------------------
  // DOKTER: Login (via Supabase Auth)
  // ----------------------------------------------------------
  Future<AuthResponse> loginDoctor({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ----------------------------------------------------------
  // DOKTER: Logout
  // ----------------------------------------------------------
  Future<void> logoutDoctor() async {
    await _supabase.auth.signOut();
  }

  // ----------------------------------------------------------
  // DOKTER: Get current doctor profile
  // ----------------------------------------------------------
  Future<Map<String, dynamic>?> getDoctorProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response =
        await _supabase.from('doctors').select().eq('id', userId).single();
    return response;
  }

  // ----------------------------------------------------------
  // PASIEN: Dapatkan Data via QR Code
  // Dipanggil sebelum registrasi untuk mengambil data klinis pasien
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> getPatientByQr(String qrCode) async {
    final response = await _supabase.rpc(
      'get_patient_by_qr',
      params: {
        'p_qr_code': qrCode,
      },
    );
    return Map<String, dynamic>.from(response);
  }

  // ----------------------------------------------------------
  // PASIEN: Aktivasi via QR Code
  // Dipanggil setelah pasien scan QR → tampilkan form username & password
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> activatePatient({
    required String qrCode,
    required String username,
    required String password,
  }) async {
    // Panggil Supabase RPC function
    final response = await _supabase.rpc(
      'activate_patient',
      params: {
        'p_qr_code': qrCode,
        'p_username': username,
        'p_password': password,
      },
    );

    final result = Map<String, dynamic>.from(response);
    return result;
    // Returns: { success: bool, patient_id?: string, full_name?: string, error?: string }
  }

  // ----------------------------------------------------------
  // PASIEN: Login dengan username + password
  // ----------------------------------------------------------
  Future<PatientSession?> loginPatient({
    required String username,
    required String password,
  }) async {
    final response = await _supabase.rpc(
      'login_patient',
      params: {
        'p_username': username,
        'p_password': password,
      },
    );

    final result = Map<String, dynamic>.from(response);

    if (result['success'] == true) {
      final session = PatientSession.fromJson(result);
      // Simpan session lokal
      await _savePatientSession(session);
      return session;
    } else {
      throw Exception(result['error'] ?? 'Login gagal');
    }
  }

  // ----------------------------------------------------------
  // PASIEN: Logout
  // ----------------------------------------------------------
  Future<void> logoutPatient() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPatientSessionKey);
  }

  // ----------------------------------------------------------
  // PASIEN: Get saved session
  // ----------------------------------------------------------
  Future<PatientSession?> getPatientSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kPatientSessionKey);
    if (jsonStr == null) return null;

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return PatientSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePatientSession(PatientSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPatientSessionKey,
      jsonEncode(session.toJson()),
    );
  }

  // ----------------------------------------------------------
  // Helper: Cek apakah user yang login adalah dokter atau pasien
  // ----------------------------------------------------------
  bool get isDoctorLoggedIn => _supabase.auth.currentUser != null;

  Future<bool> get isPatientLoggedIn async {
    final session = await getPatientSession();
    return session != null;
  }
}
