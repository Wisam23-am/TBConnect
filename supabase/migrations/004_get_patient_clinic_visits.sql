-- ============================================================
-- TBConnect Migration - 004_get_patient_clinic_visits.sql
-- Membuat RPC get_patient_clinic_visits untuk mengambil seluruh
-- jadwal kontrol pasien (bypass RLS karena pasien login custom)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_patient_clinic_visits(
  p_patient_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',                   cv.id,
      'patient_id',           cv.patient_id,
      'doctor_id',            cv.doctor_id,
      'visit_number',         cv.visit_number,
      'scheduled_date',       cv.scheduled_date,
      'location',             cv.location,
      'purpose',              cv.purpose,
      'status',               cv.status,
      'reschedule_requested', cv.reschedule_requested,
      'reschedule_reason',    cv.reschedule_reason,
      'reschedule_to_date',   cv.reschedule_to_date,
      'notes',                cv.notes,
      'created_at',           cv.created_at,
      'updated_at',           cv.updated_at
    ) ORDER BY cv.visit_number ASC
  )
  INTO v_result
  FROM public.clinic_visits cv
  WHERE cv.patient_id = p_patient_id;

  RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_patient_clinic_visits IS 'RPC: Ambil daftar lengkap jadwal kontrol pasien (bypass RLS)';
