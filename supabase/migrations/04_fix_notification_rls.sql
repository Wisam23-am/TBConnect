-- ============================================================
-- Fix RLS: Izinkan Dokter melakukan INSERT ke tabel notifications
-- ============================================================

CREATE POLICY "doctors: insert notifications for own patients"
  ON public.notifications FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.patients p
      WHERE p.id = notifications.patient_id
        AND p.doctor_id = auth.uid()
    )
  );
