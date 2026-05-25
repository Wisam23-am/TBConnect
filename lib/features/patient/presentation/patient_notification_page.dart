import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../services/auth_service.dart';
import '../../../services/notification_realtime_service.dart';
import '../../../services/patient_service.dart';
import '../../../services/notification_service.dart';

// ---------------------------------------------------------------------------
// Domain Models
// ---------------------------------------------------------------------------
class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? payload;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.payload,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'].toString(),
      type: json['type'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }
}

/// Model untuk reminder minum obat yang ditampilkan di atas daftar notifikasi
class MedicationReminderCard {
  final String session; // morning | afternoon | evening
  final String label; // Pagi | Siang | Malam
  final String window; // 06:00 - 09:00
  final String status; // locked | active | late | taken | missed
  final DateTime? takenAt;

  const MedicationReminderCard({
    required this.session,
    required this.label,
    required this.window,
    required this.status,
    this.takenAt,
  });
}

// ---------------------------------------------------------------------------
// Main Notification Page
// ---------------------------------------------------------------------------
class PatientNotificationPage extends StatefulWidget {
  const PatientNotificationPage({super.key});

  @override
  State<PatientNotificationPage> createState() =>
      _PatientNotificationPageState();
}

class _PatientNotificationPageState extends State<PatientNotificationPage> {
  final _authService = AuthService();
  final _patientService = PatientDataService();
  final _realtimeService = NotificationRealtimeService.instance;

  List<NotificationModel> _notifications = [];
  List<MedicationReminderCard> _medicationReminders = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<NotificationSnapshot>? _notificationSubscription;
  Timer? _medicationRefreshTimer;
  final Set<String> _seenNotificationIds = {};
  String? _currentPatientId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _medicationRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final session = await _authService.getPatientSession();
    if (!mounted) return;

    if (session == null || session.patientId == 'guest') {
      setState(() {
        _notifications = _buildMockNotifications();
        _medicationReminders = _buildSimulatedReminders(DateTime.now());
        _isLoading = false;
      });
      return;
    }

    _currentPatientId = session.patientId;
    await _realtimeService.start(session.patientId);
    _notificationSubscription = _realtimeService.stream.listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _notifications = snapshot.notifications
            .map((e) => NotificationModel.fromJson(e))
            .toList();
        for (final item in snapshot.notifications) {
          final id = item['id']?.toString();
          if (id != null && id.isNotEmpty) {
            _seenNotificationIds.add(id);
          }
        }
        _isLoading = false;
      });
      _refreshMedicationStatus();
    });

    await _loadAll();
    _medicationRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshMedicationStatus(),
    );
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await Future.wait([
      _fetchNotifications(),
      _realtimeService.refreshNow(),
      _fetchMedicationStatus(),
    ]);
  }

  Future<void> _refreshMedicationStatus() async {
    await _fetchMedicationStatus();
  }

  // ──────────────────────────────────────────────────────────────
  // Fetch notifikasi dari Supabase
  // ──────────────────────────────────────────────────────────────
  Future<void> _fetchNotifications() async {
    try {
      final session = await _authService.getPatientSession();
      if (session == null || session.patientId == 'guest') {
        if (mounted) {
          setState(() {
            _notifications = _buildMockNotifications();
            _isLoading = false;
          });
        }
        return;
      }

      final data = await _patientService.getPatientNotifications(
        patientId: session.patientId,
      );
      if (mounted) {
        setState(() {
          _notifications =
              data.map((e) => NotificationModel.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat notifikasi:\n${_formatBackendError(e)}';
          _isLoading = false;
        });
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Fetch status obat hari ini untuk reminder card
  // ──────────────────────────────────────────────────────────────
  Future<void> _fetchMedicationStatus() async {
    try {
      final session = await _authService.getPatientSession();
      if (session == null || session.patientId == 'guest') {
        // Simulasi status saat guest/testing
        final now = DateTime.now();
        if (mounted) {
          setState(() {
            _medicationReminders = _buildSimulatedReminders(now);
          });
        }
        return;
      }

      final result = await _patientService.getTodayMedications(
        patientId: session.patientId,
      );
      final sessions =
          List<Map<String, dynamic>>.from(result['sessions'] ?? []);

      if (mounted) {
        setState(() {
          _medicationReminders = sessions
              .map((s) => MedicationReminderCard(
                    session: s['session'] as String? ?? '',
                    label: s['label'] as String? ?? '',
                    window: s['window'] as String? ?? '',
                    status: s['status'] as String? ?? 'locked',
                    takenAt: s['taken_at'] != null
                        ? DateTime.tryParse(s['taken_at'].toString())
                        : null,
                  ))
              .toList();
        });
      }
    } catch (_) {
      // Medication status tidak kritis — halaman tetap tampil
    }
  }

  List<MedicationReminderCard> _buildSimulatedReminders(DateTime now) {
    String resolveStatus(int startH, int endH) {
      if (now.hour < startH) return 'locked';
      if (now.hour >= startH && now.hour < endH) return 'active';
      return 'late';
    }

    return [
      MedicationReminderCard(
        session: 'morning',
        label: 'Pagi',
        window: '06:00 - 09:00',
        status: resolveStatus(6, 9),
      ),
      MedicationReminderCard(
        session: 'afternoon',
        label: 'Siang',
        window: '13:00 - 15:00',
        status: resolveStatus(13, 15),
      ),
      MedicationReminderCard(
        session: 'evening',
        label: 'Malam',
        window: '18:00 - 21:00',
        status: resolveStatus(18, 21),
      ),
    ];
  }

  List<NotificationModel> _buildMockNotifications() {
    return [
      NotificationModel(
        id: 'mock-1',
        type: 'medication_reminder',
        title: 'Pengingat Minum Obat Pagi',
        body:
            'Sudah masuk jadwal minum obat Pagi Anda. Silakan minum obat Anda dan tap konfirmasi.',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      NotificationModel(
        id: 'mock-2',
        type: 'doctor_feedback',
        title: 'Pesan dari dr. Budi Santoso, Sp.P',
        body:
            'Kepatuhan minum obat Anda sangat baik dalam seminggu terakhir. Pertahankan!',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      NotificationModel(
        id: 'mock-3',
        type: 'clinic_visit_reminder',
        title: 'Jadwal Kontrol 3 Hari Lagi',
        body: 'Kontrol berkala di Poli Paru - RSUD Dr. Soetomo, 27 Mei 2026.',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      NotificationModel(
        id: 'mock-4',
        type: 'emergency_ack',
        title: 'Konfirmasi Laporan Gejala Kritis',
        body:
            'Dokter Anda telah menerima laporan sesak napas. Tim medis akan segera memandu.',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }

  // ──────────────────────────────────────────────────────────────
  // Mark notification as read
  // ──────────────────────────────────────────────────────────────
  Future<void> _markAsRead(String notificationId, bool currentStatus) async {
    if (currentStatus) return;

    if (notificationId.startsWith('mock-')) {
      if (mounted) {
        setState(() {
          final index =
              _notifications.indexWhere((n) => n.id == notificationId);
          if (index != -1) {
            final n = _notifications[index];
            _notifications[index] = NotificationModel(
              id: n.id,
              type: n.type,
              title: n.title,
              body: n.body,
              isRead: true,
              createdAt: n.createdAt,
              payload: n.payload,
            );
          }
        });
      }
      return;
    }

    try {
      await _patientService.markNotificationRead(
        patientId: _currentPatientId ??
            (await _authService.getPatientSession())?.patientId ??
            '',
        notificationId: notificationId,
      );
      if (mounted) {
        setState(() {
          final index =
              _notifications.indexWhere((n) => n.id == notificationId);
          if (index != -1) {
            final n = _notifications[index];
            _notifications[index] = NotificationModel(
              id: n.id,
              type: n.type,
              title: n.title,
              body: n.body,
              isRead: true,
              createdAt: n.createdAt,
              payload: n.payload,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui:\n${_formatBackendError(e)}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  String _formatBackendError(Object error) {
    final dynamic e = error;
    final lines = <String>[];

    String? readField(String name) {
      try {
        final value = switch (name) {
          'message' => e.message,
          'details' => e.details,
          'hint' => e.hint,
          'code' => e.code,
          _ => null,
        };
        if (value == null) return null;
        final text = value.toString().trim();
        return text.isEmpty ? null : text;
      } catch (_) {
        return null;
      }
    }

    final message = readField('message') ?? error.toString();
    final details = readField('details');
    final hint = readField('hint');
    final code = readField('code');

    lines.add(message.replaceAll('Exception: ', '').trim());
    if (details != null && !lines.contains(details)) {
      lines.add(details);
    }
    if (hint != null && !lines.contains(hint)) {
      lines.add('Hint: $hint');
    }
    if (code != null && !lines.contains(code)) {
      lines.add('Code: $code');
    }

    return lines.join('\n');
  }

  // ──────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────
  IconData _getIconForType(String type) {
    switch (type) {
      case 'medication_reminder':
        return Icons.medical_services_outlined;
      case 'doctor_feedback':
        return Icons.message_outlined;
      case 'clinic_visit_reminder':
        return Icons.event_available_outlined;
      case 'weight_input_reminder':
        return Icons.monitor_weight_outlined;
      case 'emergency_ack':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'medication_reminder':
        return const Color(0xFF2A609C);
      case 'doctor_feedback':
        return const Color(0xFF00897B);
      case 'clinic_visit_reminder':
        return const Color(0xFFE65100);
      case 'emergency_ack':
        return const Color(0xFFD32F2F);
      case 'weight_input_reminder':
        return const Color(0xFF7B1FA2);
      default:
        return const Color(0xFF112D4E);
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} m lalu';
    if (diff.inDays < 1) return '${diff.inHours} j lalu';
    if (diff.inDays < 7) return '${diff.inDays} h lalu';
    return DateFormat('dd MMM').format(dt);
  }

  // ──────────────────────────────────────────────────────────────
  // Widget: Medication Reminder Section
  // ──────────────────────────────────────────────────────────────
  Widget _buildMedicationReminderSection() {
    // Hanya tampilkan jika ada sesi yang active atau late (perlu tindakan)
    final actionable = _medicationReminders
        .where((r) => r.status == 'active' || r.status == 'late')
        .toList();
    if (actionable.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Pengingat Minum Obat Hari Ini',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8A9BA8),
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...actionable.map((r) => _buildMedicationReminderCard(r)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Semua Notifikasi',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8A9BA8),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationReminderCard(MedicationReminderCard r) {
    final isActive = r.status == 'active';
    final isLate = r.status == 'late';

    final Color bgColor = isActive
        ? const Color(0xFFEBF5EB)
        : isLate
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFF8F9FA);
    final Color borderColor = isActive
        ? const Color(0xFF4CAF50)
        : isLate
            ? const Color(0xFFFF9800)
            : const Color(0xFFEDEEEF);
    final Color iconColor = isActive
        ? const Color(0xFF2E7D32)
        : isLate
            ? const Color(0xFFE65100)
            : const Color(0xFF8A9BA8);
    final IconData icon =
        isActive ? Icons.alarm_on_rounded : Icons.alarm_off_rounded;
    final String badgeText = isActive ? 'SEKARANG' : 'TERLAMBAT';
    final Color badgeColor =
        isActive ? const Color(0xFF2E7D32) : const Color(0xFFE65100);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Obat ${r.label}',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF112D4E),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Jadwal: ${r.window}',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: const Color(0xFF43474E),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: iconColor.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Widget: Notification List Item
  // ──────────────────────────────────────────────────────────────
  Widget _buildNotificationItem(NotificationModel notif) {
    final iconColor = _getColorForType(notif.type);
    return GestureDetector(
      onTap: () => _markAsRead(notif.id, notif.isRead),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.isRead
                ? const Color(0xFFEDEEEF)
                : const Color(0xFFD6E2F0),
            width: 1,
          ),
          boxShadow: notif.isRead
              ? []
              : [
                  const BoxShadow(
                    color: Color(0x0A112D4E),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  )
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(_getIconForType(notif.type), color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF112D4E),
                            fontSize: 14,
                            fontWeight: notif.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeAgo(notif.createdAt),
                        style: GoogleFonts.manrope(
                          color: const Color(0xFF8A9BA8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notif.body,
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF43474E),
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (!notif.isRead) ...[
              const SizedBox(width: 10),
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFE65100),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Empty & Error States
  // ──────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F4F8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined,
                size: 64, color: Color(0xFFC4C6CF)),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum ada notifikasi',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF112D4E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesan atau pengingat untuk Anda\nakan muncul di sini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
                fontSize: 14, color: const Color(0xFF5A8DA0)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Terjadi Kesalahan',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF112D4E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Gagal memuat notifikasi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                  fontSize: 14, color: const Color(0xFF5A8DA0)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF112D4E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Notifikasi',
          style: GoogleFonts.manrope(
            color: const Color(0xFF112D4E),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        // Add a close button on the top-left to dismiss this page
        iconTheme: const IconThemeData(color: Color(0xFF112D4E)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF112D4E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Tombol aktifkan notifikasi sistem Android
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined,
                color: Color(0xFF112D4E)),
            tooltip: 'Aktifkan pengingat harian',
            onPressed: () async {
              final granted =
                  await LocalNotificationService.instance.requestPermission();
              if (granted) {
                await LocalNotificationService.instance
                    .scheduleDailyMedicationReminders();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🔔 Pengingat harian diaktifkan',
                        style: GoogleFonts.manrope(color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFF2E7D32),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Izin notifikasi ditolak. Aktifkan di Pengaturan.',
                        style: GoogleFonts.manrope(color: Colors.white),
                      ),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFEDEEEF), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF112D4E)))
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  color: const Color(0xFF112D4E),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ── Medication Reminder Section ──
                      SliverToBoxAdapter(
                        child: _buildMedicationReminderSection(),
                      ),

                      // ── Notification List ──
                      if (_notifications.isEmpty)
                        SliverFillRemaining(
                          child: _buildEmptyState(),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildNotificationItem(
                                    _notifications[index]),
                              ),
                              childCount: _notifications.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
