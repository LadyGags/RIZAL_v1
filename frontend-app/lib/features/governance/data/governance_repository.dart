import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated.dart';
import '../../../shared/models/attendance.dart';
import '../../../shared/models/governance.dart';
import '../../../shared/utils/json.dart';

class GovernanceRepository {
  GovernanceRepository(this._client);
  final DioClient _client;

  Future<GovernanceAccess> accessMe() async {
    final r = await _client.get(Api.govAccessMe);
    return GovernanceAccess.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<List<GovernanceUnitSummary>> units({String? type}) async {
    final r = await _client.get(Api.govUnits, query: {'unit_type': type});
    return Paginated.from(
      r.data,
      (e) => GovernanceUnitSummary.fromJson((e as Map).cast<String, dynamic>()),
    ).data;
  }

  Future<GovernanceUnitDetail> unitDetail(int id) async {
    final r = await _client.get(Api.govUnit(id));
    return GovernanceUnitDetail.fromJson(
        (r.data as Map).cast<String, dynamic>());
  }

  Future<GovernanceUnitDetail> createUnit({
    required String code,
    required String name,
    required String type,
    String? description,
    int? parentUnitId,
    int? departmentId,
    int? programId,
  }) async {
    // SG requires department_id (college scope); ORG requires program_id (the
    // department is inherited from the parent SG by the backend).
    final r = await _client.post(Api.govUnits, data: {
      'unit_code': code,
      'unit_name': name,
      'unit_type': type,
      'description': description,
      'parent_unit_id': parentUnitId,
      if (departmentId != null) 'department_id': departmentId,
      if (programId != null) 'program_id': programId,
    });
    return GovernanceUnitDetail.fromJson(
        (r.data as Map).cast<String, dynamic>());
  }

  Future<GovernanceDashboardOverview> dashboard(int unitId) async {
    final r = await _client.get(Api.govUnitDashboard(unitId));
    return GovernanceDashboardOverview.fromJson(
        (r.data as Map).cast<String, dynamic>());
  }

  Future<List<GovernanceAnnouncement>> announcements(int unitId) async {
    final r = await _client.get(Api.govUnitAnnouncements(unitId));
    return asMapList(r.data).map(GovernanceAnnouncement.fromJson).toList();
  }

  Future<GovernanceAnnouncement> createAnnouncement(
    int unitId, {
    required String title,
    required String body,
    String status = 'published',
  }) async {
    final r = await _client.post(Api.govUnitAnnouncements(unitId),
        data: {'title': title, 'body': body, 'status': status});
    return GovernanceAnnouncement.fromJson(
        (r.data as Map).cast<String, dynamic>());
  }

  Future<GovernanceMember> assignMember(
    int unitId, {
    required int userId,
    String? positionTitle,
    List<String> permissionCodes = const [],
  }) async {
    final r = await _client.post(Api.govUnitMembers(unitId), data: {
      'user_id': userId,
      'position_title': positionTitle,
      'permission_codes': permissionCodes,
    });
    return GovernanceMember.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<void> removeMember(int memberId) =>
      _client.delete(Api.govMember(memberId));

  Future<GovernanceMember> updateMember(int memberId,
      {String? positionTitle, List<String> permissionCodes = const []}) async {
    final r = await _client.patch(Api.govMember(memberId), data: {
      if (positionTitle != null) 'position_title': positionTitle,
      'permission_codes': permissionCodes,
    });
    return GovernanceMember.fromJson((r.data as Map).cast<String, dynamic>());
  }

  /// Fetch (auto-creating if missing) the school's SSG with its members.
  /// Campus-admin only.
  Future<GovernanceUnitDetail> ssgSetup() async {
    final r = await _client.get('/api/governance/ssg/setup');
    final m = (r.data as Map).cast<String, dynamic>();
    final unit = m['unit'];
    return GovernanceUnitDetail.fromJson(
        (unit is Map ? unit : m).cast<String, dynamic>());
  }

  /// Students the officer can view (`id` = user id, with display name + student
  /// number). Used to label event attendees by name in reports.
  Future<List<GovUserSummary>> accessibleStudents({String? context}) async {
    final r = await _client.get('/api/governance/students',
        query: {'governance_context': context, 'limit': 250});
    return asMapList(r.data).map((m) {
      final user = (m['user'] is Map)
          ? (m['user'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final sp = m['student_profile'];
      if (sp is Map && user['student_profile'] == null) {
        user['student_profile'] = sp;
      }
      return GovUserSummary.fromJson(user);
    }).toList();
  }

  Future<List<GovUserSummary>> searchStudents(String q, {int? unitId}) async {
    final r = await _client.get(Api.govStudentSearch,
        query: {'q': q, 'governance_unit_id': unitId, 'limit': 25});
    return asMapList(r.data).map((m) {
      final user = (m['user'] is Map)
          ? (m['user'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      if (m['student_profile'] is Map && user['student_profile'] == null) {
        user['student_profile'] = m['student_profile'];
      }
      return GovUserSummary.fromJson(user);
    }).toList();
  }

  Future<EventStats> eventStats(int eventId, {String? governanceContext}) async {
    final r = await _client.get(Api.eventStats(eventId),
        query: {'governance_context': governanceContext});
    return EventStats.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<List<AttendanceRecord>> eventAttendees(int eventId,
      {String? status, String? governanceContext}) async {
    final r = await _client.get(Api.eventAttendees(eventId), query: {
      'status': status,
      'governance_context': governanceContext,
      'limit': 250,
    });
    return Paginated.from(
      r.data,
      (e) => AttendanceRecord.fromJson((e as Map).cast<String, dynamic>()),
    ).data;
  }

  /// Record a manual sign-in for a student at an event. Backend rules:
  /// admin / campus_admin / governance member with `manage_attendance`.
  /// If the student is already checked in, the same endpoint records
  /// the sign-out instead — caller doesn't need to switch endpoints.
  Future<AttendanceActionResult> markStudentPresent({
    required int eventId,
    required String studentNumber,
    String? notes,
    String? governanceContext,
  }) async {
    final r = await _client.post(
      Api.attendanceManual,
      query: {'governance_context': governanceContext},
      data: {
        'event_id': eventId,
        'student_id': studentNumber,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return AttendanceActionResult.fromJson(
        (r.data as Map).cast<String, dynamic>());
  }

  /// Record a sign-out for an existing attendance row.
  Future<AttendanceActionResult> markStudentSignedOut(
    int attendanceId, {
    String? governanceContext,
  }) async {
    final r = await _client.post(
      Api.attendanceTimeOut(attendanceId),
      query: {'governance_context': governanceContext},
    );
    return AttendanceActionResult.fromJson(
        (r.data as Map).cast<String, dynamic>());
  }
}

final governanceRepositoryProvider = Provider<GovernanceRepository>(
  (ref) => GovernanceRepository(ref.watch(dioClientProvider)),
);
