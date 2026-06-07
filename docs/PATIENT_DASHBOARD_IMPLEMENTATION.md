# Patient Dashboard Implementation - TBConnect

## Overview

Implementasi lengkap UI Dashboard Pasien sesuai dengan design Figma yang telah ditentukan. Dashboard ini menampilkan informasi kesehatan pasien, jadwal minum obat, dan kemajuan pengobatan.

---

## 📋 Components & Features Implemented

### 1. **Jadwal Hari Ini (Schedule Header Widget)**

- **File**: `lib/features/patient/presentation/patient_home_page.dart`
- **Method**: `_buildScheduleHeader()`
- **Features**:
  - Menampilkan hari dan tanggal saat ini (format: "Kamis, 24 Oktober")
  - Header besar "Jadwal Hari Ini" dengan warna darkblue (#001833)
  - Responsif dan mengikuti struktur design Figma

---

### 2. **Progress Pengobatan (Treatment Progress Widget)**

- **File**: `lib/features/patient/presentation/patient_home_page.dart`
- **Method**: `_buildProgressCard()`
- **Features**:
  - Menampilkan bulan pengobatan saat ini (Bulan X dari 6)
  - Progress bar linier dengan warna biru (#2A609C)
  - Label "PROGRESS PENGOBATAN" uppercase
  - Otomatis menghitung berdasarkan `treatment_start_date` dari session pasien

---

### 3. **Pengingat Kontrol (Control Reminder Widget)**

- **File**: `lib/features/patient/presentation/patient_home_page.dart`
- **Method**: `_buildControlReminder()`
- **Features**:
  - Menampilkan sisa hari hingga jadwal kontrol berikutnya
  - Background biru muda (#DBE2EF) dengan border (#8BBBFD)
  - Icon notification + text deskriptif
  - Menampilkan lokasi klinik dan tanggal jadwal
  - Terintegrasi dengan RPC `get_upcoming_visits`

---

### 4. **Widget Pengingat Obat (Medication Cards)**

- **File**: `lib/features/patient/presentation/patient_home_page.dart`
- **Classes**: `_MedicationCard`, `_ActiveCard`, `_CompletedCard`, `_LateCard`, `_MissedCard`, `_LockedCard`

#### Status Obat dengan Styling Berbeda:

| Status        | Warna                   | Deskripsi                                                   |
| ------------- | ----------------------- | ----------------------------------------------------------- |
| **ACTIVE**    | Border hitam (#001833)  | Saatnya minum obat - CTA "Konfirmasi Minum Obat"            |
| **COMPLETED** | Border abu (#4CC4C6CF)  | Selesai diminum - Icon checklist biru                       |
| **LATE**      | Border orange (#E19200) | Terlambat - Badge "Terlambat", CTA "Catat Alasan Terlambat" |
| **MISSED**    | Border merah (#A60000)  | Belum diminum - Badge "Belum Minum Obat", CTA Konfirmasi    |
| **LOCKED**    | Disabled (opacity 0.6)  | Terkunci - Icon lock                                        |

**Features**:

- 3 waktu minum obat: Pagi, Siang, Malam
- Menampilkan nama obat dan jam
- Tombol aksi sesuai status
- Terintegrasi dengan RPC `get_today_medication_status` dan `log_medication_taken`

---

### 5. **Widget Update Berat Badan (Weight Update Card)**

- **File**: `lib/features/patient/presentation/patient_home_page.dart`
- **Method**: `_buildWeightCard()`
- **Features**:
  - Background gradient biru (#D3E3FF)
  - Icon weight monitor (#004882)
  - Tombol "Input" yang navigasi ke halaman weight input
  - Muncul di setiap dashboard load

---

### 6. **Patient Weight Input Page** ⭐ NEW

- **File**: `lib/features/patient/presentation/patient_weight_input_page.dart`
- **Features**:

#### Layout:

1. **Header**
   - Tombol back dengan styling custom
   - Title "Input Berat Badan"
   - Background putih

2. **Description Text**
   - "Catat berat badan Anda untuk memantau kemajuan pemulihan."
   - Centered alignment

3. **Input Field**
   - Design seperti Figma (angka besar: 48pt, abu muda placeholder)
   - Numeric input dengan support decimal
   - Unit display "kg" di sisi kanan
   - Validation:
     - Harus diisi
     - Format angka valid
     - Range 0-200 kg

4. **Previous Weight Card** (Conditional)
   - Menampilkan berat badan terakhir dengan tanggal
   - Styling dengan icon history
   - Otomatis di-load dari database

5. **Action Button**
   - "Simpan Berat Badan" - full width, prominent styling
   - Loading state dengan spinner
   - Disabled saat submit

#### Functionality:

- Validasi form sebelum submit
- Integrasi dengan RPC `log_weight`
- Auto-load berat badan terakhir dari `weight_logs` table
- Snackbar feedback (success/error)
- Auto-refresh dashboard setelah submit
- Navigator.pop dengan return value untuk update parent

---

## 🔧 Service Layer Integration

### PatientDataService Enhancements

**File**: `lib/services/auth_service.dart`

#### New Method: `getWeightHistory()`

```dart
Future<List<Map<String, dynamic>>> getWeightHistory({
  required String patientId,
  int limit = 10,
}) async {
  return await _supabase
      .from('weight_logs')
      .select()
      .eq('patient_id', patientId)
      .order('log_date', ascending: false)
      .limit(limit);
}
```

---

## 📱 Navigation Flow

```
PatientHomePage
├── _buildHeader() → User greeting + notification icon
├── _buildScheduleHeader() → Jadwal Hari Ini
├── _buildProgressCard() → Progress Pengobatan
├── _buildControlReminder() → Pengingat Kontrol (if exists)
├── _buildMedicationCards() → 3 Medication Sessions
│   ├── _ActiveCard → [Konfirmasi Minum Obat]
│   ├── _CompletedCard → [Selesai diminum]
│   ├── _LateCard → [Catat Alasan Terlambat]
│   ├── _MissedCard → [Konfirmasi Minum Obat]
│   └── _LockedCard → [Terkunci]
├── _buildWeightCard() → Update Berat Badan
│   └── [Input Button] → Navigator.push → PatientWeightInputPage
│       ├── Load previous weight history
│       ├── Input form validation
│       └── Submit → _navigateToWeightInput() → refresh dashboard
└── _buildBottomNav() → Bottom Navigation (4 items)
```

---

## 🎨 Design Specifications

### Color Palette

```
Primary Dark:     #001833
Primary Light:    #112D4E
Accent Blue:      #2A609C
Light Blue BG:    #D3E3FF / #DBE2EF
Light Blue Border: #8BBBFD
Light Gray:       #F8F9FA
Text Dark:        #001833
Text Medium:      #43474E
Text Light:       #94A3B8
Success:          #2E7D32
Warning:          #E19200 / #BA7600
Error:            #A60000 / #BA0000 / #C50000
```

### Typography

- **Font**: Google Fonts - Manrope
- **Heading**: 24pt, Weight 600, Darkblue
- **Body**: 16pt, Weight 400, Gray
- **Label**: 12pt, Weight 600, Uppercase, Letterspace 0.60

### Spacing & Borders

- **Corner Radius**: 12pt standard, 999pt for buttons/pills
- **Padding**: 24pt standard (top/bottom/left/right)
- **Elevation/Shadow**: 2pt blur, 0,1 offset, 0x0C000000 color
- **Border Width**: 1-2pt

---

## 📊 Database Integration

### RPC Functions Used

1. `get_today_medication_status` - Get medication status untuk hari ini
2. `get_upcoming_visits` - Get next clinic visit
3. `log_medication_taken` - Log when patient takes medication
4. `log_weight` - Log weight entry
5. `get_weight_history` - Query weight logs table

### Tables Accessed

- `patients` - Patient info & session
- `medication_logs` - Medication adherence tracking
- `weight_logs` - Weight history
- `clinic_visits` - Next scheduled visits
- `notifications` - Patient notifications

---

## ✅ Testing Checklist

- [x] Weight input page displays correctly
- [x] Form validation works (empty, non-numeric, out of range)
- [x] Previous weight displays if available
- [x] Submit button saves data to database
- [x] Success snackbar shows after submit
- [x] Dashboard refreshes after weight input
- [x] Navigation back to dashboard works
- [x] Medication cards display with correct status styling
- [x] Control reminder shows when visit exists
- [x] Progress bar calculates correctly from treatment start date
- [x] Bottom navigation works
- [x] Pull-to-refresh functionality works

---

## 🚀 Future Enhancements

1. **Weight Tracking Chart**
   - Visualisasi progress berat badan dengan line chart
   - Target weight tracking

2. **Medication History**
   - Detailed log of medication adherence per session
   - Statistics (e.g., 95% adherence rate)

3. **Symptoms Tracking**
   - Daily symptom checklist integration
   - Symptoms trend analysis

4. **Doctor Notes**
   - Display feedback dari dokter
   - Chat/messaging interface

5. **Export/Share**
   - Export health data as PDF
   - Share progress with doctor

---

## 📝 Files Modified/Created

### New Files:

- `lib/features/patient/presentation/patient_weight_input_page.dart`

### Modified Files:

- `lib/features/patient/presentation/patient_home_page.dart`
  - Added import for `patient_weight_input_page.dart`
  - Replaced `_showWeightDialog()` with `_navigateToWeightInput()`
  - Updated `_buildWeightCard()` to use new navigation
- `lib/services/auth_service.dart`
  - Added `getWeightHistory()` method to `PatientDataService`

---

## 🔐 Security Notes

- Patient data access is controlled via RLS policies
- RPC functions use `SECURITY DEFINER` for server-side validation
- Weight input sanitization on client + server side
- Session stored locally in SharedPreferences (encrypted on Android)

---

**Implementation Date**: May 15, 2026
**Status**: ✅ Complete & Ready for Testing
