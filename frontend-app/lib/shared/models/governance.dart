import '../utils/json.dart';

List<String> _codes(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

/// A unit the user belongs to, from `/governance/access/me`.
class GovUnitAccess {
  const GovUnitAccess({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.permissionCodes = const [],
  });
  final int id;
  final String code;
  final String name;
  final String type; // SSG | SG | ORG
  final List<String> permissionCodes;

  bool can(String code) => permissionCodes.contains(code);

  factory GovUnitAccess.fromJson(Map<String, dynamic> j) => GovUnitAccess(
        id: asInt(j['governance_unit_id']) ?? 0,
        code: asStr(j['unit_code']) ?? '',
        name: asStr(j['unit_name']) ?? 'Unit',
        type: asStr(j['unit_type']) ?? 'ORG',
        permissionCodes: _codes(j['permission_codes']),
      );

  /// Build an access entry from a unit summary (e.g. a child unit surfaced on a
  /// parent's dashboard, for tap-to-switch). [permissionCodes] is the caller's
  /// *effective* permissions on the unit — direct membership codes plus any the
  /// backend propagates from a parent membership.
  factory GovUnitAccess.fromSummary(
    GovernanceUnitSummary s, {
    List<String> permissionCodes = const [],
  }) =>
      GovUnitAccess(
        id: s.id,
        code: s.code,
        name: s.name,
        type: s.type,
        permissionCodes: permissionCodes,
      );
}

class GovernanceAccess {
  const GovernanceAccess({
    this.userId,
    this.schoolId,
    this.permissionCodes = const [],
    this.units = const [],
  });
  final int? userId;
  final int? schoolId;
  final List<String> permissionCodes;
  final List<GovUnitAccess> units;

  bool get hasAccess => units.isNotEmpty;

  /// Preferred active unit: SSG > SG > ORG, else first.
  GovUnitAccess? get preferred {
    if (units.isEmpty) return null;
    for (final type in ['SSG', 'SG', 'ORG']) {
      for (final u in units) {
        if (u.type == type) return u;
      }
    }
    return units.first;
  }

  factory GovernanceAccess.fromJson(Map<String, dynamic> j) => GovernanceAccess(
        userId: asInt(j['user_id']),
        schoolId: asInt(j['school_id']),
        permissionCodes: _codes(j['permission_codes']),
        units: asMapList(j['units']).map(GovUnitAccess.fromJson).toList(),
      );
}

class GovernanceUnitSummary {
  const GovernanceUnitSummary({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.type,
    this.memberCount = 0,
    this.isActive = true,
    this.departmentId,
    this.programId,
  });
  final int id;
  final String code;
  final String name;
  final String? description;
  final String type;
  final int memberCount;
  final bool isActive;

  /// College scope (SG units, and inherited by their ORG children). Present on
  /// unit-detail payloads; absent on dashboard child summaries.
  final int? departmentId;

  /// Program scope (ORG units). Present on unit-detail payloads.
  final int? programId;

  factory GovernanceUnitSummary.fromJson(Map<String, dynamic> j) =>
      GovernanceUnitSummary(
        id: asInt(j['id']) ?? 0,
        code: asStr(j['unit_code']) ?? '',
        name: asStr(j['unit_name']) ?? 'Unit',
        description: asStr(j['description']),
        type: asStr(j['unit_type']) ?? 'ORG',
        memberCount: asInt(j['member_count']) ?? 0,
        isActive: j['is_active'] == null ? true : asBool(j['is_active']),
        departmentId: asInt(j['department_id']),
        programId: asInt(j['program_id']),
      );
}

class GovUserSummary {
  const GovUserSummary({
    required this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.studentNumber,
    this.studentProfileId,
    this.programName,
    this.departmentName,
    this.yearLevel,
  });
  final int id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? studentNumber;

  /// FK on `attendances.student_id` points at `student_profiles.id`, which
  /// is **not** `User.id`. Holding it here makes the client-side join with
  /// the event-attendees list a one-liner instead of a multi-hop lookup.
  final int? studentProfileId;

  final String? programName;
  final String? departmentName;
  final int? yearLevel;

  String get displayName {
    final n = [firstName, lastName]
        .where((e) => e != null && e.trim().isNotEmpty)
        .join(' ')
        .trim();
    return n.isNotEmpty ? n : (email ?? 'User');
  }

  String get initials {
    final a = (firstName ?? '').trim();
    final b = (lastName ?? '').trim();
    final x = a.isNotEmpty ? a[0] : (email ?? '?')[0];
    final y = b.isNotEmpty ? b[0] : '';
    return (x + y).toUpperCase();
  }

  factory GovUserSummary.fromJson(Map<String, dynamic> j) {
    final sp = j['student_profile'];
    final p = sp is Map ? sp.cast<String, dynamic>() : const <String, dynamic>{};
    return GovUserSummary(
      id: asInt(j['id']) ?? 0,
      email: asStr(j['email']),
      firstName: asStr(j['first_name']),
      lastName: asStr(j['last_name']),
      studentNumber: asStr(p['student_id']),
      studentProfileId: asInt(p['id']),
      programName: asStr(p['program_name']),
      departmentName: asStr(p['department_name']),
      yearLevel: asInt(p['year_level']),
    );
  }
}

List<String> _permCodes(dynamic list) {
  final out = <String>[];
  if (list is List) {
    for (final p in list) {
      if (p is Map) {
        final perm = p['permission'];
        if (perm is Map && perm['permission_code'] != null) {
          out.add(perm['permission_code'].toString());
        }
      }
    }
  }
  return out;
}

class GovernanceMember {
  const GovernanceMember({
    required this.id,
    required this.userId,
    this.positionTitle,
    this.isActive = true,
    this.user,
    this.permissionCodes = const [],
  });
  final int id;
  final int userId;
  final String? positionTitle;
  final bool isActive;
  final GovUserSummary? user;
  final List<String> permissionCodes;

  factory GovernanceMember.fromJson(Map<String, dynamic> j) {
    final u = j['user'];
    return GovernanceMember(
      id: asInt(j['id']) ?? 0,
      userId: asInt(j['user_id']) ?? 0,
      positionTitle: asStr(j['position_title']),
      isActive: j['is_active'] == null ? true : asBool(j['is_active']),
      user: u is Map ? GovUserSummary.fromJson(u.cast<String, dynamic>()) : null,
      permissionCodes: _permCodes(j['member_permissions']),
    );
  }
}

class GovernanceUnitDetail {
  const GovernanceUnitDetail({
    required this.summary,
    this.members = const [],
    this.unitPermissionCodes = const [],
  });
  final GovernanceUnitSummary summary;
  final List<GovernanceMember> members;
  final List<String> unitPermissionCodes;

  factory GovernanceUnitDetail.fromJson(Map<String, dynamic> j) =>
      GovernanceUnitDetail(
        summary: GovernanceUnitSummary.fromJson(j),
        members: asMapList(j['members']).map(GovernanceMember.fromJson).toList(),
        unitPermissionCodes: _permCodes(j['unit_permissions']),
      );
}

class GovernanceAnnouncement {
  const GovernanceAnnouncement({
    required this.id,
    this.title = '',
    this.body = '',
    this.status = 'draft',
    this.authorName,
    this.updatedAt,
    this.createdAt,
  });
  final int id;
  final String title;
  final String body;
  final String status; // draft | published | archived
  final String? authorName;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  factory GovernanceAnnouncement.fromJson(Map<String, dynamic> j) =>
      GovernanceAnnouncement(
        id: asInt(j['id']) ?? 0,
        title: asStr(j['title']) ?? '',
        body: asStr(j['body']) ?? '',
        status: asStr(j['status']) ?? 'draft',
        authorName: asStr(j['author_name']),
        updatedAt: asDate(j['updated_at']),
        createdAt: asDate(j['created_at']),
      );
}

class GovernanceDashboardOverview {
  const GovernanceDashboardOverview({
    this.unitType,
    this.publishedAnnouncementCount = 0,
    this.totalStudents = 0,
    this.recentAnnouncements = const [],
    this.childUnits = const [],
  });
  final String? unitType;
  final int publishedAnnouncementCount;
  final int totalStudents;
  final List<GovernanceAnnouncement> recentAnnouncements;
  final List<GovernanceUnitSummary> childUnits;

  factory GovernanceDashboardOverview.fromJson(Map<String, dynamic> j) =>
      GovernanceDashboardOverview(
        unitType: asStr(j['unit_type']),
        publishedAnnouncementCount:
            asInt(j['published_announcement_count']) ?? 0,
        totalStudents: asInt(j['total_students']) ?? 0,
        recentAnnouncements: asMapList(j['recent_announcements'])
            .map(GovernanceAnnouncement.fromJson)
            .toList(),
        childUnits: asMapList(j['child_units'])
            .map(GovernanceUnitSummary.fromJson)
            .toList(),
      );
}

class StatusCount {
  const StatusCount(this.count, this.percentage);
  final int count;
  final double percentage;
}

class EventStats {
  const EventStats({this.total = 0, this.statuses = const {}});
  final int total;
  final Map<String, StatusCount> statuses;

  int countOf(String s) => statuses[s]?.count ?? 0;

  factory EventStats.fromJson(Map<String, dynamic> j) {
    final map = <String, StatusCount>{};
    final st = j['statuses'];
    if (st is Map) {
      st.forEach((k, v) {
        if (v is Map) {
          map[k.toString()] =
              StatusCount(asInt(v['count']) ?? 0, asDouble(v['percentage']) ?? 0);
        }
      });
    }
    return EventStats(total: asInt(j['total']) ?? 0, statuses: map);
  }
}
