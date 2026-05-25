// ============================================================
// TBConnect - Patient Service
// File: lib/services/patient_service.dart
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

class PatientDataService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ----------------------------------------------------------
  // Log minum obat
  // ----------------------------------------------------------
  Future<void> logMedication({
    required String patientId,
    required String session,
    String? reason,
    DateTime? date,
  }) async {
    await _supabase.rpc('log_medication_taken', params: {
      'p_patient_id': patientId,
      'p_session': session,
      if (reason != null && reason.isNotEmpty) 'p_reason': reason,
      if (date != null) 'p_log_date': date.toIso8601String().split('T').first,
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
      'p_patient_id': patientId,
      'p_nausea_level': nauseaLevel,
      'p_dizziness_level': dizzinessLevel,
      'p_fatigue_level': fatigueLevel,
      'p_hemoptysis': hemoptysis,
      'p_chest_pain': chestPain,
      'p_shortness_of_breath': shortnessOfBreath,
      'p_notes': notes,
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
      'p_weight_kg': weightKg,
      'p_notes': notes,
    });
  }

  // ----------------------------------------------------------
  // Get status obat hari ini / tanggal tertentu
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> getTodayMedications({
    required String patientId,
    DateTime? date,
  }) async {
    final result = await _supabase.rpc('get_today_medication_status', params: {
      'p_patient_id': patientId,
      if (date != null)
        'p_target_date': date.toIso8601String().split('T').first,
    });
    return Map<String, dynamic>.from(result);
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
  // Tandai notifikasi sudah dibaca
  // ----------------------------------------------------------
  Future<void> markNotificationRead({
    required String patientId,
    required String notificationId,
  }) async {
    try {
      await _supabase.rpc('mark_notification_read', params: {
        'p_notif_id': notificationId,
      });
    } catch (_) {
      await _supabase.rpc('mark_notification_read', params: {
        'p_patient_id': patientId,
        'p_notification_id': notificationId,
      });
    }
  }

  // ----------------------------------------------------------
  // Get weight history pasien
  // ----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getWeightHistory({
    required String patientId,
    int limit = 10,
  }) async {
    return await _supabase
        .from('weight_logs')
        .select()
        .eq('patient_id', patientId)
        .order('log_date', ascending: false)
        .limit(limit);
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
      'p_visit_id': visitId,
      'p_patient_id': patientId,
      'p_new_date': newDate.toIso8601String().split('T').first,
      'p_reason': reason,
    });
  }

  // ----------------------------------------------------------
  // Get all clinic visits (jadwal kontrol)
  // ----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getClinicVisits({
    required String patientId,
  }) async {
    final result = await _supabase.rpc('get_patient_clinic_visits', params: {
      'p_patient_id': patientId,
    });
    final list = List<dynamic>.from(result as List? ?? []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ----------------------------------------------------------
  // Save daily symptom report
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> saveDailySymptomReport({
    required String patientId,
    required String moodLevel,
    required List<String> symptoms,
    required List<String> emergencySymptoms,
    String? notes,
  }) async {
    final result = await _supabase.rpc('save_daily_symptom_report', params: {
      'p_patient_id': patientId,
      'p_mood_level': moodLevel,
      'p_symptoms': symptoms,
      'p_emergency_symptoms': emergencySymptoms,
      'p_notes': notes,
    });
    return Map<String, dynamic>.from(result);
  }

  // ----------------------------------------------------------
  // Get today's symptom report
  // ----------------------------------------------------------
  Future<Map<String, dynamic>?> getTodaySymptomReport({
    required String patientId,
  }) async {
    final result = await _supabase.rpc('get_today_symptom_report', params: {
      'p_patient_id': patientId,
    });
    final data = result['data'];
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  // ----------------------------------------------------------
  // Get symptom report history
  // ----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getSymptomReportHistory({
    required String patientId,
    int limit = 7,
  }) async {
    final result = await _supabase.rpc('get_daily_symptom_reports', params: {
      'p_patient_id': patientId,
      'p_limit': limit,
    });
    final reports = result['reports'] as List? ?? [];
    return reports.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ----------------------------------------------------------
  // Get full patient profile (including doctor details)
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> getPatientProfile(String patientId) async {
    final response = await _supabase.rpc('get_patient_profile', params: {
      'p_patient_id': patientId,
    });
    return Map<String, dynamic>.from(response);
  }
}
