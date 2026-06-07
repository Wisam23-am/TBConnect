# TBConnect - Medication Window Migration Guide

## 📌 Situasi

Anon key tidak bisa menjalankan `DROP FUNCTION` atau `CREATE FUNCTION` (DDL operations).
Perlu salah satu dari berikut untuk apply migration.

---

## ✅ OPSI 1: Via Supabase SQL Editor (PALING MUDAH)

**Syarat**: Akses ke Supabase Dashboard

**Langkah**:

1. Buka: https://teifdfxmyebvnlcfngvc.supabase.co
2. Login dengan akun yang membuat project
3. Klik **SQL Editor** (sidebar kiri)
4. Klik **+ New Query**
5. Copy seluruh isi file: `database/FINAL_MIGRATION_APPLY_TO_SUPABASE.sql`
6. Paste ke editor
7. Klik tombol **RUN** (warna biru/hijau)
8. Tunggu sampai selesai, output harus `Successfully executed`

**Screenshot Success**:

```
-- successfully executed migration
-- functions: log_medication_taken, get_today_medication_status created
-- table: medication_logs.late_reason column added
```

---

## ✅ OPSI 2: Via PowerShell (Windows + Service Role Key)

**Syarat**:

- Service Role Key (bukan anon key)
- PowerShell 5.0+

**Cara dapat Service Role Key**:

1. Buka: https://teifdfxmyebvnlcfngvc.supabase.co
2. Klik **Settings** (sidebar bawah)
3. Klik **API**
4. Cari "service_role secret" (BUKAN anon_public)
5. Copy key-nya

**Jalankan**:

```powershell
# Set service key as environment variable
$env:SUPABASE_SERVICE_ROLE_KEY = "eyJhbGciOi...your_service_role_key...dI"

# Run migration script
.\scripts\run_migration.ps1 -ServiceKey $env:SUPABASE_SERVICE_ROLE_KEY
```

**Atau langsung**:

```powershell
.\scripts\run_migration.ps1 -ServiceKey "eyJhbGciOi...your_service_role_key...dI"
```

---

## ✅ OPSI 3: Via psql (Linux/macOS/Windows with WSL)

**Syarat**:

- PostgreSQL client tools (`psql`) installed
- Database password

**Cara dapat password**:

1. Buka: https://teifdfxmyebvnlcfngvc.supabase.co
2. Settings → Database
3. Cari "Password" (password default saat setup project)
4. Jika lupa, reset password di sini

**Jalankan**:

```bash
# Set password as environment variable
export SUPABASE_DB_PASSWORD="your_postgres_password"

# Run migration
bash scripts/apply_migration.sh
```

**Atau gunakan psql langsung**:

```bash
psql -h db.teifdfxmyebvnlcfngvc.supabase.co \
     -U postgres \
     -d postgres \
     -p 5432 \
     -f database/FINAL_MIGRATION_APPLY_TO_SUPABASE.sql
```

---

## ✅ OPSI 4: Via supabase-cli (Jika installed)

**Install supabase-cli** (jika belum):

```bash
npm install -g supabase
```

**Login ke Supabase**:

```bash
supabase login
```

**Jalankan migration**:

```bash
supabase db push
```

---

## ⚠️ Informasi Teknis

### Credentials

```
Supabase URL: https://teifdfxmyebvnlcfngvc.supabase.co
Database Host: db.teifdfxmyebvnlcfngvc.supabase.co
Database Port: 5432
Database Name: postgres
Database User: postgres
Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Migration Contents

File: `database/FINAL_MIGRATION_APPLY_TO_SUPABASE.sql`

```sql
-- 1. Add late_reason column to medication_logs
ALTER TABLE medication_logs ADD COLUMN IF NOT EXISTS late_reason TEXT;

-- 2. Drop old functions (prevent conflicts)
DROP FUNCTION IF EXISTS public.log_medication_taken(UUID, TEXT);
DROP FUNCTION IF EXISTS public.log_medication_taken(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.get_today_medication_status(UUID);

-- 3. Create log_medication_taken RPC with window validation
-- Window Logic:
--   Morning: 06:00-09:00 (active) → 09:00-13:00 (late) → 13:00+ (blocked)
--   Afternoon: 13:00-16:00 (active) → 16:00-18:00 (late) → 18:00+ (blocked)
--   Evening: 18:00-22:00 (active) → 22:00+ (late)

-- 4. Create get_today_medication_status RPC with strict status logic
--    Returns 'locked' when next session starts (prevents double-dosing)
```

---

## 🔍 Verify Migration Success

Setelah apply, check di Supabase SQL Editor:

```sql
-- Check if column exists
SELECT column_name FROM information_schema.columns
WHERE table_name = 'medication_logs' AND column_name = 'late_reason';
-- Should return: late_reason ✓

-- Check if functions exist
SELECT routine_name FROM information_schema.routines
WHERE routine_name IN ('log_medication_taken', 'get_today_medication_status');
-- Should return 2 rows ✓

-- Test function
SELECT get_today_medication_status('YOUR_PATIENT_ID'::uuid);
-- Should return JSON with window status (active/late/locked) ✓
```

---

## 🚀 Next Steps

1. **Apply migration** dengan salah satu opsi di atas
2. **Verify** menggunakan query di section "Verify Migration Success"
3. **Jalankan app**: `flutter run`
4. **Test medication flow**:
   - Morning 06:00-09:00: Tombol "Konfirmasi" (active)
   - Morning 09:00-12:59: Tombol "Catat Alasan" (late)
   - Morning 13:00+: Status "TERKUNCI", tombol hilang (locked)
   - Sama untuk Afternoon & Evening

---

## ❓ Troubleshooting

### "Permission denied" error di SQL Editor

→ Akun Anda tidak punya akses admin. Minta owner project untuk apply.

### "Function already exists" error

→ Drop function dulu: `DROP FUNCTION IF EXISTS public.log_medication_taken(UUID, TEXT, TEXT);`

### Connection timeout via psql

→ Firewall mungkin block koneksi database. Gunakan SQL Editor opsi 1.

### Service Role Key tidak work

→ Pastikan key dimulai dengan "eyJ...". Anon key dimulai sama tapi beda.

---

## 📞 Butuh Help?

Share screenshot error atau output jika ada masalah.
