-- ============================================================
-- TBConnect - Supabase RPC Functions (Tambahan)
-- Dipanggil dari Flutter via PatientDataService
-- Semua fungsi SECURITY DEFINER untuk bypass RLS
-- (Pasien tidak punya Supabase Auth session)
-- ============================================================


-- ============================================================
-- RPC: get_upcoming_visits
-- Ambil jadwal kontrol yang akan datang untuk pasien
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_upcoming_visits(
  p_patient_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'scheduled_date', cv.scheduled_date,
      'location',       cv.location,
      'visit_number',   cv.visit_number,
      'status',         cv.status
    ) ORDER BY cv.scheduled_date ASC
  )
  INTO v_result
  FROM public.clinic_visits cv
  WHERE cv.patient_id = p_patient_id
    AND cv.status = 'upcoming'
  LIMIT 1;

  RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_upcoming_visits IS 'RPC: Ambil jadwal kontrol mendatang untuk pasien (bypass RLS)';


-- ============================================================
-- RPC: log_medication_taken
-- Dipanggil pasien saat tap "Minum Obat"
-- Menggunakan server time NOW() — WAJIB untuk hindari manipulasi
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_medication_taken(
  p_patient_id  UUID,
  p_session     TEXT  -- 'morning' | 'afternoon' | 'evening'
)
RETURNS JSONB AS $$
DECLARE
  v_server_time   TIMESTAMPTZ := NOW() AT TIME ZONE 'Asia/Jakarta';
  v_current_hour  SMALLINT := EXTRACT(HOUR FROM v_server_time);
  v_log_date      DATE := v_server_time::DATE;
  v_status        TEXT;
  v_session_start SMALLINT;
  v_session_end   SMALLINT;
  v_existing      public.medication_logs;
BEGIN
  -- Validasi session dan jam aktif (WIB)
  CASE p_session
    WHEN 'morning'   THEN v_session_start := 6;  v_session_end := 9;
    WHEN 'afternoon' THEN v_session_start := 13; v_session_end := 15;
    WHEN 'evening'   THEN v_session_start := 18; v_session_end := 21;
    ELSE RETURN jsonb_build_object('success', false, 'error', 'Session tidak valid');
  END CASE;

  -- Tentukan status berdasarkan server time
  IF v_current_hour < v_session_start THEN
    RETURN jsonb_build_object('success', false, 'error', 'Waktu minum obat belum tiba');
  ELSIF v_current_hour >= v_session_start AND v_current_hour < v_session_end THEN
    v_status := 'taken';
  ELSE
    v_status := 'late';  -- Masih bisa input, tapi dicatat terlambat
  END IF;

  -- Cek apakah sudah ada log hari ini
  SELECT * INTO v_existing
  FROM public.medication_logs
  WHERE patient_id = p_patient_id
    AND log_date = v_log_date
    AND session = p_session;

  IF FOUND AND v_existing.status = 'taken' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Obat sudah dicatat hari ini');
  END IF;

  -- Upsert log
  INSERT INTO public.medication_logs (patient_id, log_date, session, status, taken_at)
  VALUES (p_patient_id, v_log_date, p_session, v_status, NOW())
  ON CONFLICT (patient_id, log_date, session)
  DO UPDATE SET status = EXCLUDED.status, taken_at = EXCLUDED.taken_at;

  RETURN jsonb_build_object('success', true, 'status', v_status);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.log_medication_taken IS 'Catat minum obat dengan server time. Status auto: taken atau late';


-- ============================================================
-- RPC: get_today_medication_status
-- Get status 3 sesi obat hari ini beserta apakah sesi sudah aktif
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_today_medication_status(
  p_patient_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_server_time   TIMESTAMPTZ := NOW() AT TIME ZONE 'Asia/Jakarta';
  v_current_hour  SMALLINT := EXTRACT(HOUR FROM v_server_time);
  v_today         DATE := v_server_time::DATE;

  -- Status dari DB
  v_morning_log   public.medication_logs;
  v_afternoon_log public.medication_logs;
  v_evening_log   public.medication_logs;

  -- Helper function
  v_result        JSONB;
BEGIN
  SELECT * INTO v_morning_log   FROM public.medication_logs
    WHERE patient_id = p_patient_id AND log_date = v_today AND session = 'morning';
  SELECT * INTO v_afternoon_log FROM public.medication_logs
    WHERE patient_id = p_patient_id AND log_date = v_today AND session = 'afternoon';
  SELECT * INTO v_evening_log   FROM public.medication_logs
    WHERE patient_id = p_patient_id AND log_date = v_today AND session = 'evening';

  -- Fungsi helper untuk compute display_status
  -- locked: belum waktunya
  -- active: sedang dalam window waktu
  -- taken: sudah minum
  -- late: window sudah lewat tapi belum minum
  -- missed: sudah lebih dari 2 jam setelah window berakhir

  v_result := jsonb_build_array(
    jsonb_build_object(
      'session',       'morning',
      'label',         'Pagi',
      'window',        '06:00 - 09:00',
      'status',        CASE
                         WHEN v_morning_log.status IS NOT NULL THEN v_morning_log.status
                         WHEN v_current_hour < 6  THEN 'locked'
                         WHEN v_current_hour BETWEEN 6 AND 8 THEN 'active'
                         WHEN v_current_hour BETWEEN 9 AND 10 THEN 'late'
                         ELSE 'missed'
                       END,
      'taken_at',      v_morning_log.taken_at
    ),
    jsonb_build_object(
      'session',       'afternoon',
      'label',         'Siang',
      'window',        '13:00 - 15:00',
      'status',        CASE
                         WHEN v_afternoon_log.status IS NOT NULL THEN v_afternoon_log.status
                         WHEN v_current_hour < 13 THEN 'locked'
                         WHEN v_current_hour BETWEEN 13 AND 14 THEN 'active'
                         WHEN v_current_hour BETWEEN 15 AND 16 THEN 'late'
                         ELSE 'missed'
                       END,
      'taken_at',      v_afternoon_log.taken_at
    ),
    jsonb_build_object(
      'session',       'evening',
      'label',         'Malam',
      'window',        '18:00 - 21:00',
      'status',        CASE
                         WHEN v_evening_log.status IS NOT NULL THEN v_evening_log.status
                         WHEN v_current_hour < 18 THEN 'locked'
                         WHEN v_current_hour BETWEEN 18 AND 20 THEN 'active'
                         WHEN v_current_hour BETWEEN 21 AND 22 THEN 'late'
                         ELSE 'missed'
                       END,
      'taken_at',      v_evening_log.taken_at
    )
  );

  RETURN jsonb_build_object(
    'success',       true,
    'server_time',   v_server_time,
    'sessions',      v_result
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_today_medication_status IS 'Get status obat hari ini (3 sesi) berdasarkan server time WIB';


-- ============================================================
-- RPC: log_daily_symptoms
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_daily_symptoms(
  p_patient_id            UUID,
  p_nausea_level          SMALLINT DEFAULT 0,
  p_dizziness_level       SMALLINT DEFAULT 0,
  p_fatigue_level         SMALLINT DEFAULT 0,
  p_hemoptysis            BOOLEAN DEFAULT FALSE,
  p_chest_pain            BOOLEAN DEFAULT FALSE,
  p_shortness_of_breath   BOOLEAN DEFAULT FALSE,
  p_notes                 TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_today         DATE := (NOW() AT TIME ZONE 'Asia/Jakarta')::DATE;
  v_is_emergency  BOOLEAN;
BEGIN
  v_is_emergency := p_hemoptysis OR p_chest_pain OR p_shortness_of_breath;

  INSERT INTO public.symptom_logs (
    patient_id, log_date,
    nausea_level, dizziness_level, fatigue_level,
    hemoptysis, chest_pain, shortness_of_breath,
    notes
  )
  VALUES (
    p_patient_id, v_today,
    p_nausea_level, p_dizziness_level, p_fatigue_level,
    p_hemoptysis, p_chest_pain, p_shortness_of_breath,
    p_notes
  )
  ON CONFLICT (patient_id, log_date)
  DO UPDATE SET
    nausea_level          = EXCLUDED.nausea_level,
    dizziness_level       = EXCLUDED.dizziness_level,
    fatigue_level         = EXCLUDED.fatigue_level,
    hemoptysis            = EXCLUDED.hemoptysis,
    chest_pain            = EXCLUDED.chest_pain,
    shortness_of_breath   = EXCLUDED.shortness_of_breath,
    notes                 = EXCLUDED.notes;

  -- Jika emergency, auto-kirim notifikasi ke dokter (via notifications table)
  IF v_is_emergency THEN
    INSERT INTO public.notifications (patient_id, type, title, body, payload)
    SELECT
      p_patient_id,
      'emergency_ack',
      '🚨 Laporan Darurat',
      'Pasien melaporkan gejala kritis. Segera periksa!',
      jsonb_build_object('log_date', v_today, 'hemoptysis', p_hemoptysis,
                         'chest_pain', p_chest_pain, 'shortness_of_breath', p_shortness_of_breath);
  END IF;

  RETURN jsonb_build_object(
    'success',      true,
    'is_emergency', v_is_emergency,
    'log_date',     v_today
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- RPC: log_weight
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_weight(
  p_patient_id  UUID,
  p_weight_kg   NUMERIC,
  p_notes       TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_today DATE := (NOW() AT TIME ZONE 'Asia/Jakarta')::DATE;
BEGIN
  INSERT INTO public.weight_logs (patient_id, log_date, weight_kg, notes)
  VALUES (p_patient_id, v_today, p_weight_kg, p_notes)
  ON CONFLICT (patient_id, log_date)
  DO UPDATE SET weight_kg = EXCLUDED.weight_kg, notes = EXCLUDED.notes;

  RETURN jsonb_build_object('success', true, 'weight_kg', p_weight_kg);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- RPC: get_patient_notifications
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_patient_notifications(
  p_patient_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_notifications JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',         id,
      'type',       type,
      'title',      title,
      'body',       body,
      'is_read',    is_read,
      'created_at', created_at
    ) ORDER BY created_at DESC
  )
  INTO v_notifications
  FROM public.notifications
  WHERE patient_id = p_patient_id
  LIMIT 50;

  -- Mark as read
  UPDATE public.notifications
  SET is_read = TRUE
  WHERE patient_id = p_patient_id AND is_read = FALSE;

  RETURN COALESCE(v_notifications, '[]'::JSONB);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- RPC: request_visit_reschedule
-- ============================================================
CREATE OR REPLACE FUNCTION public.request_visit_reschedule(
  p_visit_id    UUID,
  p_patient_id  UUID,
  p_new_date    DATE,
  p_reason      TEXT
)
RETURNS JSONB AS $$
BEGIN
  UPDATE public.clinic_visits
  SET
    reschedule_requested  = TRUE,
    reschedule_reason     = p_reason,
    reschedule_to_date    = p_new_date,
    updated_at            = NOW()
  WHERE id = p_visit_id
    AND patient_id = p_patient_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Jadwal tidak ditemukan');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- CRON JOB: Auto-mark missed medications (via pg_cron / Edge Function)
-- Jalankan setiap hari jam 23:00 WIB
-- Tandai semua sesi yang belum ada lognya sebagai 'missed'
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_missed_medications()
RETURNS VOID AS $$
DECLARE
  v_today DATE := (NOW() AT TIME ZONE 'Asia/Jakarta')::DATE;
  v_session TEXT;
BEGIN
  FOREACH v_session IN ARRAY ARRAY['morning', 'afternoon', 'evening']
  LOOP
    INSERT INTO public.medication_logs (patient_id, log_date, session, status)
    SELECT p.id, v_today, v_session, 'missed'
    FROM public.patients p
    WHERE p.status = 'active'
      AND p.is_activated = TRUE
      AND NOT EXISTS (
        SELECT 1 FROM public.medication_logs ml
        WHERE ml.patient_id = p.id
          AND ml.log_date = v_today
          AND ml.session = v_session
      )
    ON CONFLICT (patient_id, log_date, session) DO NOTHING;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.mark_missed_medications IS
  'Dipanggil setiap malam jam 23:00 via pg_cron atau Supabase Edge Function cron';

-- Setup pg_cron (aktifkan di Supabase Dashboard → Database → Extensions → pg_cron)
-- SELECT cron.schedule('mark-missed-meds', '0 16 * * *', 'SELECT public.mark_missed_medications()');
-- (16 UTC = 23 WIB)