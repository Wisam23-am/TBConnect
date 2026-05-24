-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.clinic_visits (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  patient_id uuid NOT NULL,
  doctor_id uuid NOT NULL,
  visit_number smallint NOT NULL,
  scheduled_date date NOT NULL,
  location text NOT NULL,
  purpose text DEFAULT 'Kontrol & Ambil Obat'::text,
  status text DEFAULT 'upcoming'::text CHECK (status = ANY (ARRAY['upcoming'::text, 'done'::text, 'missed'::text, 'rescheduled'::text])),
  reschedule_requested boolean DEFAULT false,
  reschedule_reason text,
  reschedule_to_date date,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT clinic_visits_pkey PRIMARY KEY (id),
  CONSTRAINT clinic_visits_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id),
  CONSTRAINT clinic_visits_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.daily_symptom_reports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  patient_id uuid NOT NULL,
  report_date date NOT NULL DEFAULT CURRENT_DATE,
  mood_level text NOT NULL CHECK (mood_level = ANY (ARRAY['sangat_buruk'::text, 'kurang_baik'::text, 'cukup_baik'::text, 'sangat_baik'::text])),
  symptoms ARRAY DEFAULT '{}'::text[],
  emergency_symptoms ARRAY DEFAULT '{}'::text[],
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT daily_symptom_reports_pkey PRIMARY KEY (id),
  CONSTRAINT daily_symptom_reports_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id)
);
CREATE TABLE public.doctor_feedbacks (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  doctor_id uuid NOT NULL,
  patient_id uuid NOT NULL,
  message text NOT NULL,
  is_urgent boolean DEFAULT false,
  is_read boolean DEFAULT false,
  read_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT doctor_feedbacks_pkey PRIMARY KEY (id),
  CONSTRAINT doctor_feedbacks_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id),
  CONSTRAINT doctor_feedbacks_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id)
);
CREATE TABLE public.doctors (
  id uuid NOT NULL,
  full_name text NOT NULL,
  email text NOT NULL UNIQUE,
  str_number text NOT NULL UNIQUE,
  specialization text DEFAULT 'Paru-Paru'::text,
  hospital_name text,
  phone_number text,
  avatar_url text,
  notif_start_hour smallint DEFAULT 7,
  notif_end_hour smallint DEFAULT 21,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT doctors_pkey PRIMARY KEY (id),
  CONSTRAINT doctors_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.medication_logs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  patient_id uuid NOT NULL,
  log_date date NOT NULL,
  session text NOT NULL CHECK (session = ANY (ARRAY['morning'::text, 'afternoon'::text, 'evening'::text])),
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'taken'::text, 'missed'::text, 'late'::text])),
  taken_at timestamp with time zone,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  late_reason text,
  CONSTRAINT medication_logs_pkey PRIMARY KEY (id),
  CONSTRAINT medication_logs_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id)
);
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  patient_id uuid NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY['medication_reminder'::text, 'doctor_feedback'::text, 'clinic_visit_reminder'::text, 'weight_input_reminder'::text, 'emergency_ack'::text])),
  title text NOT NULL,
  body text NOT NULL,
  payload jsonb,
  is_sent boolean DEFAULT false,
  sent_at timestamp with time zone,
  is_read boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id)
);
CREATE TABLE public.patients (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  doctor_id uuid NOT NULL,
  full_name text NOT NULL,
  age smallint CHECK (age > 0 AND age < 150),
  gender text CHECK (gender = ANY (ARRAY['male'::text, 'female'::text])),
  phone_number text,
  address text,
  initial_weight_kg numeric NOT NULL,
  treatment_start_date date NOT NULL,
  treatment_duration_months smallint DEFAULT 6,
  username text UNIQUE,
  password_hash text,
  is_activated boolean DEFAULT false,
  qr_code text NOT NULL UNIQUE,
  qr_expires_at timestamp with time zone,
  status text DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'completed'::text, 'dropout'::text, 'transferred'::text])),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  activated_at timestamp with time zone,
  nik text UNIQUE,
  birth_place text,
  birth_date date,
  faskes_name text,
  CONSTRAINT patients_pkey PRIMARY KEY (id),
  CONSTRAINT patients_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id)
);
CREATE TABLE public.symptom_logs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  patient_id uuid NOT NULL,
  log_date date NOT NULL,
  nausea_level smallint DEFAULT 0 CHECK (nausea_level >= 0 AND nausea_level <= 10),
  dizziness_level smallint DEFAULT 0 CHECK (dizziness_level >= 0 AND dizziness_level <= 10),
  fatigue_level smallint DEFAULT 0 CHECK (fatigue_level >= 0 AND fatigue_level <= 10),
  hemoptysis boolean DEFAULT false,
  chest_pain boolean DEFAULT false,
  shortness_of_breath boolean DEFAULT false,
  is_emergency boolean DEFAULT (hemoptysis OR chest_pain OR shortness_of_breath),
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT symptom_logs_pkey PRIMARY KEY (id),
  CONSTRAINT symptom_logs_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id)
);
CREATE TABLE public.weight_logs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  patient_id uuid NOT NULL,
  log_date date NOT NULL,
  weight_kg numeric NOT NULL CHECK (weight_kg > 0::numeric),
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  day_of_treatment integer,
  CONSTRAINT weight_logs_pkey PRIMARY KEY (id),
  CONSTRAINT weight_logs_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id)
);