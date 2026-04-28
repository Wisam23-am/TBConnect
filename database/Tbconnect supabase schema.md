-- ============================================================
-- TBConnect - Supabase Database Schema
-- Platform: Flutter + Supabase
-- Auth: Dokter via Supabase Auth | Pasien via QR Code Activation
-- ============================================================

-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ============================================================
-- TABLE: doctors
-- Profil dokter, linked ke Supabase Auth (auth.users)
-- ============================================================
CREATE TABLE public.doctors (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name     TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  str_number    TEXT NOT NULL UNIQUE,           -- Nomor STR (Surat Tanda Registrasi)
  specialization TEXT DEFAULT 'Paru-Paru',
  hospital_name  TEXT,
  phone_number   TEXT,
  avatar_url     TEXT,
  -- Pengaturan notifikasi dokter
  notif_start_hour  SMALLINT DEFAULT 7,         -- Jam mulai terima notif (0-23)
  notif_end_hour    SMALLINT DEFAULT 21,        -- Jam selesai terima notif (0-23)
  is_active     BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.doctors IS 'Profil dokter yang terintegrasi dengan Supabase Auth';
COMMENT ON COLUMN public.doctors.str_number IS 'Surat Tanda Registrasi - wajib untuk verifikasi profesional medis';


-- ============================================================
-- TABLE: patients
-- Pasien dibuat oleh dokter, TIDAK memiliki akun auth.users
-- Login menggunakan username + password yang dibuat sendiri
-- setelah scan QR dari dokter
-- ============================================================
CREATE TABLE public.patients (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  doctor_id         UUID NOT NULL REFERENCES public.doctors(id) ON DELETE RESTRICT,

  -- Data medis dasar
  full_name         TEXT NOT NULL,
  age               SMALLINT NOT NULL CHECK (age > 0 AND age < 150),
  gender            TEXT CHECK (gender IN ('male', 'female')),
  phone_number      TEXT,
  address           TEXT,

  -- Data pengobatan TBC
  initial_weight_kg  NUMERIC(5,2) NOT NULL,     -- Berat badan awal (kg)
  treatment_start_date DATE NOT NULL,
  treatment_duration_months SMALLINT DEFAULT 6,

  -- Akun pasien (dibuat saat aktivasi QR)
  username          TEXT UNIQUE,                -- Diisi pasien saat aktivasi
  password_hash     TEXT,                       -- bcrypt hash
  is_activated      BOOLEAN DEFAULT FALSE,      -- TRUE setelah pasien scan QR & set password

  -- QR Code
  qr_code           TEXT NOT NULL UNIQUE,       -- Kode unik, contoh: TBC-8899A
  qr_expires_at     TIMESTAMPTZ,               -- Opsional: QR bisa expired

  -- Status pasien
  status            TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'dropout', 'transferred')),

  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW(),
  activated_at      TIMESTAMPTZ                -- Timestamp saat pasien pertama aktivasi
);

COMMENT ON TABLE public.patients IS 'Pasien TBC. Akun dibuat dokter, diaktifkan pasien via scan QR';
COMMENT ON COLUMN public.patients.qr_code IS 'Kode unik format TBC-XXXXX, di-encode jadi QR oleh app';
COMMENT ON COLUMN public.patients.is_activated IS 'False = belum pernah scan QR. True = sudah set username & password';


-- ============================================================
-- TABLE: medication_logs
-- Pencatatan kepatuhan minum obat harian
-- ============================================================
CREATE TABLE public.medication_logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id  UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,

  log_date    DATE NOT NULL,
  session     TEXT NOT NULL CHECK (session IN ('morning', 'afternoon', 'evening')),
  -- morning:   06:00 - 09:00
  -- afternoon: 13:00 - 15:00
  -- evening:   18:00 - 21:00

  status      TEXT NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending', 'taken', 'missed', 'late')),
  taken_at    TIMESTAMPTZ,                     -- Timestamp server saat pasien tap "Minum Obat"
  notes       TEXT,

  created_at  TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE (patient_id, log_date, session)        -- 1 log per pasien per sesi per hari
);

COMMENT ON TABLE public.medication_logs IS 'Log kepatuhan minum obat 3x sehari';
COMMENT ON COLUMN public.medication_logs.taken_at IS 'Menggunakan server time (NOW()) bukan device time';


-- ============================================================
-- TABLE: symptom_logs
-- Monitoring gejala harian pasien
-- ============================================================
CREATE TABLE public.symptom_logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id  UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,

  log_date    DATE NOT NULL,

  -- Gejala umum (skala 0-10, 0 = tidak ada)
  nausea_level      SMALLINT DEFAULT 0 CHECK (nausea_level BETWEEN 0 AND 10),   -- Mual
  dizziness_level   SMALLINT DEFAULT 0 CHECK (dizziness_level BETWEEN 0 AND 10), -- Pusing
  fatigue_level     SMALLINT DEFAULT 0 CHECK (fatigue_level BETWEEN 0 AND 10),  -- Kelelahan

  -- Gejala kritis (boolean flags)
  hemoptysis        BOOLEAN DEFAULT FALSE,  -- Batuk darah (⚠️ CRITICAL)
  chest_pain        BOOLEAN DEFAULT FALSE,  -- Nyeri dada
  shortness_of_breath BOOLEAN DEFAULT FALSE, -- Sesak napas

  -- Flag emergency otomatis jika ada gejala kritis
  is_emergency      BOOLEAN GENERATED ALWAYS AS (hemoptysis OR chest_pain OR shortness_of_breath) STORED,

  notes             TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE (patient_id, log_date)             -- 1 log gejala per hari
);

COMMENT ON TABLE public.symptom_logs IS 'Log gejala harian. is_emergency otomatis True jika ada gejala kritis';


-- ============================================================
-- TABLE: weight_logs
-- Tracking berat badan (tiap 30 hari atau mingguan)
-- ============================================================
CREATE TABLE public.weight_logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id  UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,

  log_date    DATE NOT NULL,
  weight_kg   NUMERIC(5,2) NOT NULL CHECK (weight_kg > 0),
  day_of_treatment INT GENERATED ALWAYS AS (
    -- Dihitung dari treatment_start_date, diisi via trigger
    NULL
  ) STORED,                                -- Akan diisi via trigger (hari ke-berapa pengobatan)
  notes       TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE (patient_id, log_date)
);

-- Ganti kolom generated dengan kolom biasa (lebih fleksibel untuk trigger)
ALTER TABLE public.weight_logs DROP COLUMN day_of_treatment;
ALTER TABLE public.weight_logs ADD COLUMN day_of_treatment INT;

COMMENT ON TABLE public.weight_logs IS 'Tracking berat badan pasien. Input di hari ke-30, 60, 90, dst';


-- ============================================================
-- TABLE: clinic_visits
-- Jadwal kontrol ke klinik/puskesmas
-- ============================================================
CREATE TABLE public.clinic_visits (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id      UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
  doctor_id       UUID NOT NULL REFERENCES public.doctors(id) ON DELETE RESTRICT,

  visit_number    SMALLINT NOT NULL,            -- Kunjungan ke-1, 2, 3, dst
  scheduled_date  DATE NOT NULL,
  location        TEXT NOT NULL,
  purpose         TEXT DEFAULT 'Kontrol & Ambil Obat',

  status          TEXT DEFAULT 'upcoming'
                  CHECK (status IN ('upcoming', 'done', 'missed', 'rescheduled')),

  -- Reschedule request dari pasien
  reschedule_requested BOOLEAN DEFAULT FALSE,
  reschedule_reason    TEXT,
  reschedule_to_date   DATE,

  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.clinic_visits IS 'Jadwal kunjungan kontrol bulanan selama 6 bulan pengobatan';


-- ============================================================
-- TABLE: doctor_feedbacks
-- Feedback/pesan dari dokter ke pasien
-- ============================================================
CREATE TABLE public.doctor_feedbacks (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  doctor_id   UUID NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
  patient_id  UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,

  message     TEXT NOT NULL,
  is_urgent   BOOLEAN DEFAULT FALSE,
  is_read     BOOLEAN DEFAULT FALSE,
  read_at     TIMESTAMPTZ,

  created_at  TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.doctor_feedbacks IS 'Pesan asinkron dari dokter ke pasien';


-- ============================================================
-- TABLE: notifications
-- Push notification log (untuk tracking status kirim)
-- ============================================================
CREATE TABLE public.notifications (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id  UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,

  type        TEXT NOT NULL CHECK (type IN (
                'medication_reminder',   -- Pengingat minum obat
                'doctor_feedback',       -- Ada pesan dari dokter
                'clinic_visit_reminder', -- Jadwal kontrol mendekat
                'weight_input_reminder', -- Saatnya input berat badan
                'emergency_ack'          -- Konfirmasi laporan emergency
              )),
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  payload     JSONB,                     -- Data tambahan (misal: medication_log_id)

  is_sent     BOOLEAN DEFAULT FALSE,
  sent_at     TIMESTAMPTZ,
  is_read     BOOLEAN DEFAULT FALSE,

  created_at  TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.notifications IS 'Log notifikasi push untuk pasien';


-- ============================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================

-- Fungsi: auto update updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger updated_at untuk doctors
CREATE TRIGGER set_doctors_updated_at
  BEFORE UPDATE ON public.doctors
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Trigger updated_at untuk patients
CREATE TRIGGER set_patients_updated_at
  BEFORE UPDATE ON public.patients
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Trigger updated_at untuk clinic_visits
CREATE TRIGGER set_clinic_visits_updated_at
  BEFORE UPDATE ON public.clinic_visits
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- Fungsi: Hitung day_of_treatment saat insert weight_log
CREATE OR REPLACE FUNCTION public.calculate_treatment_day()
RETURNS TRIGGER AS $$
BEGIN
  NEW.day_of_treatment = (NEW.log_date - (
    SELECT treatment_start_date FROM public.patients WHERE id = NEW.patient_id
  ))::INT + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_weight_log_treatment_day
  BEFORE INSERT ON public.weight_logs
  FOR EACH ROW EXECUTE FUNCTION public.calculate_treatment_day();


-- Fungsi: Generate QR Code unik format TBC-XXXXX
CREATE OR REPLACE FUNCTION public.generate_unique_qr_code()
RETURNS TEXT AS $$
DECLARE
  v_code TEXT;
  v_exists BOOLEAN;
BEGIN
  LOOP
    -- Generate format: TBC-XXXXX (5 karakter alphanumeric uppercase)
    v_code := 'TBC-' || upper(substring(md5(random()::text) FROM 1 FOR 5));
    SELECT EXISTS(SELECT 1 FROM public.patients WHERE qr_code = v_code) INTO v_exists;
    EXIT WHEN NOT v_exists;
  END LOOP;
  RETURN v_code;
END;
$$ LANGUAGE plpgsql;


-- Fungsi: Auto-generate QR code saat dokter buat pasien baru
CREATE OR REPLACE FUNCTION public.auto_generate_qr_code()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.qr_code IS NULL OR NEW.qr_code = '' THEN
    NEW.qr_code := public.generate_unique_qr_code();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_patient_qr_code
  BEFORE INSERT ON public.patients
  FOR EACH ROW EXECUTE FUNCTION public.auto_generate_qr_code();


-- Fungsi: Handle aktivasi pasien (dipanggil dari Flutter via RPC)
-- Pasien scan QR → input username & password → akun aktif
CREATE OR REPLACE FUNCTION public.activate_patient(
  p_qr_code   TEXT,
  p_username  TEXT,
  p_password  TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_patient   public.patients;
  v_username_exists BOOLEAN;
BEGIN
  -- Cari pasien berdasarkan QR code
  SELECT * INTO v_patient
  FROM public.patients
  WHERE qr_code = p_qr_code
    AND is_activated = FALSE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'QR code tidak valid atau sudah digunakan');
  END IF;

  -- Cek apakah QR sudah expired
  IF v_patient.qr_expires_at IS NOT NULL AND v_patient.qr_expires_at < NOW() THEN
    RETURN jsonb_build_object('success', false, 'error', 'QR code sudah kadaluarsa, minta QR baru ke dokter');
  END IF;

  -- Validasi panjang username dan password
  IF length(p_username) < 4 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Username minimal 4 karakter');
  END IF;

  IF length(p_password) < 6 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Password minimal 6 karakter');
  END IF;

  -- Cek username sudah dipakai
  SELECT EXISTS(SELECT 1 FROM public.patients WHERE username = p_username) INTO v_username_exists;
  IF v_username_exists THEN
    RETURN jsonb_build_object('success', false, 'error', 'Username sudah digunakan, pilih username lain');
  END IF;

  -- Aktivasi akun pasien
  UPDATE public.patients SET
    username        = p_username,
    password_hash   = crypt(p_password, gen_salt('bf')),  -- bcrypt
    is_activated    = TRUE,
    activated_at    = NOW(),
    updated_at      = NOW()
  WHERE id = v_patient.id;

  RETURN jsonb_build_object(
    'success',     true,
    'patient_id',  v_patient.id,
    'full_name',   v_patient.full_name,
    'doctor_id',   v_patient.doctor_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.activate_patient IS 'RPC: Dipanggil saat pasien scan QR dan set username/password pertama kali';


-- Fungsi: Login pasien (username + password)
CREATE OR REPLACE FUNCTION public.login_patient(
  p_username  TEXT,
  p_password  TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_patient public.patients;
BEGIN
  SELECT * INTO v_patient
  FROM public.patients
  WHERE username = p_username
    AND is_activated = TRUE
    AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Username tidak ditemukan');
  END IF;

  -- Verifikasi password
  IF v_patient.password_hash != crypt(p_password, v_patient.password_hash) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Password salah');
  END IF;

  RETURN jsonb_build_object(
    'success',       true,
    'patient_id',    v_patient.id,
    'full_name',     v_patient.full_name,
    'doctor_id',     v_patient.doctor_id,
    'qr_code',       v_patient.qr_code,
    'treatment_start_date', v_patient.treatment_start_date,
    'initial_weight_kg',    v_patient.initial_weight_kg
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.login_patient IS 'RPC: Login pasien dengan username + password (bukan via Supabase Auth)';


-- Fungsi: Handle new Supabase Auth user → auto insert ke doctors table
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Hanya insert jika metadata mengandung role = 'doctor'
  IF (NEW.raw_user_meta_data->>'role') = 'doctor' THEN
    INSERT INTO public.doctors (id, full_name, email, str_number)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'full_name', 'Dokter Baru'),
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'str_number', 'PENDING-' || substr(NEW.id::text, 1, 8))
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

COMMENT ON FUNCTION public.handle_new_auth_user IS 'Auto-create doctors row saat dokter register via Supabase Auth';


-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Aktifkan RLS di semua tabel
ALTER TABLE public.doctors          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medication_logs  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.symptom_logs     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weight_logs      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clinic_visits    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctor_feedbacks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications    ENABLE ROW LEVEL SECURITY;


-- ---- DOCTORS ----
-- Dokter hanya bisa lihat & edit profil sendiri
CREATE POLICY "doctors: read own profile"
  ON public.doctors FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "doctors: update own profile"
  ON public.doctors FOR UPDATE
  USING (auth.uid() = id);


-- ---- PATIENTS ----
-- Dokter hanya bisa akses pasien miliknya
CREATE POLICY "doctors: manage own patients"
  ON public.patients FOR ALL
  USING (auth.uid() = doctor_id);

-- Pasien tidak menggunakan Supabase Auth → akses via SECURITY DEFINER functions
-- (login_patient, activate_patient)


-- ---- MEDICATION LOGS ----
-- Dokter bisa lihat semua log pasiennya
CREATE POLICY "doctors: view patient medication logs"
  ON public.medication_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.patients p
      WHERE p.id = medication_logs.patient_id
        AND p.doctor_id = auth.uid()
    )
  );

-- Insert medication log hanya dari service_role (via Edge Function / RPC)
-- Pasien login tidak menggunakan auth.uid(), jadi insert via RPC


-- ---- SYMPTOM LOGS ----
CREATE POLICY "doctors: view patient symptom logs"
  ON public.symptom_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.patients p
      WHERE p.id = symptom_logs.patient_id
        AND p.doctor_id = auth.uid()
    )
  );


-- ---- WEIGHT LOGS ----
CREATE POLICY "doctors: view patient weight logs"
  ON public.weight_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.patients p
      WHERE p.id = weight_logs.patient_id
        AND p.doctor_id = auth.uid()
    )
  );


-- ---- CLINIC VISITS ----
CREATE POLICY "doctors: manage clinic visits"
  ON public.clinic_visits FOR ALL
  USING (doctor_id = auth.uid());


-- ---- DOCTOR FEEDBACKS ----
CREATE POLICY "doctors: manage own feedbacks"
  ON public.doctor_feedbacks FOR ALL
  USING (doctor_id = auth.uid());


-- ---- NOTIFICATIONS ----
CREATE POLICY "doctors: view notifications of own patients"
  ON public.notifications FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.patients p
      WHERE p.id = notifications.patient_id
        AND p.doctor_id = auth.uid()
    )
  );


-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_patients_doctor_id       ON public.patients(doctor_id);
CREATE INDEX idx_patients_qr_code         ON public.patients(qr_code);
CREATE INDEX idx_patients_username        ON public.patients(username) WHERE username IS NOT NULL;
CREATE INDEX idx_medication_logs_patient  ON public.medication_logs(patient_id, log_date);
CREATE INDEX idx_symptom_logs_patient     ON public.symptom_logs(patient_id, log_date);
CREATE INDEX idx_weight_logs_patient      ON public.weight_logs(patient_id, log_date);
CREATE INDEX idx_clinic_visits_patient    ON public.clinic_visits(patient_id);
CREATE INDEX idx_feedbacks_patient        ON public.doctor_feedbacks(patient_id, created_at DESC);
CREATE INDEX idx_notifications_patient    ON public.notifications(patient_id, is_read);


-- ============================================================
-- VIEWS (untuk kemudahan query di Flutter)
-- ============================================================

-- View: Dashboard triage dokter (priority board)
-- Sorting: Emergency > Missed Medication > Normal
CREATE OR REPLACE VIEW public.v_doctor_triage AS
SELECT
  p.id              AS patient_id,
  p.full_name,
  p.age,
  p.treatment_start_date,
  p.doctor_id,

  -- Status emergency dari gejala hari ini
  COALESCE(sl.is_emergency, FALSE)  AS has_emergency_symptom,

  -- Apakah ada obat terlambat/terlewat hari ini
  COALESCE(
    EXISTS(
      SELECT 1 FROM public.medication_logs ml
      WHERE ml.patient_id = p.id
        AND ml.log_date = CURRENT_DATE
        AND ml.status IN ('missed', 'late')
    ), FALSE
  ) AS has_missed_medication,

  -- Kepatuhan 7 hari terakhir (%)
  ROUND(
    (
      SELECT COUNT(*) FILTER (WHERE ml2.status = 'taken')::NUMERIC
      / NULLIF(COUNT(*), 0) * 100
      FROM public.medication_logs ml2
      WHERE ml2.patient_id = p.id
        AND ml2.log_date >= CURRENT_DATE - INTERVAL '7 days'
    ), 1
  ) AS adherence_7d_pct,

  -- Berat terbaru
  (
    SELECT wl.weight_kg FROM public.weight_logs wl
    WHERE wl.patient_id = p.id
    ORDER BY wl.log_date DESC LIMIT 1
  ) AS latest_weight_kg,

  -- Priority level untuk sorting
  CASE
    WHEN COALESCE(sl.is_emergency, FALSE) THEN 1             -- 🔴 Emergency
    WHEN COALESCE(
      EXISTS(
        SELECT 1 FROM public.medication_logs ml3
        WHERE ml3.patient_id = p.id
          AND ml3.log_date = CURRENT_DATE
          AND ml3.status IN ('missed', 'late')
      ), FALSE
    ) THEN 2                                                  -- 🟡 Missed medication
    ELSE 3                                                    -- 🟢 Normal
  END AS priority_level

FROM public.patients p
LEFT JOIN public.symptom_logs sl
  ON sl.patient_id = p.id AND sl.log_date = CURRENT_DATE
WHERE p.status = 'active';

COMMENT ON VIEW public.v_doctor_triage IS 'Dashboard triage: sorting otomatis Emergency > Missed > Normal';


-- View: Summary adherence pasien (untuk detail pasien di dashboard dokter)
CREATE OR REPLACE VIEW public.v_patient_adherence_summary AS
SELECT
  p.id          AS patient_id,
  p.full_name,
  p.doctor_id,
  p.treatment_start_date,
  (CURRENT_DATE - p.treatment_start_date)::INT AS treatment_day,

  -- Total sesi yang sudah tercatat
  COUNT(ml.id)                                  AS total_sessions,
  COUNT(*) FILTER (WHERE ml.status = 'taken')   AS taken_count,
  COUNT(*) FILTER (WHERE ml.status = 'missed')  AS missed_count,
  COUNT(*) FILTER (WHERE ml.status = 'late')    AS late_count,

  -- Persentase kepatuhan keseluruhan
  ROUND(
    COUNT(*) FILTER (WHERE ml.status = 'taken')::NUMERIC
    / NULLIF(COUNT(ml.id), 0) * 100, 1
  ) AS overall_adherence_pct

FROM public.patients p
LEFT JOIN public.medication_logs ml ON ml.patient_id = p.id
GROUP BY p.id, p.full_name, p.doctor_id, p.treatment_start_date;

COMMENT ON VIEW public.v_patient_adherence_summary IS 'Ringkasan kepatuhan minum obat per pasien';


-- ============================================================
-- SAMPLE DATA (untuk testing & development)
-- ============================================================

-- Catatan: doctor ID akan diisi setelah register via Supabase Auth
-- Contoh insert manual untuk testing:

/*
-- Contoh pasien (tanpa aktivasi) - jalankan setelah ada doctor_id nyata
INSERT INTO public.patients (doctor_id, full_name, age, gender, initial_weight_kg, treatment_start_date)
VALUES
  ('YOUR-DOCTOR-UUID', 'Budi Santoso', 35, 'male', 58.5, '2025-01-15'),
  ('YOUR-DOCTOR-UUID', 'Sari Dewi', 28, 'female', 45.0, '2025-02-01'),
  ('YOUR-DOCTOR-UUID', 'Ahmad Fauzi', 42, 'male', 65.0, '2025-02-15');
-- QR code akan auto-generate via trigger

-- Contoh clinic visit
INSERT INTO public.clinic_visits (patient_id, doctor_id, visit_number, scheduled_date, location)
VALUES
  ('PATIENT-UUID', 'DOCTOR-UUID', 1, '2025-02-15', 'Poli Paru - RSUD Dr. Soetomo'),
  ('PATIENT-UUID', 'DOCTOR-UUID', 2, '2025-03-15', 'Poli Paru - RSUD Dr. Soetomo');
*/