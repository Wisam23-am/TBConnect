-- ============================================================
-- TBConnect - Get Weight History RPC
-- ============================================================

-- Fungsi ini dibuat dengan SECURITY DEFINER agar dapat bypass RLS (Row Level Security) 
-- pada tabel weight_logs, karena pasien hanya memiliki akses via RPC.

DROP FUNCTION IF EXISTS public.get_patient_weight_history(UUID, INT);

CREATE OR REPLACE FUNCTION public.get_patient_weight_history(
  p_patient_id UUID,
  p_limit INT DEFAULT 10
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', id,
      'log_date', log_date,
      'weight_kg', weight_kg,
      'day_of_treatment', day_of_treatment,
      'created_at', created_at
    )
  )
  INTO v_result
  FROM (
    SELECT *
    FROM public.weight_logs
    WHERE patient_id = p_patient_id
    ORDER BY log_date DESC
    LIMIT p_limit
  ) AS recent_logs;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
