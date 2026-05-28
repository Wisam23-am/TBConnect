import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/notification_realtime_service.dart';
import '../patient_notification_page.dart';

class PatientHomeHeader extends StatelessWidget {
  final String name;
  final NotificationRealtimeService realtimeService;

  const PatientHomeHeader({
    super.key,
    required this.name,
    required this.realtimeService,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF112D4E), Color(0xFF3F72AF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                initial,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Halo, $name',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.22,
                ),
              ),
            ),
            const Spacer(),
            StreamBuilder<NotificationSnapshot>(
              stream: realtimeService.stream,
              builder: (context, snapshot) {
                final unreadCount = snapshot.data?.unreadCount ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      color: Colors.white.withOpacity(0.2),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PatientNotificationPage(),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.notifications,
                              size: 26, color: Colors.white),
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
