import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/attendance.dart';
import '../../../../shared/models/governance.dart';
import '../../application/governance_providers.dart';
import '../../data/governance_repository.dart';

/// Bottom sheet that lets an officer manually mark a student present for
/// the given event. Lists every roster student who does NOT already have
/// an attendance row, with a live search field.
class AddAttendanceSheet extends ConsumerStatefulWidget {
  const AddAttendanceSheet({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.unit,
  });

  final int eventId;
  final String eventName;
  final GovUnitAccess unit;

  static Future<AttendanceActionResult?> show(
    BuildContext context, {
    required int eventId,
    required String eventName,
    required GovUnitAccess unit,
  }) {
    return showModalBottomSheet<AttendanceActionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: AddAttendanceSheet(
          eventId: eventId,
          eventName: eventName,
          unit: unit,
        ),
      ),
    );
  }

  @override
  ConsumerState<AddAttendanceSheet> createState() => _AddAttendanceSheetState();
}

class _AddAttendanceSheetState extends ConsumerState<AddAttendanceSheet> {
  final _query = TextEditingController();
  EventAttendee? _selected;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pick = _selected;
    if (pick == null || pick.studentNumber == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(governanceRepositoryProvider)
          .markStudentPresent(
            eventId: widget.eventId,
            studentNumber: pick.studentNumber!,
            governanceContext: widget.unit.type,
          );
      ref.invalidate(eventAttendeesProvider(widget.eventId));
      ref.invalidate(eventAttendeesEnrichedProvider(widget.eventId));
      ref.invalidate(eventAbsentStudentsProvider(widget.eventId));
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final absentAsync =
        ref.watch(eventAbsentStudentsProvider(widget.eventId));

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.x20,
                  AppSpacing.x16, AppSpacing.x20, AppSpacing.x8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mark attendance',
                          style: AppTypography.ui(
                            size: 20,
                            weight: FontWeight.w800,
                            color: t.ink,
                            height: 1.15,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.eventName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.ui(
                            size: 13,
                            weight: FontWeight.w500,
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: t.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x20, 0, AppSpacing.x20, AppSpacing.x12),
              child: _SheetSearch(controller: _query, onChanged: (_) {
                setState(() {});
              }),
            ),
            Expanded(
              child: absentAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.x20),
                    child: Text(
                      e is ApiException
                          ? e.message
                          : 'Could not load roster.',
                      style: AppTypography.ui(
                          size: 14, color: t.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (list) {
                  final filtered = list
                      .where((s) =>
                          s.studentNumber != null &&
                          s.matchesQuery(_query.text))
                      .toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.x20),
                        child: Text(
                          list.isEmpty
                              ? 'Everyone on the roster has already checked in.'
                              : 'No students match "${_query.text}".',
                          textAlign: TextAlign.center,
                          style: AppTypography.ui(
                              size: 14, color: t.textSecondary),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x20,
                        vertical: AppSpacing.x4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.x8),
                    itemBuilder: (context, i) {
                      final s = filtered[i];
                      final picked = _selected?.studentProfileId ==
                          s.studentProfileId;
                      return _StudentTile(
                        student: s,
                        selected: picked,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selected = s);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x20, 0, AppSpacing.x20, AppSpacing.x8),
                child: Text(
                  _error!,
                  style: AppTypography.ui(
                      size: 13,
                      weight: FontWeight.w600,
                      color: t.absent),
                  textAlign: TextAlign.center,
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.x20,
                    AppSpacing.x8, AppSpacing.x20, AppSpacing.x16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadii.control),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTypography.ui(
                              size: 14,
                              weight: FontWeight.w600,
                              color: t.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x12),
                    Expanded(
                      flex: 2,
                      child: _ConfirmButton(
                        enabled: _selected != null && !_submitting,
                        busy: _submitting,
                        onPressed: _submit,
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
}

class _SheetSearch extends StatefulWidget {
  const _SheetSearch({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_SheetSearch> createState() => _SheetSearchState();
}

class _SheetSearchState extends State<_SheetSearch> {
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
        autofocus: true,
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

class _StudentTile extends StatefulWidget {
  const _StudentTile({
    required this.student,
    required this.selected,
    required this.onTap,
  });

  final EventAttendee student;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_StudentTile> createState() => _StudentTileState();
}

class _StudentTileState extends State<_StudentTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final s = widget.student;
    final selected = widget.selected;

    return AnimatedScale(
      scale: _down ? 0.985 : 1,
      duration: AppMotion.press,
      curve: AppMotion.easeOut,
      child: AnimatedContainer(
        duration: AppMotion.dropdown,
        curve: AppMotion.easeOut,
        decoration: BoxDecoration(
          color: selected ? t.accent.withOpacity(0.08) : t.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: selected ? t.accent : t.border,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: t.accent.withOpacity(0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _down = v),
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x12,
                  vertical: AppSpacing.x12),
              child: Row(
                children: [
                  _Avatar(initials: s.initials, selected: selected, tokens: t),
                  const SizedBox(width: AppSpacing.x12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.fullName,
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
                        Row(
                          children: [
                            Text(
                              s.studentNumber ?? '—',
                              style: AppTypography.mono(
                                  size: 12,
                                  weight: FontWeight.w500,
                                  color: t.textSecondary),
                            ),
                            if (s.programName != null) ...[
                              const SizedBox(width: AppSpacing.x8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                    color: t.textMuted,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: AppSpacing.x8),
                              Expanded(
                                child: Text(
                                  s.programName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.ui(
                                      size: 12,
                                      weight: FontWeight.w500,
                                      color: t.textSecondary),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x8),
                  AnimatedSwitcher(
                    duration: AppMotion.press,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: Tween(begin: 0.85, end: 1.0).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: selected
                        ? Icon(Icons.check_circle_rounded,
                            key: const ValueKey('on'),
                            color: t.accent,
                            size: 24)
                        : Icon(Icons.radio_button_unchecked_rounded,
                            key: const ValueKey('off'),
                            color: t.textMuted,
                            size: 24),
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

class _Avatar extends StatelessWidget {
  const _Avatar(
      {required this.initials, required this.selected, required this.tokens});
  final String initials;
  final bool selected;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [
                  tokens.accent.withOpacity(0.22),
                  tokens.accent.withOpacity(0.10),
                ]
              : [
                  tokens.surfaceAlt,
                  tokens.surfaceAlt.withOpacity(0.6),
                ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
            color: selected
                ? tokens.accent.withOpacity(0.5)
                : tokens.border),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTypography.ui(
          size: 13,
          weight: FontWeight.w800,
          color: selected ? tokens.ink : tokens.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatefulWidget {
  const _ConfirmButton({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final on = widget.enabled;
    return AnimatedScale(
      scale: _down ? AppMotion.pressScale : 1,
      duration: AppMotion.press,
      curve: AppMotion.easeOut,
      child: Material(
        color: on ? t.accent : t.border,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.control),
          onTap: on ? widget.onPressed : null,
          onHighlightChanged: on ? (v) => setState(() => _down = v) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.busy)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: t.onAccent,
                    ),
                  )
                else
                  Icon(Icons.check_rounded,
                      color: on ? t.onAccent : t.textMuted, size: 18),
                const SizedBox(width: 8),
                Text(
                  widget.busy ? 'Saving…' : 'Mark present',
                  style: AppTypography.ui(
                    size: 14,
                    weight: FontWeight.w700,
                    color: on ? t.onAccent : t.textMuted,
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
