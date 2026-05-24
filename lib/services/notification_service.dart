// ============================================================
// TBConnect - Local Notification Service
// File: lib/services/notification_service.dart
// Handles: Android push notifications + scheduling medication reminders
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Notification IDs — tetap konsisten agar bisa di-update/cancel
class NotifId {
  static const int morningMedication = 100;
  static const int afternoonMedication = 101;
  static const int eveningMedication = 102;
  static const int clinicVisitReminder = 200;
  static const int weightInputReminder = 300;
}

/// Notification channel IDs
class NotifChannel {
  static const String medication = 'tbconnect_medication';
  static const String clinicVisit = 'tbconnect_clinic';
  static const String general = 'tbconnect_general';
}

// ---------------------------------------------------------------------------
// Singleton Notification Service
// ---------------------------------------------------------------------------
class LocalNotificationService {
  LocalNotificationService._();
  static final instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ──────────────────────────────────────────────────────────────
  // Inisialisasi — dipanggil sekali saat app start
  // ──────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;

    // Setup timezone WIB
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Buat notification channels untuk Android
    await _createChannels();

    _initialized = true;
  }

  Future<void> _createChannels() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotifChannel.medication,
        'Pengingat Minum Obat',
        description:
            'Notifikasi pengingat jadwal minum obat 3x sehari',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotifChannel.clinicVisit,
        'Jadwal Kontrol',
        description: 'Pengingat jadwal kunjungan kontrol ke dokter',
        importance: Importance.defaultImportance,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotifChannel.general,
        'Informasi TBConnect',
        description: 'Notifikasi umum dari aplikasi TBConnect',
        importance: Importance.defaultImportance,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Minta permission notifikasi (Android 13+)
  // ──────────────────────────────────────────────────────────────
  Future<bool> requestPermission() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;

    final granted =
        await androidPlugin.requestNotificationsPermission() ?? false;
    return granted;
  }

  // ──────────────────────────────────────────────────────────────
  // Jadwalkan pengingat minum obat harian (3 sesi)
  // Dipanggil setelah pasien berhasil login
  // ──────────────────────────────────────────────────────────────
  Future<void> scheduleDailyMedicationReminders() async {
    await _scheduleMedicationSession(
      id: NotifId.morningMedication,
      title: '💊 Waktunya Minum Obat Pagi',
      body:
          'Jangan lupa minum obat TB Anda sekarang. Kepatuhan adalah kunci kesembuhan!',
      hour: 6,
      minute: 0,
    );

    await _scheduleMedicationSession(
      id: NotifId.afternoonMedication,
      title: '💊 Waktunya Minum Obat Siang',
      body:
          'Sudah masuk jadwal minum obat siang. Buka TBConnect untuk konfirmasi.',
      hour: 13,
      minute: 0,
    );

    await _scheduleMedicationSession(
      id: NotifId.eveningMedication,
      title: '💊 Waktunya Minum Obat Malam',
      body: 'Pengingat malam: minum obat TB Anda sebelum tidur ya!',
      hour: 18,
      minute: 0,
    );
  }

  Future<void> _scheduleMedicationSession({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Jika jam sudah lewat hari ini, jadwalkan untuk besok
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotifChannel.medication,
          'Pengingat Minum Obat',
          channelDescription: 'Notifikasi pengingat jadwal minum obat 3x sehari',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF112D4E),
          enableVibration: true,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Ulangi setiap hari
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Pengingat kunjungan kontrol (satu kali, bukan harian)
  // ──────────────────────────────────────────────────────────────
  Future<void> scheduleClinicVisitReminder({
    required DateTime visitDate,
    required String location,
  }) async {
    // Ingatkan 1 hari sebelum jadwal jam 09:00
    final reminderDate = visitDate.subtract(const Duration(days: 1));
    final scheduledTime = tz.TZDateTime(
      tz.local,
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      9,
      0,
    );

    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      NotifId.clinicVisitReminder,
      '📅 Jadwal Kontrol Besok!',
      'Besok ada jadwal kontrol di $location. Jangan lupa hadir ya.',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          NotifChannel.clinicVisit,
          'Jadwal Kontrol',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Tampilkan notifikasi instan (misal konfirmasi, pesan dokter)
  // ──────────────────────────────────────────────────────────────
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String channel = NotifChannel.general,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel == NotifChannel.medication
              ? 'Pengingat Minum Obat'
              : 'Informasi TBConnect',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF112D4E),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Cancel satu notifikasi (misal setelah obat dikonfirmasi)
  // ──────────────────────────────────────────────────────────────
  Future<void> cancelMedicationNotification(String session) async {
    final Map<String, int> sessionIdMap = {
      'morning': NotifId.morningMedication,
      'afternoon': NotifId.afternoonMedication,
      'evening': NotifId.eveningMedication,
    };
    final id = sessionIdMap[session];
    if (id != null) await _plugin.cancel(id);
  }

  /// Cancel semua scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  // ──────────────────────────────────────────────────────────────
  // Callback saat notifikasi di-tap
  // ──────────────────────────────────────────────────────────────
  void _onNotificationTap(NotificationResponse response) {
    // Navigasi bisa ditambahkan di sini menggunakan global navigator key
    // Saat ini cukup log payload
    debugPrint('[LocalNotif] Tapped: payload=${response.payload}');
  }
}
