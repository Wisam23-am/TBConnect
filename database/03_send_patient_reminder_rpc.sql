-- ============================================================
-- RPC: send_patient_reminder
-- Dokter mengirim pengingat manual ke pasien yang terlambat minum obat
-- ============================================================

CREATE OR REPLACE FUNCTION public.send_patient_reminder(
  p_patient_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_patient_exists BOOLEAN;
  v_doctor_id UUID;
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.send_patient_reminder IS 'Dipanggil oleh dokter untuk mengirim notifikasi pengingat ke pasien.';
