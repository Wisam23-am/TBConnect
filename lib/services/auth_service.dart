// ============================================================
// TBConnect - Flutter Auth & Supabase Service Layer
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
        'role': 'doctor',           // Penting! Trigger cek metadata ini
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

    final response = await _supabase
        .from('doctors')
        .select()
        .eq('id', userId)
        .single();
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


// ============================================================
// PATIENT SERVICE
// Service layer untuk operasi pasien (dipanggil dari Flutter)
// Menggunakan Supabase Edge Functions atau service_role via RPC
// ============================================================

class PatientDataService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Semua request harus sertakan patient_id di payload
  // karena pasien tidak punya JWT Supabase Auth

  // ----------------------------------------------------------
  // Log minum obat (dipanggil saat pasien tap "Minum Obat")
  // Menggunakan server time (NOW()) via RPC untuk hindari manipulasi
  // ----------------------------------------------------------
  Future<void> logMedication({
    required String patientId,
    required String session, // 'morning' | 'afternoon' | 'evening'
  }) async {
    await _supabase.rpc('log_medication_taken', params: {
      'p_patient_id': patientId,
      'p_session': session,
    });
  }

  // ----------------------------------------------------------
  // Log gejala harian
  // ----------------------------------------------------------
  Future<void> logSymptoms({
    required String patientId,
    required int nauseaLevel,
    required int dizzinessLevel,
    required int fatigueLevel,
    required bool hemoptysis,
    required bool chestPain,
    required bool shortnessOfBreath,
    String? notes,
  }) async {
    await _supabase.rpc('log_daily_symptoms', params: {
      'p_patient_id':            patientId,
      'p_nausea_level':          nauseaLevel,
      'p_dizziness_level':       dizzinessLevel,
      'p_fatigue_level':         fatigueLevel,
      'p_hemoptysis':            hemoptysis,
      'p_chest_pain':            chestPain,
      'p_shortness_of_breath':   shortnessOfBreath,
      'p_notes':                 notes,
    });
  }

  // ----------------------------------------------------------
  // Input berat badan
  // ----------------------------------------------------------
  Future<void> logWeight({
    required String patientId,
    required double weightKg,
    String? notes,
  }) async {
    await _supabase.rpc('log_weight', params: {
      'p_patient_id': patientId,
      'p_weight_kg':  weightKg,
      'p_notes':      notes,
    });
  }

  // ----------------------------------------------------------
  // Get status obat hari ini
  // ----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getTodayMedications({
    required String patientId,
  }) async {
    return await _supabase.rpc('get_today_medication_status', params: {
      'p_patient_id': patientId,
    });
  }

  // ----------------------------------------------------------
  // Get notifikasi pasien
  // ----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getPatientNotifications({
    required String patientId,
  }) async {
    return await _supabase.rpc('get_patient_notifications', params: {
      'p_patient_id': patientId,
    });
  }

  // ----------------------------------------------------------
  // Request reschedule kunjungan
  // ----------------------------------------------------------
  Future<void> requestReschedule({
    required String visitId,
    required String patientId,
    required DateTime newDate,
    required String reason,
  }) async {
    await _supabase.rpc('request_visit_reschedule', params: {
      'p_visit_id':   visitId,
      'p_patient_id': patientId,
      'p_new_date':   newDate.toIso8601String().split('T').first,
      'p_reason':     reason,
    });
  }
}


// ============================================================
// DOCTOR SERVICE
// Operasi dokter (memiliki Supabase Auth session)
// RLS otomatis memfilter data berdasarkan auth.uid()
// ============================================================

class DoctorService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ----------------------------------------------------------
  // Tambah pasien baru → QR code di-generate otomatis via trigger
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> addPatient({
    required String nik,
    required String fullName,
    required String birthPlace,
    required DateTime birthDate,
    required String gender,
    required double initialWeightKg,
    required DateTime treatmentStartDate,
    String? phoneNumber,
    String? address,
    String? faskesName,
  }) async {
    final doctorId = _supabase.auth.currentUser!.id;

    // Hitung umur secara simpel (bisa disesuaikan jika perlu akurat ke hari)
    final age = DateTime.now().year - birthDate.year;

    final response = await _supabase.from('patients').insert({
      'doctor_id':            doctorId,
      'nik':                  nik,
      'full_name':            fullName,
      'birth_place':          birthPlace,
      'birth_date':           birthDate.toIso8601String().split('T').first,
      'age':                  age,
      'gender':               gender,
      'initial_weight_kg':    initialWeightKg,
      'treatment_start_date': treatmentStartDate.toIso8601String().split('T').first,
      'phone_number':         phoneNumber,
      'address':              address,
      'faskes_name':          faskesName,
    }).select().single();

    // Auto-generate jadwal kunjungan 6 bulan
    await _generateClinicVisits(
      patientId: response['id'],
      doctorId: doctorId,
      treatmentStartDate: treatmentStartDate,
    );

    return response;
    // response['qr_code'] = kode QR yang auto-generated (contoh: TBC-8899A)
    // Gunakan kode ini untuk generate QR Code image di Flutter (paket: qr_flutter)
  }

  // ----------------------------------------------------------
  // Auto-generate 6 jadwal kunjungan bulanan
  // ----------------------------------------------------------
  Future<void> _generateClinicVisits({
    required String patientId,
    required String doctorId,
    required DateTime treatmentStartDate,
  }) async {
    final doctorProfile = await _supabase
        .from('doctors')
        .select('hospital_name')
        .eq('id', doctorId)
        .single();

    final location = doctorProfile['hospital_name'] ?? 'Klinik / Puskesmas';

    final visits = List.generate(6, (i) {
      final visitDate = DateTime(
        treatmentStartDate.year,
        treatmentStartDate.month + (i + 1),
        treatmentStartDate.day,
      );
      return {
        'patient_id':    patientId,
        'doctor_id':     doctorId,
        'visit_number':  i + 1,
        'scheduled_date': visitDate.toIso8601String().split('T').first,
        'location':      location,
      };
    });

    await _supabase.from('clinic_visits').insert(visits);
  }

  // ----------------------------------------------------------
  // Get daftar pasien dengan triage ranking
  // ----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getTriageBoard() async {
    final doctorId = _supabase.auth.currentUser!.id;

    return await _supabase
        .from('v_doctor_triage')
        .select()
        .eq('doctor_id', doctorId)
        .order('priority_level', ascending: true)
        .order('full_name', ascending: true);
  }

  // ----------------------------------------------------------
  // Get detail pasien lengkap
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> getPatientDetail(String patientId) async {
    final patient = await _supabase
        .from('patients')
        .select('''
          *,
          medication_logs(log_date, session, status, taken_at),
          symptom_logs(log_date, nausea_level, dizziness_level, fatigue_level, hemoptysis, chest_pain, is_emergency),
          weight_logs(log_date, weight_kg, day_of_treatment),
          clinic_visits(visit_number, scheduled_date, location, status, reschedule_requested),
          doctor_feedbacks(message, is_urgent, created_at)
        ''')
        .eq('id', patientId)
        .single();
    return patient;
  }

  // ----------------------------------------------------------
  // Kirim feedback ke pasien
  // ----------------------------------------------------------
  Future<void> sendFeedback({
    required String patientId,
    required String message,
    bool isUrgent = false,
  }) async {
    final doctorId = _supabase.auth.currentUser!.id;
    await _supabase.from('doctor_feedbacks').insert({
      'doctor_id':  doctorId,
      'patient_id': patientId,
      'message':    message,
      'is_urgent':  isUrgent,
    });

    // Insert notifikasi ke pasien
    await _supabase.from('notifications').insert({
      'patient_id': patientId,
      'type':       'doctor_feedback',
      'title':      isUrgent ? '⚠️ Pesan Penting dari Dokter' : 'Pesan dari Dokter',
      'body':       message.length > 100 ? '${message.substring(0, 100)}...' : message,
    });
  }

  // ----------------------------------------------------------
  // Get adherence summary semua pasien
  // ----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAdherenceSummary() async {
    final doctorId = _supabase.auth.currentUser!.id;
    return await _supabase
        .from('v_patient_adherence_summary')
        .select()
        .eq('doctor_id', doctorId);
  }
}