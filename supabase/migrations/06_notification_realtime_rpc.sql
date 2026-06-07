-- ============================================================
-- TBConnect - Notification realtime support
-- Memisahkan fetch notifikasi dari mark-as-read agar badge dan polling
-- tetap bisa bekerja tanpa memakan notifikasi saat refresh.
-- ============================================================

-- Fetch notifikasi tanpa auto-mark-read
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
      'created_at', created_at,
      'payload',    payload
    ) ORDER BY created_at DESC
  )
  INTO v_notifications
  FROM public.notifications
  WHERE patient_id = p_patient_id
  LIMIT 50;

  RETURN COALESCE(v_notifications, '[]'::JSONB);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Mark satu notifikasi sebagai sudah dibaca (compatible signature)
CREATE OR REPLACE FUNCTION public.mark_notification_read(
  p_notif_id UUID
)
RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Overload lama untuk client yang sudah mengirim patient_id + notif_id
CREATE OR REPLACE FUNCTION public.mark_notification_read(
  p_patient_id UUID,
  p_notification_id UUID
)
RETURNS JSONB AS $$
BEGIN
  PERFORM public.mark_notification_read(p_notification_id);
  RETURN jsonb_build_object('success', true, 'notification_id', p_notification_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Optional: tandai semua notifikasi pasien sebagai sudah dibaca
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read(
  p_patient_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_updated INTEGER;
BEGIN
  UPDATE public.notifications
  SET is_read = TRUE
  WHERE patient_id = p_patient_id
    AND is_read = FALSE;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  RETURN jsonb_build_object('success', true, 'updated', v_updated);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
