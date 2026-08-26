import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/live_ticker.dart';
import '../../../core/realtime/polling_pace.dart';
import '../../../shared/models/attendance.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/governance.dart';
import '../../../shared/models/sanctions.dart';
import '../../../shared/models/school.dart';
import '../../events/data/events_repository.dart';
import '../../schoolit/data/schoolit_repository.dart';
import '../data/governance_repository.dart';
import '../data/sanctions_repository.dart';

/// The user's governance access (units + permissions). Drives the workspace.
final governanceAccessProvider =
    FutureProvider.autoDispose<GovernanceAccess>((ref) async {
  return ref.watch(governanceRepositoryProvider).accessMe();
});

/// Current student's own sanction records (`GET /api/sanctions/students/me`).
///
/// Returns an empty list when the student has no outstanding sanctions or
/// when the backend declines the request with a status code that should
/// be treated as "nothing to show":
///   * 404 — endpoint reports no records / no student profile (older
///     backend deploys returned this instead of `[]`).
///   * 403 — the account isn't a student (officer-only login that still
///     happens to surface the tile during workspace switching).
/// Anything else (500s, network failures) bubbles up so the screen can
/// render a real, retryable error with the actual status code visible.
final mySanctionsProvider =
    FutureProvider.autoDispose<List<SanctionRecord>>((ref) async {
  ref.watch(livePollingTickerProvider(PollingPace.slow));
  try {
    return await ref.watch(sanctionsRepositoryProvider).mine();
  } on ApiException catch (e) {
    if (e.isNotFound || e.isForbidden) return const <SanctionRecord>[];
    rethrow;
  }
});

/// School-wide active clearance deadline. Null when none is set or when
/// the backend declines (404 / 403) — same gentle-fallback policy as
/// [mySanctionsProvider] so a missing deadline never paints the whole
/// screen red.
final activeClearanceDeadlineProvider =
    FutureProvider.autoDispose<ClearanceDeadline?>((ref) async {
  try {
    return await ref.watch(sanctionsRepositoryProvider).activeClearanceDeadline();
  } on ApiException catch (e) {
    if (e.isNotFound || e.isForbidden) return null;
    rethrow;
  }
});

/// Explicitly selected active unit (overrides the preferred default).
class ActiveUnitController extends Notifier<GovUnitAccess?> {
  @override
  GovUnitAccess? build() => null;
  void select(GovUnitAccess unit) => state = unit;
  void clear() => state = null;
}

final activeUnitProvider =
    NotifierProvider<ActiveUnitController, GovUnitAccess?>(
        ActiveUnitController.new);

/// The unit to operate on: explicit selection, else the preferred default.
final effectiveUnitProvider = Provider.autoDispose<GovUnitAccess?>((ref) {
  final override = ref.watch(activeUnitProvider);
  if (override != null) return override;
  return ref.watch(governanceAccessProvider).valueOrNull?.preferred;
});

final unitDetailProvider =
    FutureProvider.autoDispose.family<GovernanceUnitDetail, int>((ref, id) {
  return ref.watch(governanceRepositoryProvider).unitDetail(id);
});

final dashboardOverviewProvider = FutureProvider.autoDispose
    .family<GovernanceDashboardOverview, int>((ref, id) {
  return ref.watch(governanceRepositoryProvider).dashboard(id);
});

/// Colleges (departments) for the SG-creation college picker. Reuses the
/// school-IT repository — `GET /api/departments/` is governance-accessible.
final govDepartmentsProvider =
    FutureProvider.autoDispose<List<Department>>((ref) {
  return ref.watch(schoolItRepositoryProvider).departments();
});

/// Programs for the ORG-creation program picker (filtered client-side to the
/// parent SG's department via [Program.departmentIds]).
final govProgramsProvider = FutureProvider.autoDispose<List<Program>>((ref) {
  return ref.watch(schoolItRepositoryProvider).programs();
});

/// Create a child governance unit (SG under an SSG, or ORG under an SG), then
/// refresh the user's access and the parent's dashboard so the new child shows
/// up. Returns the created unit's detail. Backend validation errors surface as
/// [ApiException] to the caller.
Future<GovernanceUnitDetail> createGovernanceUnit(
  WidgetRef ref, {
  required String code,
  required String name,
  required String type,
  required int parentUnitId,
  String? description,
  int? departmentId,
  int? programId,
}) async {
  final detail = await ref.read(governanceRepositoryProvider).createUnit(
        code: code,
        name: name,
        type: type,
        description: description,
        parentUnitId: parentUnitId,
        departmentId: departmentId,
        programId: programId,
      );
  ref.invalidate(governanceAccessProvider);
  ref.invalidate(dashboardOverviewProvider(parentUnitId));
  return detail;
}

final announcementsProvider = FutureProvider.autoDispose
    .family<List<GovernanceAnnouncement>, int>((ref, id) {
  return ref.watch(governanceRepositoryProvider).announcements(id);
});

/// Events visible in a governance context (SSG | SG | ORG).
final governanceEventsProvider =
    FutureProvider.autoDispose.family<List<AppEvent>, String>((ref, context) {
  return ref
      .watch(eventsRepositoryProvider)
      .list(limit: 200, governanceContext: context);
});

final eventStatsProvider =
    FutureProvider.autoDispose.family<EventStats, int>((ref, eventId) {
  return ref.watch(governanceRepositoryProvider).eventStats(eventId);
});

/// Polls event stats every 15s — drives the live attendance bar for ongoing
/// events.
final eventLiveStatsProvider =
    StreamProvider.autoDispose.family<EventStats, int>((ref, eventId) async* {
  final repo = ref.watch(governanceRepositoryProvider);
  while (true) {
    yield await repo.eventStats(eventId);
    await Future<void>.delayed(const Duration(seconds: 15));
  }
});

final eventAttendeesProvider = FutureProvider.autoDispose
    .family<List<AttendanceRecord>, int>((ref, eventId) {
  ref.watch(livePollingTickerProvider(PollingPace.fast));
  return ref.watch(governanceRepositoryProvider).eventAttendees(eventId);
});

/// Roster of students the active officer can see. The attendees endpoint
/// only returns FK ints — this list provides the names/IDs we need to
/// label rows and to compute "absent" = roster MINUS attended.
final governanceStudentsProvider =
    FutureProvider.autoDispose<List<GovUserSummary>>((ref) async {
  final unit = ref.watch(effectiveUnitProvider);
  return ref
      .watch(governanceRepositoryProvider)
      .accessibleStudents(context: unit?.type);
});

/// Joined `EventAttendee` rows for the monitor screen: every roster student
/// gets a row, with their attendance record attached if one exists.
/// Sorted with present/late first (most recent time-in), then absent
/// (alphabetical by full name).
final eventAttendeesEnrichedProvider = FutureProvider.autoDispose
    .family<List<EventAttendee>, int>((ref, eventId) async {
  final attendees = await ref.watch(eventAttendeesProvider(eventId).future);
  final students = await ref.watch(governanceStudentsProvider.future);

  // Index attendance rows by student_profile.id (the FK on attendances).
  final byProfileId = <int, AttendanceRecord>{};
  for (final a in attendees) {
    final pid = a.studentId;
    if (pid != null) byProfileId[pid] = a;
  }

  final rows = <EventAttendee>[];
  final usedAttendanceIds = <int>{};

  for (final s in students) {
    final profileId = s.studentProfileId;
    if (profileId == null) continue; // not a student account
    final rec = byProfileId[profileId];
    if (rec != null) usedAttendanceIds.add(rec.id);
    rows.add(EventAttendee(
      record: rec,
      studentProfileId: profileId,
      studentNumber: s.studentNumber,
      fullName: s.displayName,
      email: s.email,
      programName: s.programName,
      yearLevel: s.yearLevel,
    ));
  }

  // Surface any attendance rows that don't map to a roster student
  // (e.g. visitor / cross-college guest) so they're not invisible.
  for (final a in attendees) {
    if (usedAttendanceIds.contains(a.id)) continue;
    final pid = a.studentId ?? 0;
    rows.add(EventAttendee(
      record: a,
      studentProfileId: pid,
      studentNumber: null,
      fullName: 'Student #$pid',
    ));
  }

  rows.sort((a, b) {
    // Order: present (signed in) > present (completed) > late > absent.
    int rank(EventAttendee e) {
      if (e.isAbsent) return 3;
      if (e.isLate) return 2;
      if (e.needsSignOut) return 0;
      return 1;
    }

    final ra = rank(a);
    final rb = rank(b);
    if (ra != rb) return ra.compareTo(rb);
    // Within attended rows, newest time-in first; within absent, A→Z by name.
    if (ra == 3) {
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    }
    final at = a.record?.timeIn;
    final bt = b.record?.timeIn;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return bt.compareTo(at);
  });

  return rows;
});

/// Convenience: the roster students who do NOT have an attendance row yet
/// — the candidate set for the "Add attendance" picker so officers don't
/// re-mark someone already checked in.
final eventAbsentStudentsProvider = FutureProvider.autoDispose
    .family<List<EventAttendee>, int>((ref, eventId) async {
  final rows = await ref.watch(eventAttendeesEnrichedProvider(eventId).future);
  return rows.where((e) => e.isAbsent).toList();
});

final sanctionsDashboardProvider =
    FutureProvider.autoDispose<SanctionsDashboard>((ref) async {
  try {
    return await ref.watch(sanctionsRepositoryProvider).dashboard();
  } on ApiException catch (e) {
    // 404 = no events / no dashboard data yet for this scope. Treat as
    // empty rather than an error wall. 403 is a real permission failure —
    // let it surface with a proper error so the user sees "you need
    // officer access" instead of a misleading empty state.
    if (e.isNotFound) return const SanctionsDashboard();
    rethrow;
  }
});

final sanctionEventStudentsProvider =
    FutureProvider.autoDispose.family<PaginatedSanctions, int>((ref, eventId) {
  return ref.watch(sanctionsRepositoryProvider).eventStudents(eventId);
});
