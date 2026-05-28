f## Table `clinic_visits`

Jadwal kunjungan kontrol bulanan selama 6 bulan pengobatan

### Columns

| Name                   | Type          | Constraints |
| ---------------------- | ------------- | ----------- |
| `id`                   | `uuid`        | Primary     |
| `patient_id`           | `uuid`        |             |
| `doctor_id`            | `uuid`        |             |
| `visit_number`         | `int2`        |             |
| `scheduled_date`       | `date`        |             |
| `location`             | `text`        |             |
| `purpose`              | `text`        | Nullable    |
| `status`               | `text`        | Nullable    |
| `reschedule_requested` | `bool`        | Nullable    |
| `reschedule_reason`    | `text`        | Nullable    |
| `reschedule_to_date`   | `date`        | Nullable    |
| `notes`                | `text`        | Nullable    |
| `created_at`           | `timestamptz` | Nullable    |
| `updated_at`           | `timestamptz` | Nullable    |

## Table `daily_symptom_reports`

### Columns

| Name                 | Type          | Constraints |
| -------------------- | ------------- | ----------- |
| `id`                 | `uuid`        | Primary     |
| `patient_id`         | `uuid`        |             |
| `report_date`        | `date`        |             |
| `mood_level`         | `text`        |             |
| `symptoms`           | `_text`       | Nullable    |
| `emergency_symptoms` | `_text`       | Nullable    |
| `notes`              | `text`        | Nullable    |
| `created_at`         | `timestamptz` |             |

## Table `doctor_feedbacks`

Pesan asinkron dari dokter ke pasien

### Columns

| Name         | Type          | Constraints |
| ------------ | ------------- | ----------- |
| `id`         | `uuid`        | Primary     |
| `doctor_id`  | `uuid`        |             |
| `patient_id` | `uuid`        |             |
| `message`    | `text`        |             |
| `is_urgent`  | `bool`        | Nullable    |
| `is_read`    | `bool`        | Nullable    |
| `read_at`    | `timestamptz` | Nullable    |
| `created_at` | `timestamptz` | Nullable    |

## Table `doctors`

Profil dokter yang terintegrasi dengan Supabase Auth

### Columns

| Name               | Type          | Constraints |
| ------------------ | ------------- | ----------- |
| `id`               | `uuid`        | Primary     |
| `full_name`        | `text`        |             |
| `email`            | `text`        | Unique      |
| `str_number`       | `text`        | Unique      |
| `specialization`   | `text`        | Nullable    |
| `hospital_name`    | `text`        | Nullable    |
| `phone_number`     | `text`        | Nullable    |
| `avatar_url`       | `text`        | Nullable    |
| `notif_start_hour` | `int2`        | Nullable    |
| `notif_end_hour`   | `int2`        | Nullable    |
| `is_active`        | `bool`        | Nullable    |
| `created_at`       | `timestamptz` | Nullable    |
| `updated_at`       | `timestamptz` | Nullable    |

## Table `medication_logs`

Log kepatuhan minum obat 3x sehari

### Columns

| Name          | Type          | Constraints |
| ------------- | ------------- | ----------- |
| `id`          | `uuid`        | Primary     |
| `patient_id`  | `uuid`        |             |
| `log_date`    | `date`        |             |
| `session`     | `text`        |             |
| `status`      | `text`        |             |
| `taken_at`    | `timestamptz` | Nullable    |
| `notes`       | `text`        | Nullable    |
| `created_at`  | `timestamptz` | Nullable    |
| `late_reason` | `text`        | Nullable    |

## Table `notifications`

Log notifikasi push untuk pasien

### Columns

| Name         | Type          | Constraints |
| ------------ | ------------- | ----------- |
| `id`         | `uuid`        | Primary     |
| `patient_id` | `uuid`        |             |
| `type`       | `text`        |             |
| `title`      | `text`        |             |
| `body`       | `text`        |             |
| `payload`    | `jsonb`       | Nullable    |
| `is_sent`    | `bool`        | Nullable    |
| `sent_at`    | `timestamptz` | Nullable    |
| `is_read`    | `bool`        | Nullable    |
| `created_at` | `timestamptz` | Nullable    |

## Table `patients`

Pasien TBC. Akun dibuat dokter, diaktifkan pasien via scan QR

### Columns

| Name                        | Type          | Constraints     |
| --------------------------- | ------------- | --------------- |
| `id`                        | `uuid`        | Primary         |
| `doctor_id`                 | `uuid`        |                 |
| `full_name`                 | `text`        |                 |
| `age`                       | `int2`        | Nullable        |
| `gender`                    | `text`        | Nullable        |
| `phone_number`              | `text`        | Nullable        |
| `address`                   | `text`        | Nullable        |
| `initial_weight_kg`         | `numeric`     |                 |
| `treatment_start_date`      | `date`        |                 |
| `treatment_duration_months` | `int2`        | Nullable        |
| `username`                  | `text`        | Nullable Unique |
| `password_hash`             | `text`        | Nullable        |
| `is_activated`              | `bool`        | Nullable        |
| `qr_code`                   | `text`        | Unique          |
| `qr_expires_at`             | `timestamptz` | Nullable        |
| `status`                    | `text`        | Nullable        |
| `created_at`                | `timestamptz` | Nullable        |
| `updated_at`                | `timestamptz` | Nullable        |
| `activated_at`              | `timestamptz` | Nullable        |
| `nik`                       | `text`        | Nullable Unique |
| `birth_place`               | `text`        | Nullable        |
| `birth_date`                | `date`        | Nullable        |
| `faskes_name`               | `text`        | Nullable        |

## Table `symptom_logs`

Log gejala harian. is_emergency otomatis True jika ada gejala kritis

### Columns

| Name                  | Type          | Constraints |
| --------------------- | ------------- | ----------- |
| `id`                  | `uuid`        | Primary     |
| `patient_id`          | `uuid`        |             |
| `log_date`            | `date`        |             |
| `nausea_level`        | `int2`        | Nullable    |
| `dizziness_level`     | `int2`        | Nullable    |
| `fatigue_level`       | `int2`        | Nullable    |
| `hemoptysis`          | `bool`        | Nullable    |
| `chest_pain`          | `bool`        | Nullable    |
| `shortness_of_breath` | `bool`        | Nullable    |
| `is_emergency`        | `bool`        | Nullable    |
| `notes`               | `text`        | Nullable    |
| `created_at`          | `timestamptz` | Nullable    |

## Table `weight_logs`

Tracking berat badan pasien. Input di hari ke-30, 60, 90, dst

### Columns

| Name               | Type          | Constraints |
| ------------------ | ------------- | ----------- |
| `id`               | `uuid`        | Primary     |
| `patient_id`       | `uuid`        |             |
| `log_date`         | `date`        |             |
| `weight_kg`        | `numeric`     |             |
| `notes`            | `text`        | Nullable    |
| `created_at`       | `timestamptz` | Nullable    |
| `day_of_treatment` | `int4`        | Nullable    |
