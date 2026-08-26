import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../shared/models/attendance.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/utils/formatting.dart';

/// Bottom sheet showing a single attendee's full info + attendance row.
/// Pure read view — no extra backend calls. Officer actions (mark present /
/// sign out) are delegated back to the caller via [onMarkPresent] /
/// [onSignOut] so the in-flight state stays owned by the monitor screen.
class AttendeeDetailSheet extends StatelessWidget {
  const AttendeeDetailSheet({
    super.key,
    required this.row,
    required this.event,
    required this.canManage,
    this.onMarkPresent,
    this.onSignOut,
  });

  final EventAttendee row;
  final AppEvent event;
  final bool canManage;
  final VoidCallback? onMarkPresent;
  final VoidCallback? onSignOut;

  static Future<void> show(
    BuildContext context, {
    required EventAttendee row,
    required AppEvent event,
    required bool canManage,
    VoidCallback? onMarkPresent,
    VoidCallback? onSignOut,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttendeeDetailSheet(
        row: row,
        event: event,
        canManage: canManage,
        onMarkPresent: onMarkPresent,
        onSignOut: onSignOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final label = row.labelFor(event.status);
    final tint = _tintFor(label, t);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.sheet)),
          border: Border.all(color: t.border.withOpacity(0.6)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x20, AppSpacing.x12,
                    AppSpacing.x20, AppSpacing.x8),
                children: [
                  _Hero(row: row, tint: tint, label: label),
                  const SizedBox(height: AppSpacing.x20),
                  _MetaSection(row: row),
                  const SizedBox(height: AppSpacing.x20),
                  _AttendanceSection(row: row, event: event),
                ],
              ),
            ),
            if (canManage &&
                (row.canMarkPresent || row.needsSignOut))
              _ActionFooter(
                row: row,
                onMarkPresent: onMarkPresent,
                onSignOut: onSignOut,
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x20, vertical: AppSpacing.x12),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadii.control),
                    ),
                    foregroundColor: t.textSecondary,
                  ),
                  child: Text(
                    'Close',
                    style: AppTypography.ui(
                      size: 14,
                      weight: FontWeight.w600,
                      color: t.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _tintFor(String label, AppTokens t) => switch (label) {
        'present' => t.present,
        'late' => t.tardy,
        'absent' => t.absent,
        'excused' => t.excused,
        'incomplete' => t.atRisk,
        'pending' => t.textMuted,
        _ => t.textMuted,
      };
}

class _Hero extends StatelessWidget {
  const _Hero({required this.row, required this.tint, required this.label});
  final EventAttendee row;
  final Color tint;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withOpacity(0.22),
                tint.withOpacity(0.06),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: tint.withOpacity(0.40), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: tint.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            row.initials,
            style: AppTypography.ui(
              size: 26,
              weight: FontWeight.w800,
              color: tint,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x16),
        Text(
          row.fullName,
          textAlign: TextAlign.center,
          style: AppTypography.ui(
            size: 22,
            weight: FontWeight.w800,
            color: t.ink,
            height: 1.15,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          row.studentNumber ?? '—',
          style: AppTypography.mono(
            size: 13,
            weight: FontWeight.w600,
            color: t.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.x12),
        _PhasePill(label: label),
      ],
    );
  }
}

class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label == 'pending') {
      final t = AppTokens.of(context);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty_rounded,
                size: 14, color: t.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Not yet checked in',
              style: AppTypography.ui(
                size: 12,
                weight: FontWeight.w700,
                color: t.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }
    return StatusChip.forStatus(context, label);
  }
}

class _MetaSection extends StatelessWidget {
  const _MetaSection({required this.row});
  final EventAttendee row;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final items = <_MetaItem>[];
    if (row.programName != null && row.programName!.trim().isNotEmpty) {
      items.add(_MetaItem(
        icon: Icons.school_rounded,
        label: 'Program',
        value: row.programName!,
      ));
    }
    if (row.yearLevel != null) {
      items.add(_MetaItem(
        icon: Icons.calendar_today_rounded,
        label: 'Year level',
        value: _yearLabel(row.yearLevel!),
      ));
    }
    if (row.email != null && row.email!.trim().isNotEmpty) {
      items.add(_MetaItem(
        icon: Icons.mail_outline_rounded,
        label: 'Email',
        value: row.email!,
      ));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x16),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1) ...[
              const SizedBox(height: AppSpacing.x12),
              Divider(
                  height: 1, thickness: 1, color: t.border.withOpacity(0.5)),
              const SizedBox(height: AppSpacing.x12),
            ],
          ],
        ],
      ),
    );
  }

  String _yearLabel(int n) {
    return switch (n) {
      1 => '1st year',
      2 => '2nd year',
      3 => '3rd year',
      4 => '4th year',
      5 => '5th year',
      _ => 'Year $n',
    };
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: t.surface,
            shape: BoxShape.circle,
            border: Border.all(color: t.border),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: t.textSecondary),
        ),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTypography.ui(
                  size: 10,
                  weight: FontWeight.w700,
                  color: t.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: AppTypography.ui(
                  size: 14,
                  weight: FontWeight.w600,
                  color: t.ink,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({required this.row, required this.event});
  final EventAttendee row;
  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final rec = row.record;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t.surface,
            t.surfaceAlt.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_rounded,
                  size: 16, color: t.textSecondary),
              const SizedBox(width: 6),
              Text(
                'ATTENDANCE',
                style: AppTypography.ui(
                  size: 11,
                  weight: FontWeight.w800,
                  color: t.textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x12),
          if (rec == null)
            _NoRecord(event: event)
          else ...[
            _TimeRow(
              icon: Icons.login_rounded,
              iconColor: t.present,
              label: 'CHECK-IN',
              time: rec.timeIn,
              fallback: '—',
            ),
            const SizedBox(height: AppSpacing.x12),
            Divider(
                height: 1, thickness: 1, color: t.border.withOpacity(0.5)),
            const SizedBox(height: AppSpacing.x12),
            _TimeRow(
              icon: Icons.logout_rounded,
              iconColor: rec.timeOut == null ? t.textMuted : t.textSecondary,
              label: 'SIGN-OUT',
              time: rec.timeOut,
              fallback: rec.timeOut == null && event.isOngoing
                  ? 'Pending — student is still here'
                  : '—',
            ),
            if (rec.timeIn != null && rec.timeOut != null) ...[
              const SizedBox(height: AppSpacing.x12),
              Divider(
                  height: 1, thickness: 1, color: t.border.withOpacity(0.5)),
              const SizedBox(height: AppSpacing.x12),
              _MetricRow(
                icon: Icons.timelapse_rounded,
                label: 'DURATION',
                value: _formatDuration(rec.timeOut!.difference(rec.timeIn!)),
              ),
            ],
            if (rec.method != null && rec.method!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x12),
              Divider(
                  height: 1, thickness: 1, color: t.border.withOpacity(0.5)),
              const SizedBox(height: AppSpacing.x12),
              _MetricRow(
                icon: Icons.fingerprint_rounded,
                label: 'METHOD',
                value: _formatMethod(rec.method!),
              ),
            ],
            if (rec.notes != null && rec.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x12),
              Divider(
                  height: 1, thickness: 1, color: t.border.withOpacity(0.5)),
              const SizedBox(height: AppSpacing.x12),
              _NotesBlock(notes: rec.notes!),
            ],
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h <= 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String _formatMethod(String m) {
    final lower = m.trim().toLowerCase();
    return switch (lower) {
      'face' || 'face_scan' => 'Face scan',
      'manual' => 'Marked by officer',
      'qr' => 'QR scan',
      'auto' => 'Auto-finalized',
      _ => m[0].toUpperCase() + m.substring(1),
    };
  }
}

class _NoRecord extends StatelessWidget {
  const _NoRecord({required this.event});
  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final ongoing = event.isOngoing || event.isUpcoming;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ongoing
              ? Icons.hourglass_empty_rounded
              : Icons.event_busy_rounded,
          size: 18,
          color: ongoing ? t.textSecondary : t.absent,
        ),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ongoing
                    ? 'No check-in recorded yet'
                    : 'Missed the event',
                style: AppTypography.ui(
                  size: 14,
                  weight: FontWeight.w700,
                  color: ongoing ? t.ink : t.absent,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                ongoing
                    ? 'The student may still arrive before the check-in window closes.'
                    : 'No attendance record was created — the student didn\'t sign in within the window.',
                style: AppTypography.ui(
                  size: 12,
                  weight: FontWeight.w500,
                  color: t.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.time,
    required this.fallback,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final DateTime? time;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.ui(
                  size: 10,
                  weight: FontWeight.w800,
                  color: t.textMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 3),
              if (time != null)
                Text(
                  fmtTime(time),
                  style: AppTypography.mono(
                    size: 18,
                    weight: FontWeight.w700,
                    color: t.ink,
                  ),
                )
              else
                Text(
                  fallback,
                  style: AppTypography.ui(
                    size: 13,
                    weight: FontWeight.w600,
                    color: t.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: t.textSecondary),
        const SizedBox(width: AppSpacing.x12),
        Text(
          label,
          style: AppTypography.ui(
            size: 11,
            weight: FontWeight.w700,
            color: t.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.ui(
            size: 13,
            weight: FontWeight.w700,
            color: t.ink,
          ),
        ),
      ],
    );
  }
}

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.note_alt_outlined, size: 16, color: t.textSecondary),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NOTES',
                style: AppTypography.ui(
                  size: 11,
                  weight: FontWeight.w700,
                  color: t.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                notes,
                style: AppTypography.ui(
                  size: 13,
                  weight: FontWeight.w500,
                  color: t.ink,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionFooter extends StatefulWidget {
  const _ActionFooter({
    required this.row,
    required this.onMarkPresent,
    required this.onSignOut,
  });
  final EventAttendee row;
  final VoidCallback? onMarkPresent;
  final VoidCallback? onSignOut;

  @override
  State<_ActionFooter> createState() => _ActionFooterState();
}

class _ActionFooterState extends State<_ActionFooter> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final row = widget.row;
    final isPresent = row.canMarkPresent;
    final cb = isPresent ? widget.onMarkPresent : widget.onSignOut;
    final label = isPresent ? 'Mark present' : 'Sign out';
    final icon = isPresent ? Icons.check_rounded : Icons.logout_rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.x20, AppSpacing.x8, AppSpacing.x20, 0),
      child: AnimatedScale(
        scale: _down ? AppMotion.pressScale : 1,
        duration: AppMotion.press,
        curve: AppMotion.easeOut,
        child: Material(
          color: isPresent ? t.accent : t.surface,
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.control),
            onTap: cb == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop();
                    cb();
                  },
            onHighlightChanged:
                cb == null ? null : (v) => setState(() => _down = v),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.control),
                border: isPresent
                    ? null
                    : Border.all(color: t.border),
                boxShadow: isPresent
                    ? [
                        BoxShadow(
                          color: t.accent.withOpacity(0.30),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: isPresent ? t.onAccent : t.ink, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTypography.ui(
                      size: 14,
                      weight: FontWeight.w800,
                      color: isPresent ? t.onAccent : t.ink,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
