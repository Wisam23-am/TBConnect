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
'location', cv.location,
'visit_number', cv.visit_number,
'status', cv.status
) ORDER BY cv.scheduled_date ASC
)
INTO v_result
FROM public.clinic_visits cv
WHERE cv.patient_id = p_patient_id
AND cv.status = 'upcoming'
LIMIT 1;

RETURN COALESCE(v_result, '[]'::JSONB);
END;

$$
LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_upcoming_visits IS 'RPC: Ambil jadwal kontrol mendatang untuk pasien (bypass RLS)';


-- ============================================================
-- RPC: log_medication_taken
-- Dipanggil pasien saat tap "Minum Obat"
-- Diperbarui untuk mendukung p_log_date untuk navigasi tanggal
-- dan p_reason jika melapor terlambat.
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_medication_taken(
  p_patient_id  UUID,
  p_session     TEXT,
  p_reason      TEXT DEFAULT NULL,
  p_log_date    DATE DEFAULT NULL
)
RETURNS JSONB AS
$$

DECLARE
v_server_time TIMESTAMPTZ := NOW() AT TIME ZONE 'Asia/Jakarta';
v_current_hour SMALLINT := EXTRACT(HOUR FROM v_server_time);
v_today DATE := v_server_time::DATE;
v_target_date DATE := COALESCE(p_log_date, v_today);
v_status TEXT;
v_session_start SMALLINT;
v_session_end SMALLINT;
v_existing public.medication_logs;
BEGIN
-- Validasi session dan jam aktif (WIB)
CASE p_session
WHEN 'morning' THEN v_session_start := 6; v_session_end := 9;
WHEN 'afternoon' THEN v_session_start := 13; v_session_end := 15;
WHEN 'evening' THEN v_session_start := 18; v_session_end := 21;
ELSE RETURN jsonb_build_object('success', false, 'error', 'Session tidak valid');
END CASE;

-- Tentukan status
IF v_target_date < v_today THEN
-- Jika target adalah masa lalu, maka statusnya selalu 'late' (telat lapor)
v_status := 'late';
ELSIF v_target_date = v_today THEN
-- Hari ini, gunakan logika jam
IF v_current_hour < v_session_start THEN
RETURN jsonb_build_object('success', false, 'error', 'Waktu minum obat belum tiba');
ELSIF v_current_hour >= v_session_start AND v_current_hour < v_session_end THEN
v_status := 'taken';
ELSE
v_status := 'late';
END IF;
ELSE
RETURN jsonb_build_object('success', false, 'error', 'Tidak bisa mengisi untuk tanggal di masa depan');
END IF;

-- Cek apakah sudah ada log
SELECT \* INTO v_existing
FROM public.medication_logs
WHERE patient_id = p_patient_id
AND log_date = v_target_date
AND session = p_session;

IF FOUND AND v_existing.status = 'taken' THEN
RETURN jsonb_build_object('success', false, 'error', 'Obat sudah dicatat pada tanggal tersebut');
END IF;

-- Upsert log
INSERT INTO public.medication_logs (patient_id, log_date, session, status, taken_at, late_reason)
VALUES (p_patient_id, v_target_date, p_session, v_status, NOW(), p_reason)
ON CONFLICT (patient_id, log_date, session)
DO UPDATE SET status = EXCLUDED.status, taken_at = EXCLUDED.taken_at, late_reason = EXCLUDED.late_reason;

RETURN jsonb_build_object('success', true, 'status', v_status, 'log_date', v_target_date);
END;

$$
LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.log_medication_taken IS 'Catat minum obat (mendukung navigasi tanggal & alasan telat)';


-- ============================================================
-- RPC: get_today_medication_status
-- Get status 3 sesi obat hari ini atau tanggal tertentu
-- Diperbarui untuk mendukung p_target_date untuk navigasi tanggal
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_today_medication_status(
  p_patient_id UUID,
  p_target_date DATE DEFAULT NULL
)
RETURNS JSONB AS
$$

DECLARE
v_server_time TIMESTAMPTZ := NOW() AT TIME ZONE 'Asia/Jakarta';
v_current_hour SMALLINT := EXTRACT(HOUR FROM v_server_time);
v_today DATE := v_server_time::DATE;
v_date DATE := COALESCE(p_target_date, v_today);

v_morning_log public.medication_logs;
v_afternoon_log public.medication_logs;
v_evening_log public.medication_logs;

v*result JSONB;
BEGIN
SELECT * INTO v*morning_log FROM public.medication_logs
WHERE patient_id = p_patient_id AND log_date = v_date AND session = 'morning';
SELECT * INTO v_afternoon_log FROM public.medication_logs
WHERE patient_id = p_patient_id AND log_date = v_date AND session = 'afternoon';
SELECT \* INTO v_evening_log FROM public.medication_logs
WHERE patient_id = p_patient_id AND log_date = v_date AND session = 'evening';

v_result := jsonb_build_array(
jsonb_build_object(
'session', 'morning',
'label', 'Pagi',
'window', '06:00 - 09:00',
'status', CASE
WHEN v_morning_log.status IS NOT NULL THEN v_morning_log.status
WHEN v_date < v_today THEN 'missed'
WHEN v_date > v_today THEN 'locked'
WHEN v_current_hour < 6 THEN 'locked'
WHEN v_current_hour BETWEEN 6 AND 8 THEN 'active'
WHEN v_current_hour BETWEEN 9 AND 10 THEN 'late'
ELSE 'missed'
END,
'taken_at', v_morning_log.taken_at
),
jsonb_build_object(
'session', 'afternoon',
'label', 'Siang',
'window', '13:00 - 15:00',
'status', CASE
WHEN v_afternoon_log.status IS NOT NULL THEN v_afternoon_log.status
WHEN v_date < v_today THEN 'missed'
WHEN v_date > v_today THEN 'locked'
WHEN v_current_hour < 13 THEN 'locked'
WHEN v_current_hour BETWEEN 13 AND 14 THEN 'active'
WHEN v_current_hour BETWEEN 15 AND 16 THEN 'late'
ELSE 'missed'
END,
'taken_at', v_afternoon_log.taken_at
),
jsonb_build_object(
'session', 'evening',
'label', 'Malam',
'window', '18:00 - 21:00',
'status', CASE
WHEN v_evening_log.status IS NOT NULL THEN v_evening_log.status
WHEN v_date < v_today THEN 'missed'
WHEN v_date > v_today THEN 'locked'
WHEN v_current_hour < 18 THEN 'locked'
WHEN v_current_hour BETWEEN 18 AND 20 THEN 'active'
WHEN v_current_hour BETWEEN 21 AND 22 THEN 'late'
ELSE 'missed'
END,
'taken_at', v_evening_log.taken_at
)
);

RETURN jsonb_build_object(
'success', true,
'server_time', v_server_time,
'target_date', v_date,
'sessions', v_result
);
END;

$$
LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_today_medication_status IS 'Get status obat hari ini / tanggal tertentu (3 sesi) berdasarkan server time WIB';



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
RETURNS JSONB AS
$$

DECLARE
v_today DATE := (NOW() AT TIME ZONE 'Asia/Jakarta')::DATE;
v_is_emergency BOOLEAN;
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
nausea_level = EXCLUDED.nausea_level,
dizziness_level = EXCLUDED.dizziness_level,
fatigue_level = EXCLUDED.fatigue_level,
hemoptysis = EXCLUDED.hemoptysis,
chest_pain = EXCLUDED.chest_pain,
shortness_of_breath = EXCLUDED.shortness_of_breath,
notes = EXCLUDED.notes;

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
'success', true,
'is_emergency', v_is_emergency,
'log_date', v_today
);
END;

$$
LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- RPC: log_weight
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_weight(
  p_patient_id  UUID,
  p_weight_kg   NUMERIC,
  p_notes       TEXT DEFAULT NULL
)
RETURNS JSONB AS
$$

DECLARE
v_today DATE := (NOW() AT TIME ZONE 'Asia/Jakarta')::DATE;
BEGIN
INSERT INTO public.weight_logs (patient_id, log_date, weight_kg, notes)
VALUES (p_patient_id, v_today, p_weight_kg, p_notes)
ON CONFLICT (patient_id, log_date)
DO UPDATE SET weight_kg = EXCLUDED.weight_kg, notes = EXCLUDED.notes;

RETURN jsonb_build_object('success', true, 'weight_kg', p_weight_kg);
END;

$$
LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- RPC: get_patient_notifications
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_patient_notifications(
  p_patient_id UUID
)
RETURNS JSONB AS
$$

DECLARE
v_notifications JSONB;
BEGIN
SELECT jsonb_agg(
jsonb_build_object(
'id', id,
'type', type,
'title', title,
'body', body,
'is_read', is_read,
'created_at', created_at
) ORDER BY created_at DESC
)
INTO v_notifications
FROM public.notifications
WHERE patient_id = p_patient_id
LIMIT 50;

RETURN COALESCE(v_notifications, '[]'::JSONB);
END;

$$
LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_patient_notifications IS 'Ambil notifikasi pasien tanpa mengubah status baca; mark-read dilakukan terpisah saat user tap item.';


-- ============================================================
-- RPC: mark_notification_read
-- Tandai satu notifikasi sebagai sudah dibaca
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_notification_read(
  p_notif_id UUID
)
RETURNS JSONB AS
$$

DECLARE
v_updated INTEGER;
BEGIN
UPDATE public.notifications
SET is_read = TRUE
WHERE id = p_notif_id;

GET DIAGNOSTICS v_updated = ROW_COUNT;

IF v_updated = 0 THEN
RETURN jsonb_build_object('success', false, 'error', 'Notifikasi tidak ditemukan');
END IF;

RETURN jsonb_build_object('success', true, 'notification_id', p_notif_id);
END;

$$
LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.mark_notification_read IS 'Tandai notifikasi pasien sebagai sudah dibaca.';


-- Compat overload untuk client yang masih mengirim patient_id + notif_id
CREATE OR REPLACE FUNCTION public.mark_notification_read(
  p_patient_id UUID,
  p_notification_id UUID
)
RETURNS JSONB AS
$$

BEGIN
PERFORM public.mark_notification_read(p_notification_id);
RETURN jsonb_build_object('success', true, 'notification_id', p_notification_id);
END;

$$
LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- RPC: request_visit_reschedule
-- ============================================================
CREATE OR REPLACE FUNCTION public.request_visit_reschedule(
  p_visit_id    UUID,
  p_patient_id  UUID,
  p_new_date    DATE,
  p_reason      TEXT
)
RETURNS JSONB AS
$$

BEGIN
UPDATE public.clinic_visits
SET
reschedule_requested = TRUE,
reschedule_reason = p_reason,
reschedule_to_date = p_new_date,
updated_at = NOW()
WHERE id = p_visit_id
AND patient_id = p_patient_id;

IF NOT FOUND THEN
RETURN jsonb_build_object('success', false, 'error', 'Jadwal tidak ditemukan');
END IF;

RETURN jsonb_build_object('success', true);
END;

$$
LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- CRON JOB: Auto-mark missed medications (via pg_cron / Edge Function)
-- Jalankan setiap hari jam 23:00 WIB
-- Tandai semua sesi yang belum ada lognya sebagai 'missed'
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_missed_medications()
RETURNS VOID AS
$$

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

$$
LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.mark_missed_medications IS
  'Dipanggil setiap malam jam 23:00 via pg_cron atau Supabase Edge Function cron';

-- Setup pg_cron (aktifkan di Supabase Dashboard → Database → Extensions → pg_cron)
-- SELECT cron.schedule('mark-missed-meds', '0 16 * * *', 'SELECT public.mark_missed_medications()');
-- (16 UTC = 23 WIB)


-- ============================================================
-- RPC: send_patient_reminder
-- Dokter mengirim pengingat manual ke pasien yang terlambat minum obat
-- ============================================================
CREATE OR REPLACE FUNCTION public.send_patient_reminder(
  p_patient_id UUID
)
RETURNS JSONB AS
$$

DECLARE
v_patient_exists BOOLEAN;
BEGIN
-- Validasi apakah pasien ada dan merupakan milik dokter yang sedang login
SELECT EXISTS(
SELECT 1 FROM public.patients
WHERE id = p_patient_id AND doctor_id = auth.uid()
) INTO v_patient_exists;

IF NOT v_patient_exists THEN
RETURN jsonb_build_object('success', false, 'error', 'Pasien tidak ditemukan atau bukan milik Anda');
END IF;

-- Insert notifikasi baru
INSERT INTO public.notifications (
patient_id,
type,
title,
body,
is_sent,
is_read
)
VALUES (
p_patient_id,
'medication_reminder',
'Pengingat Minum Obat dari Dokter',
'Dokter Anda memperhatikan Anda belum mengisi log obat hari ini. Segera minum obat dan konfirmasi di aplikasi.',
FALSE,
FALSE
);

RETURN jsonb_build_object('success', true, 'message', 'Pengingat berhasil dikirim');
END;

$$
LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.send_patient_reminder IS 'Dipanggil oleh dokter untuk mengirim notifikasi pengingat ke pasien.';


-- ============================================================
-- RPC: get_patient_profile
-- Ambil profil lengkap pasien beserta data dokter pembinanya
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_patient_profile(
  p_patient_id UUID
)
RETURNS JSON AS
$$

DECLARE
v_result JSON;
BEGIN
SELECT json_build_object(
'id', p.id,
'full_name', p.full_name,
'nik', p.nik,
'birth_place', p.birth_place,
'birth_date', p.birth_date,
'age', p.age,
'gender', p.gender,
'initial_weight_kg', p.initial_weight_kg,
'treatment_start_date', p.treatment_start_date,
'phone_number', p.phone_number,
'address', p.address,
'faskes_name', p.faskes_name,
'doctors', json_build_object(
'full_name', d.full_name,
'hospital_name', d.hospital_name
)
) INTO v_result
FROM public.patients p
LEFT JOIN public.doctors d ON d.id = p.doctor_id
WHERE p.id = p_patient_id;

    RETURN v_result;

END;

$$
LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_patient_profile IS 'Ambil profil lengkap pasien beserta data dokter pembinanya (bypass RLS)';


-- ============================================================
-- RPC: save_daily_symptom_report
-- Simpan laporan gejala harian pasien (mood, gejala, catatan)
-- ============================================================
CREATE OR REPLACE FUNCTION public.save_daily_symptom_report(
  p_patient_id UUID,
  p_mood_level TEXT,
  p_symptoms TEXT[] DEFAULT '{}',
  p_emergency_symptoms TEXT[] DEFAULT '{}',
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS
$$

DECLARE
v_today DATE := CURRENT_DATE;
v_result JSONB;
BEGIN
INSERT INTO daily_symptom_reports (patient_id, report_date, mood_level, symptoms, emergency_symptoms, notes)
VALUES (p_patient_id, v_today, p_mood_level, p_symptoms, p_emergency_symptoms, p_notes)
ON CONFLICT (patient_id, report_date)
DO UPDATE SET
mood_level = EXCLUDED.mood_level,
symptoms = EXCLUDED.symptoms,
emergency_symptoms = EXCLUDED.emergency_symptoms,
notes = COALESCE(EXCLUDED.notes, daily_symptom_reports.notes),
created_at = NOW()
RETURNING jsonb_build_object(
'id', id,
'patient_id', patient_id,
'report_date', report_date,
'mood_level', mood_level,
'symptoms', symptoms,
'emergency_symptoms', emergency_symptoms,
'notes', notes,
'created_at', created_at
) INTO v_result;

RETURN jsonb_build_object('success', true, 'data', v_result);
END;

$$
;

COMMENT ON FUNCTION public.save_daily_symptom_report IS 'Simpan laporan gejala harian pasien (bypass RLS)';


-- ============================================================
-- RPC: get_daily_symptom_reports
-- Ambil daftar laporan gejala harian pasien terakhir
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_daily_symptom_reports(
  p_patient_id UUID,
  p_limit INT DEFAULT 7
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS
$$

DECLARE
v_reports JSONB;
BEGIN
SELECT jsonb_agg(
jsonb_build_object(
'id', dsr.id,
'report_date', dsr.report_date,
'mood_level', dsr.mood_level,
'symptoms', dsr.symptoms,
'emergency_symptoms', dsr.emergency_symptoms,
'notes', dsr.notes,
'created_at', dsr.created_at
)
ORDER BY dsr.report_date DESC
) INTO v_reports
FROM daily_symptom_reports dsr
WHERE dsr.patient_id = p_patient_id
LIMIT p_limit;

RETURN jsonb_build_object('success', true, 'reports', COALESCE(v_reports, '[]'::JSONB));
END;

$$
;

COMMENT ON FUNCTION public.get_daily_symptom_reports IS 'Ambil daftar laporan gejala harian pasien terakhir (bypass RLS)';


-- ============================================================
-- RPC: get_today_symptom_report
-- Ambil laporan gejala hari ini milik pasien jika ada
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_today_symptom_report(
  p_patient_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS
$$

DECLARE
v_today DATE := CURRENT_DATE;
v_result JSONB;
BEGIN
SELECT jsonb_build_object(
'id', dsr.id,
'report_date', dsr.report_date,
'mood_level', dsr.mood_level,
'symptoms', dsr.symptoms,
'emergency_symptoms', dsr.emergency_symptoms,
'notes', dsr.notes,
'created_at', dsr.created_at
) INTO v_result
FROM daily_symptom_reports dsr
WHERE dsr.patient_id = p_patient_id
AND dsr.report_date = v_today;

IF v_result IS NULL THEN
RETURN jsonb_build_object('success', true, 'data', null);
END IF;

RETURN jsonb_build_object('success', true, 'data', v_result);
END;

$$
;

COMMENT ON FUNCTION public.get_today_symptom_report IS 'Ambil laporan gejala hari ini milik pasien (bypass RLS)';
$$
