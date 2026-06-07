import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientVisitTimelineItem extends StatelessWidget {
  final Map<String, dynamic> visit;
  final String visualStatus; // 'done' | 'active' | 'locked'
  final bool isLast;
  final String Function(String) formatDateString;
  final void Function(Map<String, dynamic>) onReschedule;

  const PatientVisitTimelineItem({
    super.key,
    required this.visit,
    required this.visualStatus,
    required this.isLast,
    required this.formatDateString,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    final visitNum = visit['visit_number'] as int? ?? 1;

    Widget leftTimeline;
    Widget cardChild;

    if (visualStatus == 'done') {
      leftTimeline = _buildDoneTimeline();
      cardChild = _buildDoneCard(visitNum);
    } else if (visualStatus == 'active') {
      leftTimeline = _buildActiveTimeline();
      cardChild = _buildActiveCard(visitNum);
    } else {
      leftTimeline = _buildLockedTimeline();
      cardChild = _buildLockedCard(visitNum);
    }

    return SizedBox(
      height: visualStatus == 'active' ? 245 : 125,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leftTimeline,
          const SizedBox(width: 16),
          Expanded(child: cardChild),
        ],
      ),
    );
  }

  Widget _buildDoneTimeline() {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFF112D4E), width: 2),
          ),
          child: const Center(
            child:
                Icon(Icons.done_rounded, color: Color(0xFF112D4E), size: 16),
          ),
        ),
        if (!isLast)
          Expanded(
            child: Container(width: 2, color: const Color(0xFFE2E8F0)),
          ),
      ],
    );
  }

  Widget _buildDoneCard(int visitNum) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bulan $visitNum',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F8E8),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Selesai',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E824C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Text(
                'Selesai pada ${formatDateString(visit['scheduled_date'])}',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                visit['location'] ?? 'Puskesmas',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTimeline() {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFDBE2EF),
          ),
          child: Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF112D4E),
              ),
            ),
          ),
        ),
        if (!isLast)
          Expanded(
            child: Container(width: 2, color: const Color(0xFFE2E8F0)),
          ),
      ],
    );
  }

  Widget _buildActiveCard(int visitNum) {
    final rescheduleRequested = visit['reschedule_requested'] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C112D4E),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Garis kiri biru vertikal penanda kartu aktif
            Container(
              width: 4,
              color: const Color(0xFF112D4E),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bulan $visitNum',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF001833),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5F0FF),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            rescheduleRequested
                                ? 'Pindah Diajukan'
                                : 'Mendatang',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF112D4E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 14, color: Color(0xFF112D4E)),
                        const SizedBox(width: 8),
                        Text(
                          formatDateString(visit['scheduled_date']),
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF001833),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            visit['location'] ?? 'Puskesmas',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(
                        height: 1, thickness: 1, color: Color(0xFFEDF2F7)),
                    const SizedBox(height: 16),

                    // Cek jika sudah diajukan reschedule
                    if (rescheduleRequested)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9E6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFEAA7)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: Colors.orangeAccent, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Perpindahan jadwal diajukan ke: ${formatDateString(visit['reschedule_to_date'] ?? '')}. Menunggu persetujuan dokter.',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFD68F00),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => onReschedule(visit),
                          icon: const Icon(Icons.calendar_month_rounded,
                              size: 16),
                          label: Text(
                            'Ajukan Perpindahan Jadwal Kontrol',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF112D4E),
                            side: const BorderSide(
                                color: Color(0xFF112D4E), width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedTimeline() {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFCBD5E1),
              ),
            ),
          ),
        ),
        if (!isLast)
          Expanded(
            child: Container(width: 2, color: const Color(0xFFE2E8F0)),
          ),
      ],
    );
  }

  Widget _buildLockedCard(int visitNum) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bulan $visitNum',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Estimasi ${formatDateString(visit['scheduled_date'])}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const Icon(Icons.lock_outline_rounded,
              color: Color(0xFF94A3B8), size: 20),
        ],
      ),
    );
  }
}
