import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientNotificationItem extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const PatientNotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData getIconForType() {
      switch (notification['type']) {
        case 'medication_reminder':
          return Icons.medication_rounded;
        case 'control_reminder':
          return Icons.calendar_month_rounded;
        case 'symptom_alert':
          return Icons.warning_rounded;
        case 'chat_message':
          return Icons.chat_bubble_rounded;
        default:
          return Icons.notifications_rounded;
      }
    }

    Color getColorForType() {
      switch (notification['type']) {
        case 'medication_reminder':
          return const Color(0xFF2A609C);
        case 'control_reminder':
          return const Color(0xFF059669); // Emerald
        case 'symptom_alert':
          return const Color(0xFFDC2626); // Red
        case 'chat_message':
          return const Color(0xFFD97706); // Amber
        default:
          return const Color(0xFF64748B); // Slate
      }
    }

    final isUnread = notification['is_read'] != true;
    final iconColor = getColorForType();
    final bgColor = iconColor.withValues(alpha: 0.1);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread ? const Color(0xFFF8FAFC) : Colors.white,
          border: Border(
            bottom: const BorderSide(color: Color(0xFFF1F5F9)),
            left: BorderSide(
              color: isUnread ? const Color(0xFF112D4E) : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(getIconForType(), color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification['title'] ?? 'Notifikasi',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight:
                                isUnread ? FontWeight.w700 : FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeAgo(notification['created_at']),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _notificationBody(notification),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _notificationBody(Map<String, dynamic> notification) {
    final message = notification['message']?.toString().trim();
    final body = notification['body']?.toString().trim();
    final payload = notification['payload']?.toString().trim();

    if (message?.isNotEmpty == true) return message!;
    if (body?.isNotEmpty == true) return body!;
    if (payload?.isNotEmpty == true) return payload!;
    return '';
  }

  String _formatTimeAgo(dynamic createdAt) {
    if (createdAt == null) return '';
    final dateTime = DateTime.tryParse(createdAt.toString());
    if (dateTime == null) return '';

    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}j';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Baru';
    }
  }
}
