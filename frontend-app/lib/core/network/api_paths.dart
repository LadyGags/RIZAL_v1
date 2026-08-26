/// Backend API paths.
///
/// This deployment mounts routes under `/api` (verified against the staging
/// server: `/api/events/` → 401, `/api/v1/events/` → 404). The prefix is
/// overridable per deployment via `--dart-define=AURA_API_PREFIX=/api/v1`.
/// Public kiosk routes are mounted at the root (no prefix).
class Api {
  Api._();
  static const String prefix =
      String.fromEnvironment('AURA_API_PREFIX', defaultValue: '/api');

  // Events
  static const String events = '$prefix/events/';
  static const String eventsOngoing = '$prefix/events/ongoing';
  static String event(int id) => '$prefix/events/$id';
  static String eventTimeStatus(int id) => '$prefix/events/$id/time-status';

  // Face / attendance
  static const String faceScan = '$prefix/face/face-scan-with-recognition';
  static const String faceRegister = '$prefix/face/register';
  static const String faceVerify = '$prefix/face/verify';
  static const String myAttendance = '$prefix/attendance/students/me';
  static String studentReport(int profileId) =>
      '$prefix/attendance/students/$profileId/report';

  /// Operator-driven manual sign-in / sign-out (campus admin or governance
  /// member with `manage_attendance`). Body: `{event_id, student_id |
  /// student_profile_id, notes?}`. Same endpoint handles both directions:
  /// if the student is already checked in, it records the sign-out.
  static const String attendanceManual = '$prefix/attendance/manual';

  /// Record sign-out for an existing attendance row by id. Used by the
  /// inline "Sign out" action in the event monitor.
  static String attendanceTimeOut(int attendanceId) =>
      '$prefix/attendance/$attendanceId/time-out';

  // Profile
  static const String me = '$prefix/users/me/';
  static String studentProfile(int id) => '$prefix/users/student-profiles/$id';

  // School IT — users, departments, programs, school, bulk import
  static const String users = '$prefix/users/';
  static String user(int id) => '$prefix/users/$id';
  static const String departments = '$prefix/departments/';
  static const String programs = '$prefix/programs/';
  static const String schoolMe = '$prefix/school/me';
  static const String schoolUpdate = '$prefix/school/update';
  static const String importPreview = '$prefix/admin/import-students/preview';
  static const String importCommit = '$prefix/admin/import-students';
  static String importStatus(String jobId) =>
      '$prefix/admin/import-status/$jobId';

  /// Strip every invalid row from a previewed manifest and flip
  /// `can_commit` to true so the remaining valid rows can be imported.
  /// Used by the "Skip invalid rows" action on the bulk-import screen.
  static String importRemoveInvalid(String previewToken) =>
      '$prefix/admin/import-preview-errors/$previewToken/remove-invalid';

  // Notifications
  static const String notificationsInbox = '$prefix/notifications/inbox/me';
  static const String notificationPrefs = '$prefix/notifications/preferences/me';

  // Events — governance monitor
  static String eventAttendees(int id) => '$prefix/events/$id/attendees';
  static String eventStats(int id) => '$prefix/events/$id/stats';

  // Governance
  static const String govAccessMe = '$prefix/governance/access/me';
  static const String govUnits = '$prefix/governance/units';
  static String govUnit(int id) => '$prefix/governance/units/$id';
  static String govUnitDashboard(int id) =>
      '$prefix/governance/units/$id/dashboard-overview';
  static String govUnitMembers(int id) => '$prefix/governance/units/$id/members';
  static String govMember(int id) => '$prefix/governance/members/$id';
  static const String govStudents = '$prefix/governance/students';
  static const String govStudentSearch = '$prefix/governance/students/search';
  static String govUnitAnnouncements(int id) =>
      '$prefix/governance/units/$id/announcements';
  static String govAnnouncement(int id) =>
      '$prefix/governance/announcements/$id';

  // Sanctions (verified under /api)
  static const String sanctionsDashboard = '$prefix/sanctions/dashboard';
  // Student self-view: the signed-in student's own sanction records.
  static const String sanctionsMine = '$prefix/sanctions/students/me';
  // Active school-wide clearance deadline (null when none is set).
  static const String sanctionsClearanceDeadline =
      '$prefix/sanctions/clearance-deadline';
  static String sanctionEventStudents(int eventId) =>
      '$prefix/sanctions/events/$eventId/students';
  static String sanctionApprove(int eventId, int userId) =>
      '$prefix/sanctions/events/$eventId/students/$userId/approve';

  // Platform Admin
  static const String adminSchools = '$prefix/school/admin/list';
  static String school(int id) => '$prefix/school/$id';
  static const String adminCreateSchoolIt =
      '$prefix/school/admin/create-school-it';
  static String adminSchoolStatus(int id) => '$prefix/school/admin/$id/status';
  static const String adminSchoolItAccounts =
      '$prefix/school/admin/school-it-accounts';
  static String adminAccountStatus(int userId) =>
      '$prefix/school/admin/school-it-accounts/$userId/status';
  static String adminAccountResetPassword(int userId) =>
      '$prefix/school/admin/school-it-accounts/$userId/reset-password';
  static const String subscriptionMe = '$prefix/subscription/me';
  static const String auditLogs = '$prefix/audit-logs';
  static const String notificationLogs = '$prefix/notifications/logs';

  // Public attendance (kiosk) — mounted at root, no prefix.
  static const String publicNearby = '/public-attendance/events/nearby';
  static String publicMultiScan(int eventId) =>
      '/public-attendance/events/$eventId/multi-face-scan';
}
