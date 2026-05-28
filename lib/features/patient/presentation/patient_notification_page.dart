import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/auth_service.dart';
import '../../../services/patient_service.dart';
import 'widgets/patient_medication_reminder_section.dart';
import 'widgets/patient_notification_item.dart';
import 'widgets/patient_notification_empty.dart';
import 'widgets/patient_notification_error.dart';

class PatientNotificationPage extends StatefulWidget {
  const PatientNotificationPage({super.key});

  @override
  State<PatientNotificationPage> createState() =>
      _PatientNotificationPageState();
}

class _PatientNotificationPageState extends State<PatientNotificationPage> {
  final _authService = AuthService();
  final _patientService = PatientDataService();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;
  String? _patientId;

  // State untuk jadwal obat mendesak (belum diminum hari ini)
  Map<String, dynamic>? _urgentMedicationSchedule;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await _authService.getPatientSession();
      if (session == null) throw Exception('Session not found');

      _patientId = session.patientId;

      // Load notifikasi
      final notifications = await _patientService.getPatientNotifications(
        patientId: session.patientId,
      );

      // Cek apakah ada obat hari ini yang statusnya urgent (aktif & belum diminum)
      final now = DateTime.now();
      
      final medResult = await _patientService.getTodayMedications(
        patientId: session.patientId,
        date: now,
      );
      final logs = List<Map<String, dynamic>>.from(medResult['sessions'] ?? []);

      Map<String, dynamic>? urgentSchedule;

      // Cari sesi yang waktunya masuk sekarang dan belum diminum
      final hour = now.hour;
      for (var log in logs) {
        if (log['taken_at'] == null) {
          final sessionName = log['session'] as String? ?? '';
          bool isUrgent = false;

          if (sessionName == 'morning' && hour >= 6 && hour <= 10) {
            isUrgent = true;
          } else if (sessionName == 'afternoon' && hour >= 12 && hour <= 16) {
            isUrgent = true;
          } else if (sessionName == 'evening' && hour >= 18 && hour <= 22) {
            isUrgent = true;
          }

          if (isUrgent) {
            urgentSchedule = {
              'label_id': sessionName,
              'medications': log['medications'] ??
                  ['Isoniazid, Rifampicin, Pyrazinamide', 'Ethambutol (Total 4 Tablet)'],
            };
            break; // Ambil satu saja yang urgent
          }
        }
      }

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _urgentMedicationSchedule = urgentSchedule;
          _isLoading = false;
        });
      }

      // Tandai semua sebagai dibaca setelah dimuat
      _markAllAsRead();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    if (_patientId == null) return;
    try {
      final unreadIds = _notifications
          .where((n) => n['is_read'] != true)
          .map((n) => n['id'] as String)
          .toList();

      for (String id in unreadIds) {
        await _patientService.markNotificationRead(
          patientId: _patientId!,
          notificationId: id,
        );
      }

      if (mounted) {
        setState(() {
          for (var n in _notifications) {
            n['is_read'] = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to mark notifications as read: $e');
    }
  }

  Future<void> _handleTakeMedication() async {
    if (_urgentMedicationSchedule == null) return;

    try {
      final session = await _authService.getPatientSession();
      if (session == null) return;

      final now = DateTime.now();

      await _patientService.logMedication(
        patientId: session.patientId,
        date: now,
        session: _urgentMedicationSchedule!['label_id'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Obat berhasil dicatat',
              style: GoogleFonts.manrope(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Refresh data
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mencatat obat: $e',
              style: GoogleFonts.manrope(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF112D4E)),
        title: Text(
          'Notifikasi',
          style: GoogleFonts.manrope(
            color: const Color(0xFF001833),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF112D4E)));
    }

    if (_error != null) {
      return PatientNotificationError(error: _error!, onRetry: _loadData);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF112D4E),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Bagian Pengingat Obat Mendesak
          if (_urgentMedicationSchedule != null)
            SliverToBoxAdapter(
              child: PatientMedicationReminderSection(
                schedule: _urgentMedicationSchedule!,
                onTakeMedication: _handleTakeMedication,
              ),
            ),

          // Daftar Notifikasi
          if (_notifications.isEmpty)
            const SliverFillRemaining(
              child: PatientNotificationEmpty(),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final notification = _notifications[index];
                  return PatientNotificationItem(
                    notification: notification,
                    onTap: () {
                      // Bisa navigasi sesuai tipe notifikasi jika perlu
                    },
                  );
                },
                childCount: _notifications.length,
              ),
            ),
        ],
      ),
    );
  }
}

