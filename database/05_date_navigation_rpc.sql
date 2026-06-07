-- ============================================================
-- TBConnect - Date Navigation RPC Updates
-- File: database/05_date_navigation_rpc.sql
-- ============================================================

-- 1. Hapus fungsi lama untuk mencegah bentrokan (PGRST203)
DROP FUNCTION IF EXISTS public.log_medication_taken(UUID, TEXT);
DROP FUNCTION IF EXISTS public.log_medication_taken(UUID, TEXT, TEXT);

-- Update log_medication_taken to accept p_reason and p_log_date
CREATE OR REPLACE FUNCTION public.log_medication_taken(
  p_patient_id  UUID,
  p_session     TEXT,
  p_reason      TEXT DEFAULT NULL,
  p_log_date    DATE DEFAULT NULL
)
RETURNS JSONB AS $$
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
  -- Validasi session dan jam aktif (WIB)
  -- Morning: 06:00-09:00 (active), 09:00-13:00 (late window), 13:00+ (locked/next session)
  -- Afternoon: 13:00-16:00 (active), 16:00-18:00 (late window), 18:00+ (locked/next session)
  -- Evening: 18:00-22:00 (active), 22:00+ (late window until midnight)
  CASE p_session
    WHEN 'morning'   THEN v_session_start := 6;  v_session_end := 9;
    WHEN 'afternoon' THEN v_session_start := 13; v_session_end := 16;
    WHEN 'evening'   THEN v_session_start := 18; v_session_end := 22;
    ELSE RETURN jsonb_build_object('success', false, 'error', 'Session tidak valid');
  END CASE;

  -- Tentukan status dan validasi window
  IF v_target_date < v_today THEN
    -- Jika target adalah masa lalu, maka statusnya selalu 'late' (telat lapor)
    v_status := 'late';
  ELSIF v_target_date = v_today THEN
    -- Hari ini, gunakan logika jam dengan late window
    IF v_current_hour < v_session_start THEN
      RETURN jsonb_build_object('success', false, 'error', 'Waktu minum obat belum tiba');
    ELSIF v_current_hour < v_session_end THEN
      -- Dalam jam normal
      v_status := 'taken';
    ELSIF p_session = 'morning' AND v_current_hour < 13 THEN
      -- Morning late window: 09:00-13:00 (sebelum afternoon dimulai)
      v_status := 'late';
    ELSIF p_session = 'afternoon' AND v_current_hour < 18 THEN
      -- Afternoon late window: 16:00-18:00 (sebelum evening dimulai)
      v_status := 'late';
    ELSIF p_session = 'evening' THEN
      -- Evening late window: 22:00+ (until midnight)
      v_status := 'late';
    ELSE
      RETURN jsonb_build_object('success', false, 'error', 'Window untuk sesi ini sudah ditutup. Tidak boleh double dosing dengan sesi berikutnya.');
    END IF;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Tidak bisa mengisi untuk tanggal di masa depan');
  END IF;

  -- Cek apakah sudah ada log
  SELECT * INTO v_existing
  FROM public.medication_logs
  WHERE patient_id = p_patient_id
    AND log_date = v_target_date
    AND session = p_session;

  IF FOUND AND v_existing.status = 'taken' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Obat sudah dicatat pada tanggal tersebut');
  END IF;

  -- Jika ada existing dan sudah memiliki late_reason, jangan izinkan mengubahnya lagi
  IF FOUND AND v_existing.late_reason IS NOT NULL AND p_reason IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Late reason sudah dicatat');
  END IF;

  -- Upsert log
  INSERT INTO public.medication_logs (patient_id, log_date, session, status, taken_at, late_reason)
  VALUES (p_patient_id, v_target_date, p_session, v_status, NOW(), p_reason)
  ON CONFLICT (patient_id, log_date, session)
  DO UPDATE SET status = EXCLUDED.status,
                taken_at = EXCLUDED.taken_at,
                late_reason = COALESCE(public.medication_logs.late_reason, EXCLUDED.late_reason);

  RETURN jsonb_build_object('success', true, 'status', v_status, 'log_date', v_target_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Hapus fungsi lama untuk mencegah bentrokan (PGRST203)
DROP FUNCTION IF EXISTS public.get_today_medication_status(UUID);

-- Update get_today_medication_status to accept p_target_date
CREATE OR REPLACE FUNCTION public.get_today_medication_status(
  p_patient_id UUID,
  p_target_date DATE DEFAULT NULL
)
RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;
