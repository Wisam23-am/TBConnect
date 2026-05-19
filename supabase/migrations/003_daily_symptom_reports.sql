-- ============================================================
-- TBConnect Migration 003: Daily Symptom Reports
-- Jalankan di Supabase SQL Editor
-- ============================================================

-- 1. Create daily_symptom_reports table
CREATE TABLE IF NOT EXISTS daily_symptom_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  report_date DATE NOT NULL DEFAULT CURRENT_DATE,
  mood_level TEXT NOT NULL CHECK (mood_level IN ('sangat_buruk', 'kurang_baik', 'cukup_baik', 'sangat_baik')),
  symptoms TEXT[] DEFAULT '{}',
  emergency_symptoms TEXT[] DEFAULT '{}',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(patient_id, report_date)
);

-- 2. RPC: Save daily symptom report (upsert)
CREATE OR REPLACE FUNCTION save_daily_symptom_report(
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
AS $$
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
$$;

-- 3. RPC: Get daily symptom reports for a patient
CREATE OR REPLACE FUNCTION get_daily_symptom_reports(
  p_patient_id UUID,
  p_limit INT DEFAULT 7
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

-- 4. RPC: Get today's report for a patient (if exists)
CREATE OR REPLACE FUNCTION get_today_symptom_report(
  p_patient_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

-- 5. Enable Row Level Security
ALTER TABLE daily_symptom_reports ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies

-- Policy: Doctor can read reports of their own patients
CREATE POLICY doctor_read_reports ON daily_symptom_reports
  FOR SELECT
  TO authenticated
  USING (
    patient_id IN (
      SELECT id FROM patients
      WHERE doctor_id = auth.uid()
    )
  );

-- Policy: Doctor can insert reports for their patients
CREATE POLICY doctor_insert_reports ON daily_symptom_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (
    patient_id IN (
      SELECT id FROM patients
      WHERE doctor_id = auth.uid()
    )
  );

-- Policy: Doctor can update reports for their patients
CREATE POLICY doctor_update_reports ON daily_symptom_reports
  FOR UPDATE
  TO authenticated
  USING (
    patient_id IN (
      SELECT id FROM patients
      WHERE doctor_id = auth.uid()
    )
  );

-- Note: Pasien menggunakan SECURITY DEFINER RPC (bypass RLS),
-- sehingga tidak perlu policy untuk pasien.

-- 7. Grant execute permissions (for anon role — pasien via RPC)
GRANT EXECUTE ON FUNCTION save_daily_symptom_report TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_daily_symptom_reports TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_today_symptom_report TO authenticated, anon;
