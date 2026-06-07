#!/usr/bin/env dart
// ============================================================
// TBConnect - Medication Window Migration Script
// Run dengan: dart scripts/run_migration.dart
// ============================================================

import 'package:http/http.dart' as http;
import 'dart:convert';

const supabaseUrl = 'https://teifdfxmyebvnlcfngvc.supabase.co';
const anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlaWZkZnhteWVidm5sY2ZuZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMzk4MTcsImV4cCI6MjA5MjkxNTgxN30.fEXFsYbZcrGp8PBrLKu3ptlQXtWyqZ6C9-kKyQJsdDI';

final migrationSQL = '''
-- ============================================================
-- TBConnect - FINAL MIGRATION: Medication Window Safety Logic
-- ============================================================

-- STEP 1: Ensure late_reason column exists
ALTER TABLE medication_logs
ADD COLUMN IF NOT EXISTS late_reason TEXT;

-- STEP 2: Drop old RPC functions to prevent conflicts
DROP FUNCTION IF EXISTS public.log_medication_taken(UUID, TEXT);
DROP FUNCTION IF EXISTS public.log_medication_taken(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.get_today_medication_status(UUID);

-- STEP 3: Create log_medication_taken with window validation
CREATE OR REPLACE FUNCTION public.log_medication_taken(
  p_patient_id  UUID,
  p_session     TEXT,
  p_reason      TEXT DEFAULT NULL,
  p_log_date    DATE DEFAULT NULL
)
RETURNS JSONB AS \$\$
DECLARE
  v_server_time   TIMESTAMPTZ := NOW() AT TIME ZONE 'Asia/Jakarta';
  v_current_hour  SMALLINT := EXTRACT(HOUR FROM v_server_time);
  v_today         DATE := v_server_time::DATE;
  v_target_date   DATE := COALESCE(p_log_date, v_today);
  v_status        TEXT;
  v_session_start SMALLINT;
  v_session_end   SMALLINT;
  v_existing      public.medication_logs;
BEGIN
  CASE p_session
    WHEN 'morning'   THEN v_session_start := 6;  v_session_end := 9;
    WHEN 'afternoon' THEN v_session_start := 13; v_session_end := 16;
    WHEN 'evening'   THEN v_session_start := 18; v_session_end := 22;
    ELSE RETURN jsonb_build_object('success', false, 'error', 'Session tidak valid');
  END CASE;

  IF v_target_date < v_today THEN
    v_status := 'late';
  ELSIF v_target_date = v_today THEN
    IF v_current_hour < v_session_start THEN
      RETURN jsonb_build_object('success', false, 'error', 'Waktu minum obat belum tiba');
    ELSIF v_current_hour < v_session_end THEN
      v_status := 'taken';
    ELSIF p_session = 'morning' AND v_current_hour < 13 THEN
      v_status := 'late';
    ELSIF p_session = 'afternoon' AND v_current_hour < 18 THEN
      v_status := 'late';
    ELSIF p_session = 'evening' THEN
      v_status := 'late';
    ELSE
      RETURN jsonb_build_object('success', false, 'error', 'Window untuk sesi ini sudah ditutup. Tidak boleh double dosing dengan sesi berikutnya.');
    END IF;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Tidak bisa mengisi untuk tanggal di masa depan');
  END IF;

  SELECT * INTO v_existing
  FROM public.medication_logs
  WHERE patient_id = p_patient_id
    AND log_date = v_target_date
    AND session = p_session;

  IF FOUND AND v_existing.status = 'taken' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Obat sudah dicatat pada tanggal tersebut');
  END IF;

  IF FOUND AND v_existing.late_reason IS NOT NULL AND p_reason IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Late reason sudah dicatat');
  END IF;

  INSERT INTO public.medication_logs (patient_id, log_date, session, status, taken_at, late_reason)
  VALUES (p_patient_id, v_target_date, p_session, v_status, NOW(), p_reason)
  ON CONFLICT (patient_id, log_date, session)
  DO UPDATE SET status = EXCLUDED.status,
                taken_at = EXCLUDED.taken_at,
                late_reason = COALESCE(public.medication_logs.late_reason, EXCLUDED.late_reason);

  RETURN jsonb_build_object('success', true, 'status', v_status, 'log_date', v_target_date);
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 4: Create get_today_medication_status with strict window cutoffs
CREATE OR REPLACE FUNCTION public.get_today_medication_status(
  p_patient_id UUID,
  p_target_date DATE DEFAULT NULL
)
RETURNS JSONB AS \$\$
DECLARE
  v_server_time   TIMESTAMPTZ := NOW() AT TIME ZONE 'Asia/Jakarta';
  v_current_hour  SMALLINT := EXTRACT(HOUR FROM v_server_time);
  v_today         DATE := v_server_time::DATE;
  v_date          DATE := COALESCE(p_target_date, v_today);
  
  v_morning_log   public.medication_logs;
  v_afternoon_log public.medication_logs;
  v_evening_log   public.medication_logs;
  
  v_result        JSONB;
BEGIN
  SELECT * INTO v_morning_log   FROM public.medication_logs
    WHERE patient_id = p_patient_id AND log_date = v_date AND session = 'morning';
  SELECT * INTO v_afternoon_log FROM public.medication_logs
    WHERE patient_id = p_patient_id AND log_date = v_date AND session = 'afternoon';
  SELECT * INTO v_evening_log   FROM public.medication_logs
    WHERE patient_id = p_patient_id AND log_date = v_date AND session = 'evening';

  v_result := jsonb_build_array(
    jsonb_build_object(
      'session',       'morning',
      'label',         'Pagi',
      'window',        '06:00 - 09:00',
      'status',        CASE
                         WHEN v_morning_log.status IS NOT NULL THEN v_morning_log.status
                         WHEN v_date < v_today THEN 'missed'
                         WHEN v_date > v_today THEN 'locked'
                         WHEN v_current_hour < 6  THEN 'locked'
                         WHEN v_current_hour < 9  THEN 'active'
                         WHEN v_current_hour < 13 THEN 'late'
                         ELSE 'locked'
                       END,
      'taken_at',      v_morning_log.taken_at,
      'late_reason',   v_morning_log.late_reason
    ),
    jsonb_build_object(
      'session',       'afternoon',
      'label',         'Siang',
      'window',        '13:00 - 16:00',
      'status',        CASE
                         WHEN v_afternoon_log.status IS NOT NULL THEN v_afternoon_log.status
                         WHEN v_date < v_today THEN 'missed'
                         WHEN v_date > v_today THEN 'locked'
                         WHEN v_current_hour < 13 THEN 'locked'
                         WHEN v_current_hour < 16 THEN 'active'
                         WHEN v_current_hour < 18 THEN 'late'
                         ELSE 'locked'
                       END,
      'taken_at',      v_afternoon_log.taken_at,
      'late_reason',   v_afternoon_log.late_reason
    ),
    jsonb_build_object(
      'session',       'evening',
      'label',         'Malam',
      'window',        '18:00 - 22:00',
      'status',        CASE
                         WHEN v_evening_log.status IS NOT NULL THEN v_evening_log.status
                         WHEN v_date < v_today THEN 'missed'
                         WHEN v_date > v_today THEN 'locked'
                         WHEN v_current_hour < 18 THEN 'locked'
                         WHEN v_current_hour < 22 THEN 'active'
                         ELSE 'late'
                       END,
      'taken_at',      v_evening_log.taken_at,
      'late_reason',   v_evening_log.late_reason
    )
  );

  RETURN jsonb_build_object(
    'success',       true,
    'server_time',   v_server_time,
    'target_date',   v_date,
    'sessions',      v_result
  );
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;
''';

Future<void> main() async {
  print('🚀 TBConnect - Medication Window Migration');
  print('=' * 60);
  print('URL: $supabaseUrl');
  print('Anon Key: ${anonKey.substring(0, 20)}...');
  print('=' * 60);
  print('');

  print('⚠️  NOTE: Supabase anon key cannot execute DDL operations.');
  print('   Diperlukan Service Role Key untuk menjalankan migration.');
  print('');

  try {
    print('📝 Attempting migration via REST API...');

    // Split migration into individual statements
    List<String> statements = migrationSQL
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    print('📊 Total SQL statements: ${statements.length}');
    print('');

    // Since anon key can't execute DDL, we'll provide instructions
    print('❌ HASIL: Anon key tidak bisa menjalankan DDL (DROP/CREATE)');
    print('');
    print('✅ SOLUSI: Ada 2 pilihan:');
    print('');
    print('OPSI 1: Gunakan Service Role Key');
    print('  1. Buka https://teifdfxmyebvnlcfngvc.supabase.co');
    print('  2. Settings → API → Project API keys');
    print('  3. Copy "Service role secret" (bukan anon key)');
    print('  4. Update script dengan service role key');
    print('');
    print('OPSI 2: Paste ke SQL Editor (Manual)');
    print('  1. Buka https://teifdfxmyebvnlcfngvc.supabase.co');
    print('  2. SQL Editor → New Query');
    print(
        '  3. Paste seluruh isi file: database/FINAL_MIGRATION_APPLY_TO_SUPABASE.sql');
    print('  4. Klik RUN');
    print('');

    // Check if service role key is available via environment or config
    print('🔍 Cek environment variables...');
    bool hasServiceKey = false;
    String? serviceKey =
        const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');

    if (serviceKey != null && serviceKey.isNotEmpty) {
      print('✅ Service role key ditemukan di environment!');
      hasServiceKey = true;
      await runMigrationWithServiceKey(serviceKey, statements);
    } else {
      print('❌ Service role key tidak ditemukan di environment');
      print('');
      print('Untuk menggunakan script ini dengan service role key:');
      print(
          '  dart scripts/run_migration.dart --service-key YOUR_SERVICE_ROLE_KEY');
      print('');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> runMigrationWithServiceKey(
    String serviceKey, List<String> statements) async {
  print('🔄 Menjalankan migration dengan service role key...');
  print('');

  int successCount = 0;
  int failureCount = 0;

  for (int i = 0; i < statements.length; i++) {
    String statement = statements[i];
    if (statement.isEmpty) continue;

    print(
        '[$i/${statements.length}] Executing: ${statement.substring(0, 50)}...');

    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/rpc/exec_sql'),
        headers: {
          'Authorization': 'Bearer $serviceKey',
          'apikey': serviceKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'sql': statement}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('  ✅ Success');
        successCount++;
      } else {
        print('  ❌ Failed: ${response.statusCode}');
        print('     ${response.body}');
        failureCount++;
      }
    } catch (e) {
      print('  ❌ Error: $e');
      failureCount++;
    }
  }

  print('');
  print('=' * 60);
  print('📊 Migration Complete');
  print('   ✅ Success: $successCount');
  print('   ❌ Failed: $failureCount');
  print('=' * 60);

  if (failureCount == 0) {
    print('');
    print('🎉 Migration berhasil! Window safety logic sudah aktif.');
    print(
        '   • Morning: 06:00-09:00 (active) → 09:00-13:00 (late) → 13:00+ (locked)');
    print(
        '   • Afternoon: 13:00-16:00 (active) → 16:00-18:00 (late) → 18:00+ (locked)');
    print('   • Evening: 18:00-22:00 (active) → 22:00+ (late)');
    print('');
    print('Silakan jalankan app dengan: flutter run');
  }
}
