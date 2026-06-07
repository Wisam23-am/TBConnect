import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Medication slot status  (mirrors RPC return values)
// ---------------------------------------------------------------------------
enum MedicationStatus {
  completed, // 'taken'
  active, // 'active'
  late, // 'late'
  missed, // 'missed'
  locked, // 'locked'
}

// ---------------------------------------------------------------------------
// Data model for one medication slot
// ---------------------------------------------------------------------------
class MedicationSlot {
  final String session; // 'morning' | 'afternoon' | 'evening'
  final String label;
  final String timeRange;
  final List<String> medications;
  final MedicationStatus status;
  final DateTime? takenAt;
  final String? lateReason;

  const MedicationSlot({
    required this.session,
    required this.label,
    required this.timeRange,
    required this.medications,
    required this.status,
    this.takenAt,
    this.lateReason,
  });
}

// ===========================================================================
// Medication card – renders differently based on MedicationStatus
// Clean OOP: uses a shared card shell with Strategy-like button injection
// ===========================================================================

/// Shared visual properties for each card variant.
class _CardVariant {
  final Color accentColor;
  final Color borderColor;
  final List<BoxShadow> shadows;
  final Color? bgColor;

  const _CardVariant({
    required this.accentColor,
    required this.borderColor,
    required this.shadows,
    this.bgColor,
  });
}

/// Shared card shell – every variant uses this same layout.
class MedicationCard extends StatelessWidget {
  final MedicationSlot slot;
  final VoidCallback? onConfirm;
  final VoidCallback? onLateReason;

  const MedicationCard({
    super.key,
    required this.slot,
    this.onConfirm,
    this.onLateReason,
  });

  static const _cardVariants = {
    MedicationStatus.completed: _CardVariant(
      accentColor: Color(0xFF2A609C),
      borderColor: Color(0x4CC4C6CF),
      shadows: [
        BoxShadow(
          color: Color(0x0C000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    ),
    MedicationStatus.active: _CardVariant(
      accentColor: Color(0xFF001833),
      borderColor: Color(0xFF001833),
      shadows: [
        BoxShadow(
          color: Color(0x14001833),
          blurRadius: 30,
          offset: Offset(0, 8),
        ),
      ],
    ),
    MedicationStatus.late: _CardVariant(
      accentColor: Color(0xFFE4A700),
      borderColor: Color(0xFFE19200),
      shadows: [
        BoxShadow(
          color: Color(0x14001833),
          blurRadius: 30,
          offset: Offset(0, 8),
        ),
      ],
    ),
    MedicationStatus.missed: _CardVariant(
      accentColor: Color(0xFFC50000),
      borderColor: Color(0xFFA60000),
      shadows: [
        BoxShadow(
          color: Color(0x14001833),
          blurRadius: 30,
          offset: Offset(0, 8),
        ),
      ],
    ),
    MedicationStatus.locked: _CardVariant(
      accentColor: Color(0xFF43474E),
      borderColor: Color(0xFFE1E3E4),
      shadows: [],
      bgColor: Color(0xFFF8F9FA),
    ),
  };

  @override
  Widget build(BuildContext context) {
    if (slot.status == MedicationStatus.late) {
      if (slot.lateReason != null && slot.lateReason!.isNotEmpty) {
        return _buildLateCompleted();
      }

      return _buildActionable(
        variant: _cardVariants[MedicationStatus.late]!,
        badge: _CornerBadge(
          label: 'Terlambat',
          bgColor: const Color(0xFFBA7600),
        ),
        button: _OutlinedButton(
          label: 'Catat Alasan Terlambat',
          onPressed: onLateReason,
        ),
      );
    }

    if (slot.status == MedicationStatus.completed || slot.takenAt != null) {
      return _buildCompleted();
    }

    switch (slot.status) {
      case MedicationStatus.late:
        return _buildLateCompleted();
      case MedicationStatus.completed:
        return _buildCompleted();
      case MedicationStatus.active:
        return _buildActionable(
          variant: _cardVariants[MedicationStatus.active]!,
          button: _FilledButton(
            label: 'Konfirmasi Minum Obat',
            onPressed: onConfirm,
          ),
        );
      case MedicationStatus.missed:
        return _buildActionable(
          variant: _cardVariants[MedicationStatus.missed]!,
          badge: _CornerBadge(
            label: 'Belum Minum Obat',
            bgColor: const Color(0xFFBA0000),
          ),
          button: _FilledButton(
            label: 'Konfirmasi Minum Obat',
            onPressed: onConfirm,
          ),
        );
      case MedicationStatus.locked:
        return _buildLocked();
    }
  }

  // ── Completed (no accent, no badge, no button) ──
  Widget _buildCompleted() {
    final v = _cardVariants[MedicationStatus.completed]!;
    return _CardFrame(
      borderColor: v.borderColor,
      shadows: v.shadows,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(label: slot.label, timeRange: slot.timeRange),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2A609C), size: 20),
              const SizedBox(width: 8),
              Text(
                'Selesai diminum',
                style: GoogleFonts.manrope(
                  color: const Color(0xFF2A609C),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Late completed (logged after window) ──
  Widget _buildLateCompleted() {
    final v = _cardVariants[MedicationStatus.late]!;
    return _CardFrame(
      borderColor: v.borderColor,
      shadows: v.shadows,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(label: slot.label, timeRange: slot.timeRange),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFBA7600), size: 20),
              const SizedBox(width: 8),
              Text(
                'Terlambat diminum',
                style: GoogleFonts.manrope(
                  color: const Color(0xFFBA7600),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (slot.lateReason != null && slot.lateReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Alasan: ${slot.lateReason}',
              style: GoogleFonts.manrope(
                color: const Color(0xFF43474E),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Actionable (accent bar + optional badge + meds + button) ──
  Widget _buildActionable({
    required _CardVariant variant,
    _CornerBadge? badge,
    required Widget button,
  }) {
    return _CardFrame(
      borderColor: variant.borderColor,
      shadows: variant.shadows,
      clip: true,
      padding: const EdgeInsets.all(24),
      stackChildren: [
        // Left accent bar
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 4,
            color: variant.accentColor,
          ),
        ),
        // Corner badge (if any)
        if (badge != null)
          Positioned(
            right: 0,
            top: 0,
            child: badge,
          ),
        // Content
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderRow(
                  label: slot.label, timeRange: slot.timeRange, dark: true),
              const SizedBox(height: 16),
              _MedicationList(medications: slot.medications),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: button),
            ],
          ),
        ),
      ],
    );
  }

  // ── Locked (muted, no interaction) ──
  Widget _buildLocked() {
    final v = _cardVariants[MedicationStatus.locked]!;
    return Opacity(
      opacity: 0.60,
      child: _CardFrame(
        borderColor: v.borderColor,
        shadows: v.shadows,
        bgColor: v.bgColor,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderRow(label: slot.label, timeRange: slot.timeRange),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.lock_rounded,
                    color: Color(0xFF43474E), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Terkunci',
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF43474E),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared card frame –  the outer container for all variants
// ═══════════════════════════════════════════════════════════════════════════
class _CardFrame extends StatelessWidget {
  final Color borderColor;
  final List<BoxShadow> shadows;
  final EdgeInsets padding;
  final bool clip;
  final Color? bgColor;
  final Widget? child;
  final List<Widget>? stackChildren;

  const _CardFrame({
    required this.borderColor,
    required this.shadows,
    required this.padding,
    this.clip = false,
    this.bgColor,
    this.child,
    this.stackChildren,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: double.infinity,
      padding: child != null ? padding : EdgeInsets.zero,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (stackChildren != null) {
      return Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: shadows,
        ),
        child: Stack(children: stackChildren!),
      );
    }

    return container;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Corner badge  –  "Terlambat" / "Belum Minum Obat"
// ═══════════════════════════════════════════════════════════════════════════
class _CornerBadge extends StatelessWidget {
  final String label;
  final Color bgColor;

  const _CornerBadge({required this.label, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.60,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Medication list  –  shared between actionable cards
// ═══════════════════════════════════════════════════════════════════════════
class _MedicationList extends StatelessWidget {
  final List<String> medications;
  const _MedicationList({required this.medications});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: medications
          .map((med) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  med,
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF43474E),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Button variants  –  filled (dark) / outlined
// ═══════════════════════════════════════════════════════════════════════════
class _FilledButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _FilledButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF001833),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.60,
        ),
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _OutlinedButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFC4C6CF)),
        foregroundColor: const Color(0xFF191C1D),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.60,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared header row  –  label + time range pill
// ═══════════════════════════════════════════════════════════════════════════
class _HeaderRow extends StatelessWidget {
  final String label;
  final String timeRange;
  final bool dark;

  const _HeaderRow({
    required this.label,
    required this.timeRange,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? const Color(0xFF001833) : const Color(0xFF43474E);
    final fontSize = dark ? 24.0 : 18.0;
    final fontWeight = dark ? FontWeight.w600 : FontWeight.w400;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time_rounded,
                size: 22, color: Color(0xFF43474E)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: textColor,
                fontSize: fontSize,
                fontWeight: fontWeight,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFFD4E3FF) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            timeRange,
            style: GoogleFonts.manrope(
              color: dark ? const Color(0xFF001833) : const Color(0xFF43474E),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.60,
            ),
          ),
        ),
      ],
    );
  }
}
