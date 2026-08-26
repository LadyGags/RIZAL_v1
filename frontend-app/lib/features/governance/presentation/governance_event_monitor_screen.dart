import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/aura_card.dart';
import '../../../core/widgets/event_location_map.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_ring.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/attendance.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/governance.dart';
import '../../../shared/utils/formatting.dart';
import '../../schoolit/presentation/event_editor_screen.dart';
import '../application/governance_providers.dart';
import '../data/governance_repository.dart';
import 'widgets/add_attendance_sheet.dart';
import 'widgets/attendee_detail_sheet.dart';

enum _AttendeeFilter { all, present, late, absent }

extension _AttendeeFilterX on _AttendeeFilter {
  /// Phase-aware label. While the event is ongoing, "Absent" reads as
  /// "Pending" — the student hasn't checked in YET, and may still arrive.
  /// Once completed, the backend creates real absent rows for no-shows
  /// and the label is correct.
  String labelFor(String eventStatus) {
    final live = eventStatus.toLowerCase().trim() == 'ongoing' ||
        eventStatus.toLowerCase().trim() == 'upcoming';
    return switch (this) {
      _AttendeeFilter.all => 'All',
      _AttendeeFilter.present => 'Present',
      _AttendeeFilter.late => 'Late',
      _AttendeeFilter.absent => live ? 'Pending' : 'Absent',
    };
  }

  /// Phase-aware match. The Absent filter, while ongoing, scopes to the
  /// "pending" set (no record yet) instead of the literal backend
  /// `absent` status — which can't exist until finalization runs.
  bool matchesFor(EventAttendee e, String eventStatus) => switch (this) {
        _AttendeeFilter.all => true,
        _AttendeeFilter.present => e.isPresent,
        _AttendeeFilter.late => e.isLate,
        _AttendeeFilter.absent => e.labelFor(eventStatus) == 'absent' ||
            e.labelFor(eventStatus) == 'pending',
      };
}

/// Live attendance monitor for a governance event: stats + searchable
/// attendee list with status filters and (for officers with
/// `manage_attendance`) inline mark-present / sign-out actions.
class GovernanceEventMonitorScreen extends ConsumerStatefulWidget {
  const GovernanceEventMonitorScreen({super.key, required this.event});
  final AppEvent event;

  @override
  ConsumerState<GovernanceEventMonitorScreen> createState() =>
      _GovernanceEventMonitorScreenState();
}

class _GovernanceEventMonitorScreenState
    extends ConsumerState<GovernanceEventMonitorScreen> {
  _AttendeeFilter _filter = _AttendeeFilter.all;
  final _searchCtl = TextEditingController();
  int? _busyRowId;

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _openDetail(
      EventAttendee row, bool canManage, GovUnitAccess? unit) async {
    await AttendeeDetailSheet.show(
      context,
      row: row,
      event: widget.event,
      canManage: canManage,
      onMarkPresent: (canManage && unit != null && row.canMarkPresent)
          ? () => _markPresent(row, unit)
          : null,
      onSignOut: (canManage && unit != null && row.needsSignOut)
          ? () => _signOut(row, unit)
          : null,
    );
  }

  Future<void> _openAddSheet(GovUnitAccess unit) async {
    final r = await AddAttendanceSheet.show(
      context,
      eventId: widget.event.id,
      eventName: widget.event.name,
      unit: unit,
    );
    if (r != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.message ?? 'Marked present.')),
      );
    }
  }

  Future<void> _markPresent(EventAttendee row, GovUnitAccess unit) async {
    final sn = row.studentNumber;
    if (sn == null) return;
    setState(() => _busyRowId = -row.studentProfileId);
    try {
      final res = await ref
          .read(governanceRepositoryProvider)
          .markStudentPresent(
            eventId: widget.event.id,
            studentNumber: sn,
            governanceContext: unit.type,
          );
      HapticFeedback.mediumImpact();
      ref.invalidate(eventAttendeesProvider(widget.event.id));
      ref.invalidate(eventAttendeesEnrichedProvider(widget.event.id));
      ref.invalidate(eventAbsentStudentsProvider(widget.event.id));
      ref.invalidate(eventStatsProvider(widget.event.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  res.message ?? 'Marked ${row.fullName} present.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: AppTokens.of(context).absent,
              content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busyRowId = null);
    }
  }

  Future<void> _signOut(EventAttendee row, GovUnitAccess unit) async {
    final rec = row.record;
    if (rec == null) return;
    setState(() => _busyRowId = rec.id);
    try {
      final res = await ref
          .read(governanceRepositoryProvider)
          .markStudentSignedOut(rec.id, governanceContext: unit.type);
      HapticFeedback.mediumImpact();
      ref.invalidate(eventAttendeesProvider(widget.event.id));
      ref.invalidate(eventAttendeesEnrichedProvider(widget.event.id));
      ref.invalidate(eventStatsProvider(widget.event.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  res.message ?? 'Signed out ${row.fullName}.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: AppTokens.of(context).absent,
              content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busyRowId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final unit = ref.watch(effectiveUnitProvider);
    final statsAsync = ref.watch(eventStatsProvider(widget.event.id));
    final attendeesAsync =
        ref.watch(eventAttendeesEnrichedProvider(widget.event.id));
    final canManage = unit != null && unit.can('manage_attendance');

    return AppScaffold(
      title: widget.event.name,
      actions: (unit != null && unit.can('manage_events'))
          ? [
              IconButton(
                tooltip: 'Edit event',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => EventEditorScreen(
                          event: widget.event, governanceContext: unit.type),
                    ),
                  );
                  if (changed == true && context.mounted) {
                    ref.invalidate(governanceEventsProvider(unit.type));
                    Navigator.of(context).pop();
                  }
                },
              ),
            ]
          : null,
      body: Stack(
        children: [
          RefreshIndicator(
            color: t.accent,
            backgroundColor: t.surface,
            onRefresh: () async {
              ref.invalidate(governanceStudentsProvider);
              await Future.wait([
                ref.refresh(eventStatsProvider(widget.event.id).future),
                ref.refresh(
                    eventAttendeesEnrichedProvider(widget.event.id).future),
              ]);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.x20,
                AppSpacing.x20,
                AppSpacing.x20,
                canManage ? 96 : AppSpacing.x20,
              ),
              children: [
                statsAsync.when(
                  loading: () => const AuraCard(
                      child: SizedBox(
                          height: 120,
                          child:
                              Center(child: CircularProgressIndicator()))),
                  error: (e, _) => AuraCard(
                    child: Text(
                        e is ApiException ? e.message : 'Stats unavailable',
                        style: AppTypography.ui(
                            color: t.textSecondary, size: 14)),
                  ),
                  data: (s) => _StatsCard(stats: s),
                ),
                const SizedBox(height: AppSpacing.x24),
                if (widget.event.hasGeo) ...[
                  const SectionHeader(title: 'Location'),
                  const SizedBox(height: AppSpacing.x12),
                  EventLocationMap(
                    lat: widget.event.geoLatitude!,
                    lng: widget.event.geoLongitude!,
                    radiusM: widget.event.geoRadiusM ?? 100,
                  ),
                  const SizedBox(height: AppSpacing.x24),
                ],
                Row(
                  children: [
                    const SectionHeader(title: 'Attendees'),
                    const Spacer(),
                    attendeesAsync.whenOrNull(
                          data: (l) => Text(
                            '${l.length} students',
                            style: AppTypography.ui(
                              size: 12,
                              weight: FontWeight.w600,
                              color: t.textSecondary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ) ??
                        const SizedBox.shrink(),
                  ],
                ),
                const SizedBox(height: AppSpacing.x16),
                attendeesAsync.when(
                  loading: () => const LoadingCardList(count: 5),
                  error: (e, _) => ErrorView(
                    message: e is ApiException
                        ? e.message
                        : 'Could not load attendees.',
                    onRetry: () => ref.invalidate(
                        eventAttendeesEnrichedProvider(widget.event.id)),
                  ),
                  data: (list) => _AttendeesPanel(
                    rows: list,
                    event: widget.event,
                    filter: _filter,
                    query: _searchCtl.text,
                    searchCtl: _searchCtl,
                    onFilterChanged: (f) => setState(() => _filter = f),
                    onQueryChanged: (_) => setState(() {}),
                    canManage: canManage,
                    busyRowId: _busyRowId,
                    onMarkPresent: canManage
                        ? (row) => _markPresent(row, unit)
                        : null,
                    onSignOut:
                        canManage ? (row) => _signOut(row, unit) : null,
                    onTap: (row) => _openDetail(row, canManage, unit),
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            Positioned(
              right: AppSpacing.x20,
              bottom: AppSpacing.x20,
              child: SafeArea(
                child: _AccentFab(
                  onPressed: () => _openAddSheet(unit),
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Add attendance',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom press-scaled FAB so the accent button feels physical
/// (emil rule: press scale 0.97, 120 ms ease-out).
class _AccentFab extends StatefulWidget {
  const _AccentFab({
    required this.onPressed,
    required this.icon,
    required this.label,
  });
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  State<_AccentFab> createState() => _AccentFabState();
}

class _AccentFabState extends State<_AccentFab> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return AnimatedScale(
      scale: _down ? AppMotion.pressScale : 1,
      duration: AppMotion.press,
      curve: AppMotion.easeOut,
      child: Material(
        color: t.accent,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        elevation: 0,
        shadowColor: t.accent.withOpacity(0.35),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onPressed();
          },
          onHighlightChanged: (v) => setState(() => _down = v),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x20, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: [
                BoxShadow(
                  color: t.accent.withOpacity(0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: t.onAccent, size: 20),
                const SizedBox(width: AppSpacing.x8),
                Text(
                  widget.label,
                  style: AppTypography.ui(
                    size: 14,
                    weight: FontWeight.w700,
                    color: t.onAccent,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendeesPanel extends StatelessWidget {
  const _AttendeesPanel({
    required this.rows,
    required this.event,
    required this.filter,
    required this.query,
    required this.searchCtl,
    required this.onFilterChanged,
    required this.onQueryChanged,
    required this.canManage,
    required this.busyRowId,
    required this.onMarkPresent,
    required this.onSignOut,
    required this.onTap,
  });

  final List<EventAttendee> rows;
  final AppEvent event;
  final _AttendeeFilter filter;
  final String query;
  final TextEditingController searchCtl;
  final ValueChanged<_AttendeeFilter> onFilterChanged;
  final ValueChanged<String> onQueryChanged;
  final bool canManage;
  final int? busyRowId;
  final void Function(EventAttendee)? onMarkPresent;
  final void Function(EventAttendee)? onSignOut;
  final void Function(EventAttendee) onTap;

  @override
  Widget build(BuildContext context) {
    final eventStatus = event.status;
    int absentLike(EventAttendee e) {
      final l = e.labelFor(eventStatus);
      return (l == 'absent' || l == 'pending') ? 1 : 0;
    }

    final counts = <_AttendeeFilter, int>{
      _AttendeeFilter.all: rows.length,
      _AttendeeFilter.present: rows.where((e) => e.isPresent).length,
      _AttendeeFilter.late: rows.where((e) => e.isLate).length,
      _AttendeeFilter.absent: rows.fold<int>(0, (a, e) => a + absentLike(e)),
    };

    final filtered = rows
        .where((e) => filter.matchesFor(e, eventStatus))
        .where((e) => e.matchesQuery(query))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterBar(
          filter: filter,
          counts: counts,
          eventStatus: eventStatus,
          onChanged: onFilterChanged,
        ),
        const SizedBox(height: AppSpacing.x12),
        _SearchField(
          controller: searchCtl,
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: AppSpacing.x16),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x16),
            child: EmptyState(
              icon: filter == _AttendeeFilter.absent
                  ? Icons.celebration_rounded
                  : Icons.how_to_reg_outlined,
              title: _emptyTitle(),
              message: _emptyMessage(),
            ),
          )
        else
          AnimatedSwitcher(
            duration: AppMotion.dropdown,
            switchInCurve: AppMotion.easeOut,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: child,
            ),
            child: Column(
              key: ValueKey('${filter.name}|$query|${filtered.length}'),
              children: [
                for (var i = 0; i < filtered.length; i++)
                  _RowEntrance(
                    key: ValueKey(
                        'row-${filtered[i].studentProfileId}'),
                    index: i,
                    reduceMotion: MediaQuery.disableAnimationsOf(context),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.x12),
                      child: _AttendeeRow(
                        row: filtered[i],
                        eventStatus: eventStatus,
                        canManage: canManage,
                        busy: _isBusy(filtered[i]),
                        onTap: () => onTap(filtered[i]),
                        onMarkPresent: onMarkPresent,
                        onSignOut: onSignOut,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  bool _isBusy(EventAttendee row) {
    if (busyRowId == null) return false;
    if (row.record?.id == busyRowId) return true;
    if (busyRowId == -row.studentProfileId) return true;
    return false;
  }

  String _emptyTitle() {
    final live = event.isOngoing || event.isUpcoming;
    return switch (filter) {
      _AttendeeFilter.all => 'No attendees yet',
      _AttendeeFilter.present => 'No present students',
      _AttendeeFilter.late => 'No late check-ins',
      _AttendeeFilter.absent =>
        live ? 'Everyone is here' : 'Everyone is accounted for',
    };
  }

  String _emptyMessage() {
    final live = event.isOngoing || event.isUpcoming;
    if (query.isNotEmpty) return 'No matches for "$query".';
    return switch (filter) {
      _AttendeeFilter.all => 'Attendees appear here as they check in.',
      _AttendeeFilter.present =>
        'When students sign in, they show up here.',
      _AttendeeFilter.late => 'No one has checked in late.',
      _AttendeeFilter.absent => live
          ? 'Every roster student has checked in for this event.'
          : 'Every roster student has a recorded check-in.',
    };
  }
}

/// First-mount fade + lift for list rows. Stagger 40 ms per index
/// (capped at 8 to keep long lists snappy). Honours reduce-motion.
class _RowEntrance extends StatefulWidget {
  const _RowEntrance({
    super.key,
    required this.index,
    required this.child,
    required this.reduceMotion,
  });
  final int index;
  final Widget child;
  final bool reduceMotion;

  @override
  State<_RowEntrance> createState() => _RowEntranceState();
}

class _RowEntranceState extends State<_RowEntrance> {
  bool _on = false;
  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _on = true;
    } else {
      final delay = 40 * widget.index.clamp(0, 8);
      Future<void>.delayed(Duration(milliseconds: delay), () {
        if (mounted) setState(() => _on = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _on ? Offset.zero : const Offset(0, 0.06),
      duration: AppMotion.modal,
      curve: AppMotion.easeOut,
      child: AnimatedOpacity(
        opacity: _on ? 1 : 0,
        duration: AppMotion.modal,
        curve: AppMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return AnimatedContainer(
      duration: AppMotion.dropdown,
      curve: AppMotion.easeOut,
      decoration: BoxDecoration(
        color: _focused ? t.surface : t.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(
          color: _focused ? t.accent : t.border,
          width: _focused ? 1.4 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: t.accent.withOpacity(0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: AppTypography.ui(size: 14, color: t.ink),
        decoration: InputDecoration(
          hintText: 'Search by name or student ID',
          hintStyle:
              AppTypography.ui(size: 14, color: t.textMuted),
          prefixIcon: Icon(Icons.search_rounded,
              size: 20, color: _focused ? t.accent : t.textMuted),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                  },
                ),
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x12, vertical: AppSpacing.x12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

/// Segmented filter bar with a single sliding indicator (AnimatedAlign +
/// LayoutBuilder so the pill shifts continuously between the four cells).
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.counts,
    required this.eventStatus,
    required this.onChanged,
  });

  final _AttendeeFilter filter;
  final Map<_AttendeeFilter, int> counts;
  final String eventStatus;
  final ValueChanged<_AttendeeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    const values = _AttendeeFilter.values;
    final activeIndex = values.indexOf(filter);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: t.border),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final cellW = c.maxWidth / values.length;
          return SizedBox(
            height: 40,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: AppMotion.dropdown,
                  curve: AppMotion.easeOut,
                  left: cellW * activeIndex,
                  top: 0,
                  bottom: 0,
                  width: cellW,
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final f in values)
                      Expanded(
                        child: _FilterCell(
                          label: f.labelFor(eventStatus),
                          count: counts[f] ?? 0,
                          selected: filter == f,
                          accent: _accentForFilter(t, f, eventStatus),
                          onTap: () => onChanged(f),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _accentForFilter(
      AppTokens t, _AttendeeFilter f, String eventStatus) {
    final live = eventStatus.toLowerCase().trim() == 'ongoing' ||
        eventStatus.toLowerCase().trim() == 'upcoming';
    return switch (f) {
      _AttendeeFilter.all => t.ink,
      _AttendeeFilter.present => t.present,
      _AttendeeFilter.late => t.tardy,
      // "Pending" while ongoing reads neutral; flips to red once
      // the backend has finalized real Absent rows.
      _AttendeeFilter.absent => live ? t.textSecondary : t.absent,
    };
  }
}

class _FilterCell extends StatelessWidget {
  const _FilterCell({
    required this.label,
    required this.count,
    required this.selected,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.dropdown,
                curve: AppMotion.easeOut,
                style: AppTypography.ui(
                  size: 13,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : t.textSecondary,
                  letterSpacing: 0.1,
                ),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedContainer(
              duration: AppMotion.dropdown,
              curve: AppMotion.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? accent.withOpacity(0.18) : t.border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: AppTypography.mono(
                  size: 11,
                  weight: FontWeight.w700,
                  color: selected ? accent : t.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendeeRow extends StatefulWidget {
  const _AttendeeRow({
    required this.row,
    required this.eventStatus,
    required this.canManage,
    required this.busy,
    required this.onTap,
    required this.onMarkPresent,
    required this.onSignOut,
  });

  final EventAttendee row;
  final String eventStatus;
  final bool canManage;
  final bool busy;
  final VoidCallback onTap;
  final void Function(EventAttendee)? onMarkPresent;
  final void Function(EventAttendee)? onSignOut;

  @override
  State<_AttendeeRow> createState() => _AttendeeRowState();
}

class _AttendeeRowState extends State<_AttendeeRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final row = widget.row;
    final label = row.labelFor(widget.eventStatus);

    return AnimatedScale(
      scale: _down ? 0.985 : 1,
      duration: AppMotion.press,
      curve: AppMotion.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: t.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onHighlightChanged: (v) => setState(() => _down = v),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RowAvatar(label: label, initials: row.initials, tokens: t),
                    const SizedBox(width: AppSpacing.x12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.fullName,
                            style: AppTypography.ui(
                              size: 15,
                              weight: FontWeight.w700,
                              color: t.ink,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            row.studentNumber ?? '—',
                            style: AppTypography.mono(
                              size: 12,
                              weight: FontWeight.w500,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PhaseAwareChip(label: label),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: t.textMuted),
                  ],
                ),
                if (row.record != null) ...[
                  const SizedBox(height: AppSpacing.x12),
                  _TimeStrip(record: row.record!, tokens: t),
                ],
                if (widget.canManage &&
                    (row.canMarkPresent || row.needsSignOut)) ...[
                  const SizedBox(height: AppSpacing.x12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _InlineAction(
                      busy: widget.busy,
                      row: row,
                      onMarkPresent: widget.onMarkPresent,
                      onSignOut: widget.onSignOut,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders the row's status pill. While ongoing, a `pending` label gets a
/// neutral hourglass chip ("Not yet") so a no-show in-flight never looks
/// like a verdict; everything else goes through the standard [StatusChip].
class _PhaseAwareChip extends StatelessWidget {
  const _PhaseAwareChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label != 'pending') {
      return StatusChip.forStatus(context, label);
    }
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x12, vertical: AppSpacing.x4),
      decoration: BoxDecoration(
        color: t.textSecondary.withOpacity(0.10),
        borderRadius: AppRadii.rPill,
        border: Border.all(color: t.textSecondary.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty_rounded,
              size: 14, color: t.textSecondary),
          const SizedBox(width: 4),
          Text(
            'Not yet',
            style: AppTypography.ui(
              size: 12,
              weight: FontWeight.w700,
              color: t.textSecondary,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowAvatar extends StatelessWidget {
  const _RowAvatar(
      {required this.label, required this.initials, required this.tokens});
  final String label;
  final String initials;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final tint = switch (label) {
      'present' => tokens.present,
      'late' => tokens.tardy,
      'absent' => tokens.absent,
      'excused' => tokens.excused,
      'incomplete' => tokens.atRisk,
      _ => tokens.textMuted,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withOpacity(0.18),
            tint.withOpacity(0.08),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: tint.withOpacity(0.35), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTypography.ui(
          size: 13,
          weight: FontWeight.w800,
          color: tint,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _TimeStrip extends StatelessWidget {
  const _TimeStrip({required this.record, required this.tokens});
  final AttendanceRecord record;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.x8,
      runSpacing: 4,
      children: [
        _TimePill(
          icon: Icons.login_rounded,
          label: 'In',
          time: record.timeIn,
          color: tokens.present,
        ),
        _TimePill(
          icon: Icons.logout_rounded,
          label: 'Out',
          time: record.timeOut,
          color: record.timeOut == null
              ? tokens.textMuted
              : tokens.textSecondary,
        ),
      ],
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });
  final IconData icon;
  final String label;
  final DateTime? time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.x8, vertical: 5),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: AppTypography.ui(
              size: 10,
              weight: FontWeight.w700,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            fmtTime(time),
            style: AppTypography.mono(
              size: 12,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.busy,
    required this.row,
    required this.onMarkPresent,
    required this.onSignOut,
  });
  final bool busy;
  final EventAttendee row;
  final void Function(EventAttendee)? onMarkPresent;
  final void Function(EventAttendee)? onSignOut;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    if (row.canMarkPresent) {
      return _ActionButton(
        icon: Icons.check_rounded,
        iconColor: t.present,
        label: busy ? 'Saving…' : 'Mark present',
        borderColor: t.present.withOpacity(0.45),
        busy: busy,
        onTap: onMarkPresent == null ? null : () => onMarkPresent!(row),
      );
    }
    if (row.needsSignOut) {
      return _ActionButton(
        icon: Icons.logout_rounded,
        iconColor: t.textSecondary,
        label: busy ? 'Saving…' : 'Sign out',
        borderColor: t.border,
        busy: busy,
        onTap: onSignOut == null ? null : () => onSignOut!(row),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.borderColor,
    required this.busy,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color borderColor;
  final bool busy;
  final VoidCallback? onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final enabled = widget.onTap != null && !widget.busy;
    return AnimatedScale(
      scale: _down ? AppMotion.pressScale : 1,
      duration: AppMotion.press,
      curve: AppMotion.easeOut,
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.control),
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                }
              : null,
          onHighlightChanged:
              enabled ? (v) => setState(() => _down = v) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: widget.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.busy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(widget.icon, color: widget.iconColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: AppTypography.ui(
                    size: 13,
                    weight: FontWeight.w700,
                    color: enabled ? t.ink : t.textMuted,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final EventStats stats;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final present = stats.countOf('present');
    final rate = stats.total > 0 ? (present / stats.total) * 100 : 0.0;

    return AuraCard(
      child: Row(
        children: [
          StatRing(percent: rate, size: 96, label: 'Present'),
          const SizedBox(width: AppSpacing.x20),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.x8,
              runSpacing: AppSpacing.x8,
              children: [
                _CountChip('Present', stats.countOf('present'), t.present),
                _CountChip('Late', stats.countOf('late'), t.tardy),
                _CountChip('Absent', stats.countOf('absent'), t.absent),
                _CountChip('Excused', stats.countOf('excused'), t.excused),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x12, vertical: AppSpacing.x8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: AppTypography.mono(
                size: 13, weight: FontWeight.w800, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.ui(
                size: 12, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
