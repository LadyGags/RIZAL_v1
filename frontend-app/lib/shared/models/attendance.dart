import '../utils/json.dart';

class Liveness {
  const Liveness({this.label, this.score, this.reason});
  final String? label;
  final double? score;
  final String? reason;

  bool get isLive {
    final l = (label ?? '').toLowerCase();
    return l == 'live' || l == 'bypassed';
  }

  factory Liveness.fromJson(Map<String, dynamic> j) => Liveness(
        label: asStr(j['label']),
        score: asDouble(j['score']),
        reason: asStr(j['reason']),
      );
}

class GeoVerification {
  const GeoVerification({
    this.ok = false,
    this.reason,
    this.distanceM,
    this.effectiveDistanceM,
    this.radiusM,
    this.accuracyM,
  });
  final bool ok;
  final String? reason;
  final double? distanceM;
  final double? effectiveDistanceM;
  final double? radiusM;
  final double? accuracyM;

  factory GeoVerification.fromJson(Map<String, dynamic> j) => GeoVerification(
        ok: asBool(j['ok']),
        reason: asStr(j['reason']),
        distanceM: asDouble(j['distance_m']),
        effectiveDistanceM: asDouble(j['effective_distance_m']),
        radiusM: asDouble(j['radius_m']),
        accuracyM: asDouble(j['accuracy_m']),
      );
}

/// Result of a self-scan check-in/out (`/face/face-scan-with-recognition`).
class FaceScanResult {
  const FaceScanResult({
    required this.action,
    this.studentId,
    this.studentName,
    this.attendanceId,
    this.distance,
    this.confidence,
    this.threshold,
    this.liveness,
    this.geo,
    this.timeIn,
    this.timeOut,
    this.durationMinutes,
    this.message,
  });

  final String action; // time_in | timeout
  final String? studentId;
  final String? studentName;
  final int? attendanceId;
  final double? distance;
  final double? confidence;
  final double? threshold;
  final Liveness? liveness;
  final GeoVerification? geo;
  final DateTime? timeIn;
  final DateTime? timeOut;
  final int? durationMinutes;
  final String? message;

  bool get isTimeIn => action == 'time_in';
  bool get isTimeOut => action == 'timeout' || action == 'time_out';

  factory FaceScanResult.fromJson(Map<String, dynamic> j) {
    final liv = j['liveness'];
    final geo = j['geo'];
    return FaceScanResult(
      action: asStr(j['action']) ?? '',
      studentId: asStr(j['student_id']),
      studentName: asStr(j['student_name']),
      attendanceId: asInt(j['attendance_id']),
      distance: asDouble(j['distance']),
      confidence: asDouble(j['confidence']),
      threshold: asDouble(j['threshold']),
      liveness: liv is Map ? Liveness.fromJson(liv.cast<String, dynamic>()) : null,
      geo: geo is Map ? GeoVerification.fromJson(geo.cast<String, dynamic>()) : null,
      timeIn: asDate(j['time_in']),
      timeOut: asDate(j['time_out']),
      durationMinutes: asInt(j['duration_minutes']),
      message: asStr(j['message']),
    );
  }
}

/// An attendance record. Report records carry extra event fields, all optional.
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    this.studentId,
    this.eventId,
    this.eventName,
    this.eventLocation,
    this.eventDate,
    this.timeIn,
    this.timeOut,
    this.method,
    this.status = '',
    this.displayStatus,
    this.checkInStatus,
    this.checkOutStatus,
    this.completionState,
    this.isValidAttendance = false,
    this.durationMinutes,
    this.notes,
  });

  final int id;
  final int? studentId;
  final int? eventId;
  final String? eventName;
  final String? eventLocation;
  final DateTime? eventDate;
  final DateTime? timeIn;
  final DateTime? timeOut;
  final String? method;
  final String status;
  final String? displayStatus;
  final String? checkInStatus;
  final String? checkOutStatus;
  final String? completionState;
  final bool isValidAttendance;
  final int? durationMinutes;
  final String? notes;

  String get effectiveStatus => displayStatus ?? status;
  bool get isComplete => completionState == 'completed';

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id: asInt(j['id']) ?? 0,
        studentId: asInt(j['student_id']),
        eventId: asInt(j['event_id']),
        eventName: asStr(j['event_name']),
        eventLocation: asStr(j['event_location']),
        eventDate: asDate(j['event_date']),
        timeIn: asDate(j['time_in']),
        timeOut: asDate(j['time_out']),
        method: asStr(j['method']),
        status: asStr(j['status']) ?? '',
        displayStatus: asStr(j['display_status']),
        checkInStatus: asStr(j['check_in_status']),
        checkOutStatus: asStr(j['check_out_status']),
        completionState: asStr(j['completion_state']),
        isValidAttendance: asBool(j['is_valid_attendance']),
        durationMinutes: asInt(j['duration_minutes']),
        notes: asStr(j['notes']),
      );
}

/// Per-event roster row: combines an `AttendanceRecord` (or "no record")
/// with the matched student's display info. Built by joining
/// `/api/events/{id}/attendees` with `/api/governance/students`
/// client-side, since the attendees endpoint only returns FKs.
///
/// `record == null` means the student is in the event scope but hasn't
/// scanned (or been marked) yet — i.e., currently absent.
class EventAttendee {
  const EventAttendee({
    this.record,
    required this.studentProfileId,
    this.studentNumber,
    this.fullName = '',
    this.email,
    this.programName,
    this.yearLevel,
  });

  final AttendanceRecord? record;
  final int studentProfileId;
  final String? studentNumber;
  final String fullName;
  final String? email;
  final String? programName;
  final int? yearLevel;

  /// `displayStatus` from the record, OR `'absent'` when there's no row at
  /// all — gives the screen ONE field to filter on regardless of whether
  /// the absence is recorded or implicit.
  ///
  /// Defensive rule: if there's an attendance row with a `timeIn`, the
  /// student is **never** absent — even when the backend hasn't finalized
  /// `displayStatus` (e.g. they checked in, the event is still running,
  /// and sign-out hasn't happened yet). In that case we fall back to
  /// `'incomplete'` (sign-out missing) or `'present'` (both windows
  /// recorded), so an in-progress check-in is never painted red.
  String get effectiveStatus {
    final r = record;
    if (r == null) return 'absent';
    final raw = (r.displayStatus ?? r.status).trim().toLowerCase();
    if (raw.isNotEmpty && raw != 'absent') return raw;
    if (r.timeIn != null) {
      return r.timeOut == null ? 'incomplete' : 'present';
    }
    return 'absent';
  }

  bool get isPresent => effectiveStatus == 'present';
  bool get isLate => effectiveStatus == 'late';
  bool get isAbsent => effectiveStatus == 'absent';
  bool get isExcused => effectiveStatus == 'excused';
  bool get isIncomplete => effectiveStatus == 'incomplete';

  /// Phase-aware status for the monitor list.
  ///
  /// The backend only creates the "absent" attendance row AFTER an event
  /// is finalized (past the sign-out close window). While the event is
  /// **still ongoing**, a student with no record at all hasn't necessarily
  /// missed it — they may still arrive. Painting them red as "Absent"
  /// during that window is misleading.
  ///
  /// Returns one of:
  ///   * `'pending'`   — event is ongoing, no record yet (could still arrive)
  ///   * `'incomplete'` — checked in, hasn't signed out yet
  ///   * `'present' | 'late' | 'absent' | 'excused'` — from the row
  ///
  /// [eventStatus] is the AppEvent.status string (`ongoing` / `completed`
  /// / `upcoming` / `cancelled`); pass it through `.toLowerCase().trim()`
  /// before calling — or just pass `AppEvent.status` directly.
  String labelFor(String eventStatus) {
    final phase = eventStatus.trim().toLowerCase();
    final eventLive = phase == 'ongoing' || phase == 'upcoming';
    if (record == null && eventLive) return 'pending';
    return effectiveStatus;
  }

  /// True while the event is still running and this student hasn't
  /// recorded a sign-in yet. Drives the "Not yet" / neutral chip.
  bool isPendingFor(String eventStatus) =>
      labelFor(eventStatus) == 'pending';

  /// True when the row exists but no sign-out has been recorded yet —
  /// the inline action becomes "Sign out".
  bool get needsSignOut =>
      record != null && record!.timeIn != null && record!.timeOut == null;

  /// True when there's no row at all — the inline action becomes
  /// "Mark present".
  bool get canMarkPresent => record == null;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      final s = (studentNumber ?? '?').trim();
      return s.isEmpty ? '?' : s[0].toUpperCase();
    }
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    final result = (first + last).toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  /// Case-insensitive substring match across name + student number + email.
  /// Drives the search field on the monitor screen.
  bool matchesQuery(String q) {
    final needle = q.trim().toLowerCase();
    if (needle.isEmpty) return true;
    if (fullName.toLowerCase().contains(needle)) return true;
    if ((studentNumber ?? '').toLowerCase().contains(needle)) return true;
    if ((email ?? '').toLowerCase().contains(needle)) return true;
    return false;
  }
}

/// Result of a manual sign-in / sign-out API call (`POST /attendance/manual`
/// or `/attendance/{id}/time-out`). Both endpoints return the same shape.
class AttendanceActionResult {
  const AttendanceActionResult({
    this.attendanceId,
    this.studentId,
    this.action,
    this.timeIn,
    this.timeOut,
    this.durationMinutes,
    this.message,
  });

  final int? attendanceId;
  final String? studentId;
  final String? action; // 'time_in' | 'time_out' | null
  final DateTime? timeIn;
  final DateTime? timeOut;
  final int? durationMinutes;
  final String? message;

  bool get isTimeIn => action == 'time_in' || (timeIn != null && timeOut == null);
  bool get isTimeOut => action == 'time_out' || timeOut != null;

  factory AttendanceActionResult.fromJson(Map<String, dynamic> j) =>
      AttendanceActionResult(
        attendanceId: asInt(j['attendance_id']),
        studentId: asStr(j['student_id']),
        action: asStr(j['action']),
        timeIn: asDate(j['time_in']),
        timeOut: asDate(j['time_out']),
        durationMinutes: asInt(j['duration_minutes']),
        message: asStr(j['message']),
      );
}
