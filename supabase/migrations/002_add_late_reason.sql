-- ============================================================
-- TBConnect Migration 002: Add late_reason column
-- Jalankan di Supabase SQL Editor
-- ============================================================

-- 1. Tambah kolom late_reason ke medication_logs
ALTER TABLE medication_logs
ADD COLUMN IF NOT EXISTS late_reason TEXT;

-- 2. Buat RPC untuk log minum obat (dengan alasan opsional)
--    (drop dulu yang lama jika ada)
CREATE OR REPLACE FUNCTION log_medication_taken(
  p_patient_id UUID,
  p_session TEXT,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today DATE := CURRENT_DATE;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  -- Upsert: insert jika belum ada, update jika sudah ada
  -- Jika sudah ada entri dengan late_reason dan user mencoba memberikan alasan baru, tolak
  IF EXISTS(SELECT 1 FROM medication_logs WHERE patient_id = p_patient_id AND log_date = v_today AND session = p_session AND late_reason IS NOT NULL) AND p_reason IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Late reason sudah dicatat');
  END IF;

  INSERT INTO medication_logs (patient_id, log_date, session, status, taken_at, late_reason)
  VALUES (p_patient_id, v_today, p_session, 'taken', v_now, p_reason)
  ON CONFLICT (patient_id, log_date, session)
  DO UPDATE SET
    status = 'taken',
    taken_at = v_now,
    late_reason = COALESCE(medication_logs.late_reason, EXCLUDED.late_reason);

  RETURN jsonb_build_object('success', true);
END;
$$;

-- 3. Buat RPC untuk mengambil status obat hari ini
--    (perbarui agar menyertakan late_reason)
CREATE OR REPLACE FUNCTION get_today_medication_status(
  p_patient_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today DATE := CURRENT_DATE;
  v_sessions JSONB;
  v_server_time TEXT;
BEGIN
  v_server_time := NOW()::TEXT;

  -- Ambil data session dari tabel referensi atau hardcode
  WITH session_defs AS (
    SELECT 'morning' AS session, 'Pagi' AS label, '06:00 - 09:00' AS window
    UNION ALL
    SELECT 'afternoon', 'Siang', '13:00 - 15:00'
    UNION ALL
    SELECT 'evening', 'Malam', '18:00 - 21:00'
  ),
  logs AS (
    SELECT *
    FROM medication_logs
    WHERE patient_id = p_patient_id
      AND log_date = v_today
  )
  SELECT jsonb_agg(
    jsonb_build_object(
      'session', sd.session,
      'label', sd.label,
      'window', sd.window,
      'status', COALESCE(
        CASE
          WHEN l.status IS NOT NULL THEN l.status
          WHEN EXTRACT(HOUR FROM NOW()) < SPLIT_PART(sd.window, ':', 1)::INT THEN 'locked'
          WHEN EXTRACT(HOUR FROM NOW()) BETWEEN SPLIT_PART(sd.window, ':', 1)::INT
            AND SPLIT_PART(SPLIT_PART(sd.window, ' - ', 2), ':', 1)::INT THEN 'active'
          WHEN EXTRACT(HOUR FROM NOW()) >= SPLIT_PART(SPLIT_PART(sd.window, ' - ', 2), ':', 1)::INT
            AND l.status IS NULL THEN 'missed'
          ELSE 'locked'
        END, 'locked'
      ),
      'taken_at', l.taken_at::TEXT,
      'late_reason', l.late_reason
    )
    ORDER BY sd.session
  ) INTO v_sessions
  FROM session_defs sd
  LEFT JOIN logs l ON l.session = sd.session;

  RETURN jsonb_build_object(
    'success', true,
    'server_time', v_server_time,
    'sessions', COALESCE(v_sessions, '[]'::JSONB)
  );
END;
$$;
