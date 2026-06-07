-- TBConnect Migration 003: Create get_upcoming_visits RPC
-- Run in Supabase SQL Editor

CREATE OR REPLACE FUNCTION public.get_upcoming_visits(
  p_patient_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
  ) INTO v_result
  FROM public.clinic_visits cv
  WHERE cv.patient_id = p_patient_id
    AND cv.status = 'upcoming';

  RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

COMMENT ON FUNCTION public.get_upcoming_visits IS 'RPC: Ambil jadwal kontrol mendatang untuk pasien (bypass RLS)';
