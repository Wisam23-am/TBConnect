# TBConnect - Panduan Setup Database Supabase

## 📦 File yang Disertakan

| File | Deskripsi |
|------|-----------|
| `tbconnect_supabase_schema.sql` | Schema utama: tabel, trigger, RLS, views |
| `tbconnect_rpc_functions.sql` | RPC functions untuk operasi pasien & cron |
| `auth_service.dart` | Flutter service layer (AuthService, DoctorService, PatientDataService) |

---

## 🗄️ Arsitektur Database

```
auth.users (Supabase Auth)
    ↓ trigger: on_auth_user_created
doctors (profil dokter)
    ↓ 1-to-many
patients (dibuat dokter, login via RPC)
    ├── medication_logs
    ├── symptom_logs
    ├── weight_logs
    ├── clinic_visits
    ├── doctor_feedbacks
    └── notifications
```

---

## 🔐 Sistem Autentikasi

### Dokter → Supabase Auth (standard)
```
Register: supabase.auth.signUp(email, password, metadata: {role: 'doctor', str_number: ...})
Login:    supabase.auth.signInWithPassword(email, password)
```
- RLS aktif: dokter hanya bisa akses data pasiennya sendiri
- Trigger `on_auth_user_created` otomatis buat row di tabel `doctors`

### Pasien → Custom Auth via RPC (TIDAK pakai Supabase Auth)
```
Aktivasi: supabase.rpc('activate_patient', {qr_code, username, password})
Login:    supabase.rpc('login_patient', {username, password})
```
- Session pasien disimpan di SharedPreferences Flutter
- Semua operasi pasien melalui `SECURITY DEFINER` RPC functions

---

## 🚀 Cara Setup di Supabase

### Langkah 1: Buat Project Supabase
1. Buka https://supabase.com
2. New Project → isi nama, database password, region (Singapore/ap-southeast-1)

### Langkah 2: Jalankan Schema
1. Supabase Dashboard → SQL Editor
2. Paste isi `tbconnect_supabase_schema.sql` → Run
3. Paste isi `tbconnect_rpc_functions.sql` → Run

### Langkah 3: Aktifkan Extensions
Di SQL Editor, pastikan ini sudah aktif:
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- Untuk cron job (opsional):
CREATE EXTENSION IF NOT EXISTS pg_cron;
```

### Langkah 4: Setup Flutter
Tambah ke `pubspec.yaml`:
```yaml
dependencies:
  supabase_flutter: ^2.0.0
  shared_preferences: ^2.2.0
  mobile_scanner: ^4.0.0  # untuk scan QR
  qr_flutter: ^4.1.0      # untuk generate QR di dokter
```

`main.dart`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://YOUR_PROJECT_ID.supabase.co',
    anonKey: 'YOUR_ANON_KEY',
  );
  runApp(const MyApp());
}
```

---

## 📋 Tabel & Fungsi Utama

### Tabel
| Tabel | Deskripsi |
|-------|-----------|
| `doctors` | Profil dokter (linked ke auth.users) |
| `patients` | Data pasien + QR code + credentials |
| `medication_logs` | Log kepatuhan minum obat 3x/hari |
| `symptom_logs` | Log gejala harian (termasuk flag emergency) |
| `weight_logs` | Tracking berat badan per kunjungan |
| `clinic_visits` | Jadwal 6 kunjungan bulanan |
| `doctor_feedbacks` | Pesan dari dokter ke pasien |
| `notifications` | Log notifikasi push |

### Views
| View | Kegunaan |
|------|----------|
| `v_doctor_triage` | Dashboard triage (sorting Emergency > Missed > Normal) |
| `v_patient_adherence_summary` | Ringkasan kepatuhan per pasien |

### RPC Functions
| Function | Dipanggil oleh | Kegunaan |
|----------|---------------|----------|
| `activate_patient` | Flutter (saat scan QR) | Aktivasi akun pasien |
| `login_patient` | Flutter | Login pasien |
| `log_medication_taken` | Flutter Pasien | Catat minum obat (server time) |
| `get_today_medication_status` | Flutter Pasien | Status obat hari ini |
| `log_daily_symptoms` | Flutter Pasien | Input gejala harian |
| `log_weight` | Flutter Pasien | Input berat badan |
| `get_patient_notifications` | Flutter Pasien | Ambil notifikasi |
| `request_visit_reschedule` | Flutter Pasien | Request jadwal ulang |
| `mark_missed_medications` | Cron (23:00 WIB) | Auto-tandai obat terlewat |

---

## 🔄 Alur QR Code (Lengkap)

```
1. Dokter buat pasien baru (DoctorService.addPatient)
         ↓
2. Trigger auto-generate QR code (contoh: TBC-8899A)
         ↓
3. Flutter dokter tampilkan QR:
   QrImageView(data: patient['qr_code'], ...)
         ↓
4. Pasien buka app → tap "Scan QR Code Dokter"
         ↓
5. MobileScanner scan QR → dapat string "TBC-8899A"
         ↓
6. Tampilkan form: username + password
         ↓
7. Flutter panggil:
   supabase.rpc('activate_patient', {
     qr_code: 'TBC-8899A',
     username: 'budi123',
     password: 'rahasia'
   })
         ↓
8. Pasien langsung masuk dashboard
   (session disimpan di SharedPreferences)
```

---

## ⏰ Server Time & Anti-Cheat Obat

Semua pencatatan waktu minum obat menggunakan `NOW()` dari PostgreSQL (server time), **bukan** device time Flutter. Ini mencegah pasien manipulasi jam HP.

Status sesi otomatis:
- `locked` → belum waktunya
- `active` → dalam window waktu (tap untuk catat)
- `taken` → sudah dicatat ✅
- `late` → window lewat tapi masih bisa input
- `missed` → sudah lewat, tidak ada input (di-set cron jam 23:00)

---

## 🚨 Emergency Flow

Saat pasien input gejala kritis (batuk darah, nyeri dada, sesak):
1. `is_emergency` flag otomatis `TRUE` (computed column)
2. RPC `log_daily_symptoms` auto-insert ke `notifications`
3. Di `v_doctor_triage`, pasien ini naik ke `priority_level = 1` (🔴 top)
4. Dokter bisa kirim feedback urgent via `DoctorService.sendFeedback`

---

## 📊 Cron Job Setup (Opsional tapi Direkomendasikan)

Di Supabase SQL Editor:
```sql
-- Aktifkan pg_cron
CREATE EXTENSION pg_cron;

-- Schedule: setiap hari jam 23:00 WIB (= 16:00 UTC)
SELECT cron.schedule(
  'mark-missed-medications',
  '0 16 * * *',
  'SELECT public.mark_missed_medications()'
);
```