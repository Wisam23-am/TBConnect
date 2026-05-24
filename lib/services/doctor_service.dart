// ============================================================
// TBConnect - Doctor Service
// File: lib/services/doctor_service.dart
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ----------------------------------------------------------
  // Tambah pasien baru
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
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception(
          'Sesi dokter tidak ditemukan. Silakan login ulang sebelum menambahkan pasien.');
    }

    final doctorId = currentUser.id;
    final age = DateTime.now().year - birthDate.year;

    final response = await _supabase
        .from('patients')
        .insert({
          'doctor_id': doctorId,
          'nik': nik,
          'full_name': fullName,
          'birth_place': birthPlace,
          'birth_date': birthDate.toIso8601String().split('T').first,
          'age': age,
          'gender': gender,
          'initial_weight_kg': initialWeightKg,
          'treatment_start_date':
              treatmentStartDate.toIso8601String().split('T').first,
          'phone_number': phoneNumber,
          'address': address,
          'faskes_name': faskesName,
        })
        .select()
        .single();

    await _generateClinicVisits(
      patientId: response['id'],
      doctorId: doctorId,
      treatmentStartDate: treatmentStartDate,
    );

    return response;
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
        'patient_id': patientId,
        'doctor_id': doctorId,
        'visit_number': i + 1,
        'scheduled_date': visitDate.toIso8601String().split('T').first,
        'location': location,
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
    final patient = await _supabase.from('patients').select('''
          *,
          medication_logs(log_date, session, status, taken_at, late_reason),
          daily_symptom_reports(report_date, mood_level, symptoms, emergency_symptoms, notes, created_at),
          symptom_logs(log_date, nausea_level, dizziness_level, fatigue_level, hemoptysis, chest_pain, is_emergency),
          weight_logs(log_date, weight_kg, day_of_treatment),
          clinic_visits(visit_number, scheduled_date, location, status, reschedule_requested),
          doctor_feedbacks(message, is_urgent, created_at)
        ''').eq('id', patientId).single();
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
      'doctor_id': doctorId,
      'patient_id': patientId,
      'message': message,
      'is_urgent': isUrgent,
    });

    await _supabase.from('notifications').insert({
      'patient_id': patientId,
      'type': 'doctor_feedback',
      'title': isUrgent ? '⚠️ Pesan Penting dari Dokter' : 'Pesan dari Dokter',
      'body':
          message.length > 100 ? '${message.substring(0, 100)}...' : message,
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

  // ----------------------------------------------------------
  // Kirim Pengingat Minum Obat ke Pasien
  // ----------------------------------------------------------
  Future<void> sendReminder(String patientId) async {
    await _supabase.rpc(
      'send_patient_reminder',
      params: {'p_patient_id': patientId},
    );
  }
}
