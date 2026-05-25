import 'dart:async';

import 'package:flutter/foundation.dart';

import 'notification_service.dart';
import 'patient_service.dart';

class NotificationSnapshot {
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final List<Map<String, dynamic>> newNotifications;

  const NotificationSnapshot({
    required this.notifications,
    required this.unreadCount,
    required this.newNotifications,
  });
}

class NotificationRealtimeService {
  NotificationRealtimeService._();

  static final instance = NotificationRealtimeService._();

  final PatientDataService _patientService = PatientDataService();
  final StreamController<NotificationSnapshot> _controller =
      StreamController<NotificationSnapshot>.broadcast();

  Timer? _timer;
  String? _patientId;
  bool _isPolling = false;
  bool _hasSeeded = false;
  final Map<String, Map<String, dynamic>> _latestById = {};

  Stream<NotificationSnapshot> get stream => _controller.stream;

  bool get isActive => _timer != null;

  Future<void> start(String patientId) async {
    if (_patientId == patientId && _timer != null) return;

    stop();
    _patientId = patientId;
    _hasSeeded = false;
    _latestById.clear();

    await _poll();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _patientId = null;
    _hasSeeded = false;
    _latestById.clear();
  }

  Future<void> refreshNow() async {
    await _poll();
  }

  Future<void> _poll() async {
    if (_isPolling) return;
    final patientId = _patientId;
    if (patientId == null || patientId.isEmpty) return;

    _isPolling = true;
    try {
      final notifications = await _patientService.getPatientNotifications(
        patientId: patientId,
      );

      final unreadCount =
          notifications.where((n) => n['is_read'] == false).length;
      final newNotifications = <Map<String, dynamic>>[];

      for (final item in notifications) {
        final id = item['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        final previous = _latestById[id];
        if (previous == null && _hasSeeded) {
          newNotifications.add(item);
        }
        _latestById[id] = item;
      }

      _hasSeeded = true;

      if (newNotifications.isNotEmpty) {
        for (final item in newNotifications) {
          final type = item['type']?.toString() ?? 'general';
          if (type == 'doctor_feedback' ||
              type == 'medication_reminder' ||
              type == 'clinic_visit_reminder' ||
              type == 'weight_input_reminder' ||
              type == 'emergency_ack') {
            await LocalNotificationService.instance.showInstantNotification(
              id: DateTime.now().microsecondsSinceEpoch.remainder(2147483647),
              title: item['title']?.toString() ?? 'TBConnect',
              body: item['body']?.toString() ?? '',
            );
          }
        }
      }

      if (!_controller.isClosed) {
        _controller.add(NotificationSnapshot(
          notifications: notifications,
          unreadCount: unreadCount,
          newNotifications: newNotifications,
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationRealtimeService poll error: $e');
      }
    } finally {
      _isPolling = false;
    }
  }

  Future<void> dispose() async {
    stop();
    await _controller.close();
  }
}
