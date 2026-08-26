# Changelog

All notable changes to the Aura (RIZAL) Flutter app are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this
project adheres to [Semantic Versioning](https://semver.org/). Pre-1.0 while
building toward full four-workspace parity: **each phase bumps the minor**, bug
fixes bump the patch, and **1.0.0** lands when all four workspaces ship.
`pubspec.yaml` `version:` tracks the latest entry as `<semver>+<build>`.

## [Unreleased]

## [1.36.3] - 2026-05-29

### Highlights — Phase-aware attendee list + tap-to-view-details

- **"Not yet" replaces "Absent" while events are running.** The backend
  only stamps a `status='absent'` row AFTER finalization (when the
  sign-out window closes). Before that, students with no record might
  still arrive. The monitor now reflects backend reality:
  - Ongoing / upcoming + no record → neutral **"Not yet"** chip with
    hourglass icon (was incorrectly red "Absent").
  - Completed + no record → **"Absent"** in red (backend auto-creates
    these rows lazily on the next read of `/attendees` or `/stats` —
    see `services/event_attendance_service.py:90`).
  - Checked in but not signed out → **"Incomplete"** chip
    (orange), regardless of phase.
  - The filter pill labelled "Absent" renames to **"Pending"** while
    the event is ongoing, and its accent tint flips from red to
    neutral so the pill stops shouting at officers during a live
    event. Count of pending/absent reflects whichever the phase calls
    for.
- **Tap-to-view-details.** Tapping any row opens
  `AttendeeDetailSheet` — a `DraggableScrollableSheet` with:
  - Large gradient avatar tinted to the phase-aware status, full
    name, mono student ID, and a phase pill.
  - Meta card (program, year level, email).
  - Attendance card with big mono `CHECK-IN` / `SIGN-OUT` rows,
    computed duration, recording method ("Face scan" / "Marked by
    officer" / "Auto-finalized"), and notes (so the backend's
    `"Auto-marked absent - no sign-in recorded."` shows up
    verbatim).
  - Officer action footer (Mark present / Sign out) when permitted
    and applicable — same handlers as the inline row buttons, so
    in-flight state stays owned by the monitor.
  - All read-only: no extra backend calls; uses already-loaded
    `EventAttendee` + `AttendanceRecord` data.
- **Chevron + selection haptic** on each row so tap-ability is
  obvious.
- New model APIs: `EventAttendee.labelFor(eventStatus)`,
  `EventAttendee.isPendingFor(eventStatus)`.

## [1.36.2] - 2026-05-28

### Polish pass

- **Typography fixed across the new monitor surface.** Replaced
  `theme.textTheme.titleMedium` (which doesn't exist in `AppTypography`
  → fell back to Roboto and looked thin) with explicit Manrope styles
  via a new `AppTypography.ui()` helper that drives the variable-font
  weight axis the same way `mono()` and the global `textTheme` do.
  Avatar initials, filter labels, row names, FAB and action buttons
  now all render in proper Manrope weights.
- **Sliding filter indicator.** The All · Present · Late · Absent
  segmented control now slides a single `AnimatedPositioned` pill
  between cells (260 ms, custom ease-out) and tints the active label
  + count badge with the status colour (green / orange / red /
  ink). Replaces the per-cell background swap that fought the eye.
- **Real motion on rows + buttons.** First-mount fade + 6%-lift on
  each attendee row (40 ms stagger, capped at 8 cells); 0.985 press
  scale on the whole row, on the FAB, and on inline action buttons;
  `HapticFeedback.selectionClick` on tap. All paths respect
  `MediaQuery.disableAnimations`.
- **Search field with focus halo.** Border + fill swap to surface +
  accent on focus, with a soft accent shadow underneath; icon tints
  accent on focus.
- **Absent never lies.** `EventAttendee.effectiveStatus` now returns
  `'incomplete'` (or `'present'` when both windows are recorded)
  whenever there's a `timeIn` — a student who has checked in but
  not yet signed out is never painted as **Absent**, regardless of
  what the backend's `display_status` happens to say while the event
  is still running.

### Highlights — Manual attendance + searchable roster

- **Mark students present without face scan.** The governance event
  monitor (`GovernanceEventMonitorScreen`) gains an "Add attendance"
  floating action and per-row "Mark present" / "Sign out" buttons —
  gated on the officer's `manage_attendance` permission. Calls
  `POST /api/attendance/manual` (which auto-detects sign-in vs sign-out)
  and `POST /api/attendance/{id}/time-out`, both with the unit-typed
  `governance_context` query. Mid-impact haptic confirms each action;
  the stats card, attendee list, and absent-roster all refetch
  automatically. Backend already supported this; the Flutter UI didn't
  expose it.
- **Searchable, named attendee list.** Replaces the old
  "Student #142" plain rows with a roster joined client-side from
  `/api/events/{id}/attendees` × `/api/governance/students`. Each row
  shows initials avatar (status-tinted: green / orange / red /
  neutral), full name, mono student-ID, time-in + time-out pills,
  status chip. Above the list: segmented filter pills **All ·
  Present · Late · Absent** with mono count badges, plus a search
  field matching name, student ID, or email (case-insensitive). The
  empty-state copy adapts to the active filter ("Everyone is
  accounted for" when Absent is empty).
- **Smart-poll for the monitor.** `eventAttendeesProvider` now
  subscribes to `livePollingTickerProvider(PollingPace.fast)` so the
  list reflects new check-ins without a manual pull-to-refresh.
- **New models / providers.** `EventAttendee` joins
  `AttendanceRecord` + roster info with `effectiveStatus` /
  `needsSignOut` / `canMarkPresent` / `matchesQuery`.
  `AttendanceActionResult` decodes both manual-attendance endpoints.
  `GovUserSummary` parses `studentProfileId` so the FK on
  `attendances.student_id` (= `student_profiles.id`, **not**
  `User.id`) resolves cleanly. New providers:
  `governanceStudentsProvider`, `eventAttendeesEnrichedProvider(id)`,
  `eventAbsentStudentsProvider(id)`.

## [1.36.1] - 2026-05-28

### Highlights (what changed since v1.36.0+80)

- **Alarm-style event notifications.** Reminders now ring on the alarm
  volume stream and bypass silent / Do Not Disturb (where the user has
  granted that channel privilege). Channel bumped to `event_window_v2`
  with `Importance.max`, `audioAttributesUsage: AudioAttributesUsage.alarm`,
  category `AndroidNotificationCategory.alarm`. iOS interruption level
  raised to `timeSensitive` so it bypasses Focus modes. iOS permission
  request added to `initNotifications`. Old `event_window` channel is
  deleted on first launch after this update so the user doesn't see two
  channels in Android settings.
- **Scan UI no longer ambiguous.** A big colour-coded banner sits above
  the capture button telling the student EXACTLY what this scan will
  do: **CHECK IN** (green), **SIGN OUT** (purple, with "You checked in
  at HH:MM"), or a muted variant explaining why no scan is possible
  ("Already checked in at 09:14 · Sign-out opens 15:00",
  "Attendance complete (09:14 → 16:32)", "Closed · Check-in opens
  at HH:MM"). Capture button is disabled with a lock icon when scan
  isn't valid — no more accidental duplicate check-ins. Camera oval
  ring tints muted when scan is unavailable.
- **Result sheet labels every time.** After-scan bottom sheet now
  shows `CHECK-IN TIME` and `CHECK-OUT TIME` rows in JetBrainsMono with
  explicit labels (instead of one unlabeled timestamp). After a fresh
  check-in, a "SIGN-OUT OPENS" hint shows the upcoming window. After a
  sign-out, a "Total time: 6h 18m" pill appears. Large colour-coded
  action title — "Checked in" / "Signed out" / "Already recorded" —
  instead of the old ambiguous "Recorded". Staggered RiseIn entrance,
  TweenAnimationBuilder settle on the action icon (scale 0.92 → 1.0,
  never `scale(0)`; reduced-motion honoured).
- **Real-time data without manual refresh.** Six high-value providers
  auto-refetch on a lifecycle-aware timer while the screen is
  foregrounded: `myProfileProvider`, `notificationsProvider`,
  `ongoingEventsProvider`, `scheduleEventsProvider` (medium 30s cadence),
  `studentsProvider`, `mySanctionsProvider` (slow 60s cadence). All
  polling stops when the app is backgrounded (zero battery / network
  drain); every live provider refetches **immediately** on resume.
  Silent-fail on transient errors so a brief offline hiccup doesn't
  splash error banners across every screen.
- **Schoolit users — search + filter chips.** Top-level Users tab gains
  a search field; typing cross-fades the colleges grid to a flat student
  result list. College detail keeps its search and gains a filter bar:
  Program / Year / Status / Face enrolled chips. All filters compose
  with AND. Pure-Dart `StudentFilter` (14 unit tests).
- **Login redesign.** Centered brand hero in a soft accent halo, "or"
  divider between Sign in and Google, inline Forgot link next to the
  password label, condensed 2-item footer, full staggered entrance.
  No longer crowded.
- **Build unblocker.** Release APK build is back to green —
  `integration_test` removed from `dev_dependencies` to stop it from
  leaking into the release `GeneratedPluginRegistrant.java` (it was
  causing `package dev.flutter.plugins.integration_test does not
  exist` at compile time). `flutter test` (unit + widget) is
  unaffected.
- **Per-ABI APK splits.** Release APK is now built with
  `--split-per-abi` so each variant is ~38–45 MB instead of one
  ~105 MB fat APK that bundled all three architectures. Ship just
  `app-arm64-v8a-release.apk` to ~95% of phones.

### Added
- **Event window reminders (v1.36.0).** Notifies the user when an event's
  check-in or sign-out window opens, aligned to the backend's
  `check_in_opens_at` / `sign_out_opens_at` thresholds (Asia/Manila).
  Up to five scheduled fires per event in scope (10-min lead + open for
  check-in; 10-min lead + open + closing-soon for sign-out), driven by
  `flutter_local_notifications.zonedSchedule` with
  `AndroidScheduleMode.exactAllowWhileIdle`. New `EventPhaseBanner`
  (`features/events/presentation/widgets/event_phase_banner.dart`) mounts
  above `NearbyEventBanner` on student Home and surfaces the active
  phase (gradient card, pulsing dot, 30-second tick). New
  `eventWindowRemindersProvider` toggle in Account → Notifications,
  default ON.
  - `lib/main.dart` initializes the IANA `timezone` database and sets
    `Asia/Manila` as the local TZ at boot, matching
    `backend/app/services/event_time_status.py:DEFAULT_EVENT_TIMEZONE`.
  - `geofence_background.dart` extended **additively**: shared
    `FlutterLocalNotificationsPlugin` instance exposed via
    `GeofenceBackground.notifications`; new `event_window` Android
    channel registered alongside the existing `nearby_checkin` channel
    (unchanged); `_dispatch` now accepts both `checkin:<id>` (legacy
    geofence) and `checkin:<id>:<action>` (new event-window) payloads.
    Existing `nearbyGeofenceCallback` / `pendingCheckInProvider` /
    `NearbyEventBanner` behavior is preserved.
  - Android manifest gains `USE_EXACT_ALARM` + `SCHEDULE_EXACT_ALARM`
    permissions (required by `flutter_local_notifications` on
    Android 12+ for `exactAllowWhileIdle`).
- **Campus admin can edit a student.** New
  `features/schoolit/presentation/edit_student_screen.dart` pushed from a
  pencil action in the student detail screen's app bar. Two independent
  save sections — **Identity** (first / middle / last name, email →
  `PATCH /api/users/{id}`) and **Academics** (student number, college,
  program, year level, status, promotion lock → `PATCH
  /api/users/student-profiles/{profile_id}`) — so a 400 on one section
  doesn't lose the other's edits. Each section has its own loading +
  error pill and its Save button is disabled until that section is
  dirty.
- **Status is now editable.** Five chips (Active, Graduated, Inactive,
  Transferred, Archived) with colour + icon (a11y). Transitioning
  **into** INACTIVE / TRANSFERRED / ARCHIVED requires an explicit
  confirm dialog ("This will block sign-in for this student.
  Continue?") — entering or staying in an already-destructive status
  is **not** flagged, matching the actual operator intent. ACTIVE /
  GRADUATED transitions confirm silently.
- **Year level segmented control** (1·2·3·4·5) with selection haptic;
  one tap, all options visible at once.
- **Promotion lock** switch with plain-English help: "When on, this
  student stays in the current year level when the school promotes
  everyone else."
- **`StudentProfile.promotionLocked`** added to the shared model
  (`shared/models/profile.dart`). Backend has been returning the
  field; we were dropping it.
- **Discard guard** — `PopScope` plus an app-bar `Discard` action
  appear only when at least one section is dirty; tapping back or
  Discard confirms before throwing away in-progress edits.

### Added (data layer)
- **`features/schoolit/application/edit_student_form.dart`** — pure-
  Dart form state holder. Seeds from a `UserProfile` snapshot, tracks
  per-section dirtiness, builds **only-dirty-field** patches so a
  year-level save doesn't re-send the email (which would trigger
  the backend's email uniqueness check unnecessarily). Client-side
  validators mirror the backend's regex / length rules so the
  operator sees errors before the request goes out. Pure-Dart, no
  Flutter widget imports — fully testable.
- **22 unit tests** in `test/unit/edit_student_form_test.dart`
  covering seeding, dirty tracking, patch building (including
  middle-name nulling on empty), destructive-status detection, and
  every validator branch (empty fields, bad email, bad student-id
  characters, length bounds, missing college/program).

### Changed
- **`StudentDetailScreen` is now read-only with a pencil action.**
  The previous "Change college" in-line bottom sheet was a single-
  purpose modal that only let admins reassign dept + program; it's
  been removed in favour of the full edit surface above, which
  covers every editable field plus status.
- **`pubspec.yaml` — `timezone: ^0.9.4` → `^0.11.0`.** Required by
  `flutter_local_notifications ^21.0.0`; the previous constraint
  combination wouldn't resolve at all (`pub get` failed with
  "version solving failed"). The bump is the version
  `flutter_local_notifications` author requires.

### Added (v1.36.0)
- **Event window reminders.** Notifies the user when an event's
  check-in or sign-out window opens, aligned to the backend's
  `check_in_opens_at` / `sign_out_opens_at` thresholds (Asia/Manila).
  Up to five scheduled fires per event in scope (10-min lead + open for
  check-in; 10-min lead + open + closing-soon for sign-out), driven by
  `flutter_local_notifications.zonedSchedule` with
  `AndroidScheduleMode.exactAllowWhileIdle`. A new `EventPhaseBanner`
  (`features/events/presentation/widgets/event_phase_banner.dart`)
  mounts above `NearbyEventBanner` on student Home and surfaces the
  active phase (gradient card, pulsing dot, 30-second tick). New
  `eventWindowRemindersProvider` toggle in Account → Notifications,
  default ON.
- **Settings.** "Event window reminders" tile sits beside "Nearby
  event check-in" in Account → Notifications. Independent toggles —
  the existing location-based prompt is unchanged.

### Changed
- `lib/main.dart` initializes the `timezone` database +
  `Asia/Manila` as the local TZ at boot, matching
  `backend/app/services/event_time_status.py:DEFAULT_EVENT_TIMEZONE`.
- `geofence_background.dart` extended **additively**: shared
  `FlutterLocalNotificationsPlugin` instance is exposed via
  `GeofenceBackground.notifications`; new `event_window` Android
  channel registered alongside the existing `nearby_checkin` channel
  (unchanged); `_dispatch` now accepts both
  `checkin:<id>` (legacy geofence) and `checkin:<id>:<action>` (new
  event-window) payload forms. Existing
  `nearbyGeofenceCallback` / `pendingCheckInProvider` /
  `NearbyEventBanner` behavior is unchanged.
- Android manifest gains `USE_EXACT_ALARM` +
  `SCHEDULE_EXACT_ALARM` permissions (required by
  `flutter_local_notifications` on Android 12+ for
  `exactAllowWhileIdle`).

### Added
- **Student profile shows college and program.** The Profile screen
  (`features/student/presentation/profile_screen.dart`) is split into
  two cards along a clean axis — **Academics** on top (Program,
  College, Year level), **Identity** underneath (Student number,
  Status, Face ID).
  - Program and College names resolve asynchronously from the new
    directory providers (below) and cross-fade in from a skeleton
    placeholder — 220 ms fade + scale 0.96 → 1.0 (never `scale(0)`;
    honors reduced motion). No `—` placeholder snap-to-text.
  - Year level renders immediately in mono (e.g. `2nd year`) — no
    network needed, the value is in `/users/me`.
  - Each row has a tinted icon chip (book / tree / school) +
    uppercase label + value; consistent with the rest of the app's
    bento system.
- **Status row is a colour-coded chip with an icon** (Active /
  Inactive / Graduated / Withdrawn / Suspended / Unknown) instead
  of plain text — same colour + icon rule the rest of the app uses
  for a11y.
- **Face ID is also a chip** (Enrolled vs Not enrolled) so the
  identity card reads as a vertical list of binary states at a
  glance.
- **Student number is now tap-to-copy.** The whole row is pressable
  (Pressable with scale-on-press + selection haptic), the copy
  icon hints discoverability, and a snackbar confirms the copy
  with the value verbatim. Empty / unassigned student numbers fall
  back to a muted "Not assigned" with no copy affordance.
- **Subtle academic line on the Account tab profile card.** Under
  the email, students now see one mono dot-separated line like
  `BSCS · 2nd year` (program short-code + year ordinal). Renders
  only when at least one piece resolves; hidden silently otherwise
  (no placeholder flicker). Program short-code is derived locally
  (`"BS Computer Science"` → `"BSCS"`, all-caps acronyms kept
  verbatim, lowercase tokens like "of" / "in" dropped).

### Added (data layer)
- **New `core/data/school_directory_repository.dart`.** Read-only
  surface over `/api/departments/` and `/api/programs/` — both
  open to any authenticated user (Backend Documentation lines
  1049 / 1129), so the student app calls them directly. Mutating
  endpoints (create / update / delete) stay in
  `SchoolItRepository`.
- **Session-cached providers:** `allDepartmentsProvider`,
  `allProgramsProvider` (not `autoDispose` — directory is small,
  refetching on every screen mount would be wasteful) +
  `departmentByIdProvider(int)` / `programByIdProvider(int)`
  family providers that resolve one name from the cached list.
  Pull-to-refresh on Profile invalidates both directory caches
  alongside `/users/me`.

### Notes
- Google Sign-In `DEVELOPER_ERROR(10)` on release builds is a
  Google Cloud Console configuration issue, not a code one. Fix
  is to add the release keystore's SHA-1 fingerprint to an
  Android OAuth client in the Cloud project that owns
  `AURA_GOOGLE_WEB_CLIENT_ID`. Package name `com.aura.aura_app`.
  No Flutter or backend code change required.

### Added (event editor — location search)
- **Search a place to set the event geofence centre.** The "Where"
  section of the event editor
  (`features/schoolit/presentation/event_editor_screen.dart`) gains a
  search field above the map: type *"Dapitan City"*, *"Main Library"*,
  or any free-text query and pick from a dropdown of matches — the map
  pans to that point and the geofence pin moves there. Tap-the-map
  remains as the always-works fallback (the hint now reads "Or tap the
  map to set the centre."). If the venue field is empty when a result
  is picked, it's seeded with the result's short name; a venue the
  user already typed is never overwritten.
- **Inline result dropdown with the right motion.** `AnimatedSize`
  (240 ms `AppMotion.easeOut`, top-aligned) pushes content down rather
  than overlay, so the form stays scrollable and works on small
  phones. Inner `AnimatedSwitcher` (180 ms) cross-fades between
  *searching* / *no matches* / *results* states with stable
  `ValueKey`s so transitions don't restart. Result rows stagger in via
  the existing `staggered()` helper (50 ms cadence). Each row is a
  `Pressable` — scale-0.97 press feedback + selection haptic come for
  free. Reduced motion fully honored.
- **New `core/services/geocoding_service.dart`.** Thin client over the
  public OSM Nominatim endpoint
  (`https://nominatim.openstreetmap.org`). Sets a descriptive
  `User-Agent` per Nominatim's usage policy; the 450 ms UI debounce
  keeps a single typing user safely under the ≤1 req/sec limit.
  Errors collapse to an empty list so the UI renders "no matches"
  rather than a crash. Static `parseResult` exposed for unit tests;
  provider mirrors the existing `geolocationServiceProvider` pattern.
  *Caveat:* fine for a single IT admin creating occasional events;
  swap to a self-hosted Nominatim or a commercial geocoder if Aura
  ever needs burst usage.
- 8 unit tests in `test/unit/geocoding_service_test.dart` lock in the
  parser contract (string/numeric lat-lon, missing/malformed fields,
  primary/secondary split) + the no-network short-circuit on empty
  queries.

### Changed
- **Event editor "Officers only" defaults to OFF, even in a governance
  context.** New events created from a governance unit used to start
  with `Officers only = true` (`_EventEditorScreenState.initState`),
  which surprised officers who actually wanted a school-wide event and
  had to remember to flip the switch off. The default is now OFF
  regardless of context — audience starts as "all students" (year-level
  chips visible), and the officer can flip the switch on to narrow it.
  Editing an existing event still reads the saved `isOfficersOnly`
  flag from the backend (unchanged).

## [1.35.2] - 2026-05-28

### Added
- **Credentials-reveal bottom sheet after manual student creation.** The
  School-IT "Manual Add" flow used to end with a tiny "Student added."
  snackbar, leaving the IT admin with no way to tell the new student how
  to sign in (the backend `create_student_account` path doesn't send a
  welcome email — only the generic `create_user` path does). The flow now
  ends with a polished bottom sheet that surfaces both pieces:
  - **Email** rendered in JetBrains Mono with a one-tap copy button.
  - **Temporary password** rendered in mono with a one-tap copy button.
    The password is computed client-side from the typed last name
    (`lastName.trim().toLowerCase()`, fallback `"password"` if empty) —
    the **same rule** the backend uses in
    `backend/app/routers/users/students.py:42`. Zero extra round-trips,
    backend stays authoritative on the hash.
  - Inline note explains the convention and that the student will be
    forced to change it on first sign-in (`must_change_password=true`).
  - "Add another" keeps the IT admin on the form with the college /
    program / year / status pre-selected and only the name+email cleared
    — typical bulk-add ergonomics.
- **Emil-style polish on the sheet.** Drag handle, `AppRadii.rSheet`
  rounded top, surface-token background, soft `AppElevation.card`
  shadow, stagger-50ms entrance via the existing `staggered()` helper,
  press-scale 0.97 via `Pressable`, copy → 200 ms scale+fade cross-fade
  to a green check that auto-resets after 1.4 s, mono numerals with
  tabular figures so passwords like `o0o0` can't be misread,
  reduced-motion fully honored.

## [1.35.1] - 2026-05-28

### Fixed
- **School-IT dashboard now shows accurate, growing student counts.** The
  user-listing pagination in `SchoolItRepository.students()` was sending
  `?page=N` to `GET /api/users/`, which the backend silently ignores — it
  paginates by `skip`+`limit` and returns a **bare list**, not the
  `{data,total_pages}` envelope the Flutter code assumed. Because the
  `List` branch hard-set `totalPages = 1`, the loop exited after one
  iteration and the app only ever saw the **first 500 users** ordered by
  id ASC. Now walks `skip=0,500,1000,…` and stops when a page returns
  `< limit` items.
- **"Manually added student doesn't appear" was the same bug.** New
  accounts get the highest id, so on schools with >500 user rows they sat
  past the truncated first page and never showed up after the success
  snackbar. The POST always succeeded; the refetch was just returning the
  same first-500 list. Fixed by the pagination change above.
- **Dashboard "Students" card no longer counts faculty / admin / school-IT
  accounts.** `schoolit_home_screen.dart` was using `students.length`,
  which counts every account `/users/` returns. Now filters to
  `studentProfile != null` to match `schoolit_users_screen.dart` so the
  dashboard and the Users-by-College screen agree.
- **Add-student flow awaits the refetch before popping.** The previous
  invalidate-then-pop left a single-frame flash of the old count;
  `add_student_screen.dart` now `await`s `ref.read(studentsProvider.future)`
  so the new student is already in the list when the snackbar appears.

## [1.35.0] - 2026-05-28

### Added
- **On-device passive liveness defence in front of every face scan.** Both
  the student self-scan (`features/attendance/presentation/attendance_screen.dart`)
  and the multi-face Gather kiosk
  (`features/gather/presentation/gather_scan_screen.dart`) now hard-gate
  spoof attempts **before** they leave the device. Photos, screen
  replays, and printed faces are rejected without a backend round-trip.
  Backend MiniFASNet (the same Silent-Face-Anti-Spoofing model) stays the
  authoritative check — this is a fast-feedback / fast-reject defence
  layer on top, not a replacement.
- **Self-scan preflight gate.** The capture button is **disabled** while
  the on-device model says the framed face is a spoof. A real-time pill
  above the button cross-fades through `Verifying…` → `Looking for your
  face` → `Real face — ready to scan` → `Possible spoof — adjust`
  (220 ms scale + fade, never `scale(0)`, never ease-in). The face
  framing ring tints green / red to match. Camera runs in image-stream
  mode (NV21) at ~6 fps; when the operator taps capture we stop the
  stream and `takePicture` for a clean JPEG to send.
- **Kiosk per-frame gate.** Every cooldown the kiosk takes the latest
  NV21 frame, runs ML Kit face detection + the anti-spoof model on the
  **largest** face (fastest path, strongest spoof signal — a held-up
  phone or printed photo fills more of the frame than legitimate
  bystanders), and:
  - **Skips the POST entirely** when the largest face is a spoof —
    bumps a local `spoofs` counter, flips the `GatherStatusChip` to
    "Spoof rejected", plays the alert system sound + heavy haptic, and
    inserts a synthetic `liveness_failed` outcome with `reason_code:
    spoof_detected_on_device` into the live log so the operator sees
    it in the bento.
  - **Skips the POST when no face is detected** — no point hitting the
    backend with an empty room.
  - **Encodes the NV21 frame to JPEG** in a `compute()` isolate (so
    the camera thread never stalls) and sends to backend on success.
- **`features/liveness/`** new module:
  - `domain/liveness_models.dart` — `FaceCheck`, `LivenessFrameResult`
    (`unavailable` / `empty` / `transientError` / live verdict),
    `Nv21Frame`. The `isSpoof` getter is the canonical hard-gate
    signal: it's `true` only when `usable == true` AND at least one
    face is present AND no face passes the threshold. `usable == false`
    NEVER reads as spoof — callers fall through to backend-only.
  - `application/liveness_service.dart` — single owner of both
    plugins. `LivenessBackend` interface (production
    `PluginLivenessBackend` + an injection point for tests).
    Idempotent `initialize()` that swallows platform errors and
    returns false rather than throwing. `analyze(Nv21Frame)` never
    throws — every failure path returns a `LivenessFrameResult` the
    caller can branch on. `dispose()` is safe without prior init.
    Exposed via `livenessServiceProvider` (Riverpod), session-scoped
    so the ~10 MB native model only loads once.
  - `application/nv21_codec.dart` — `buildNv21FrameFromCamera`
    safely packs a two-plane NV21 `CameraImage` into the single
    `width * height * 3 / 2` buffer the plugin expects (returns null
    when the device handed us a different format, so the caller can
    gracefully disable the gate). `encodeNv21ToJpeg` does
    NV21 → BT.601 RGB → rotated JPEG inside `compute()`; the RGB
    conversion uses integer math (12-bit shifts) so it's ~3× faster
    than a float pipeline and visually indistinguishable.

### Added (deps)
- **`face_anti_spoofing_detector: ^0.0.4`** — Silent-Face-Anti-Spoofing
  (MiniFASNet) on-device model. **Android-only at v0.0.4** — the iOS
  plugin is a stub that only implements `getPlatformVersion`. The
  service detects this at runtime and degrades to `usable=false` on
  iOS without surfacing a `FlutterMethodNotImplemented` error to the
  user.
- **`google_mlkit_face_detection: ^0.12.0`** — feeds bounding boxes
  to the anti-spoof model. Configured in `fast` mode with no
  landmarks / contours / tracking / classification (we only need
  bounding boxes for the gate — pulling everything would burn 2–3×
  the per-frame budget).
- **`image: ^4.3.0`** — promoted from transitive to direct so we can
  use it explicitly for the NV21 → JPEG path in the kiosk.

### Added (tests)
- **`test/unit/liveness_service_test.dart`** — 14 cases covering the
  contract: idempotent init, empty-frame defence, multi-face largest
  selection (single liveness call regardless of face count),
  threshold comparison (`>=`), null-score handling (treated as
  unknown — hard-gate, since the model gave no signal), transient
  errors flip `usable=false` so the caller doesn't gate on stale
  data, and dispose-without-init safety.

### Changed
- **Attendance camera mode.** Was `takePicture`-only with
  `ImageFormatGroup.jpeg`. Now image-stream mode with NV21 (Android,
  liveness usable) or unchanged JPEG (iOS, liveness unavailable —
  identical behaviour to before this release). The change is invisible
  to backend-only flows.
- **Kiosk camera mode.** Was `ImageFormatGroup.jpeg` +
  `ResolutionPreset.high` + `takePicture` per cooldown. Now image-
  stream mode with NV21 + `ResolutionPreset.medium` when liveness is
  usable (the backend auto-downscales to 1280 px regardless, so high
  was already overkill). When liveness is unusable, falls back to the
  previous behaviour. Stream lifecycle is owned by the kiosk —
  `_stopStreamIfRunning()` is called in dispose so the camera releases
  cleanly when the operator backs out.

### Defence-in-depth posture
The backend's MiniFASNet remains the source of truth — every frame
that gets sent is re-verified server-side at the stricter
`public_attendance_liveness_threshold = 0.92`. The new client-side
gate sits at `0.85` (matching the backend's `liveness_threshold` for
self-scan). If the on-device model ever produces a false positive,
the server's stricter check still catches it. If the device's plugin
init or per-frame detect throws, we fall through to backend-only —
behaviour is then exactly what it was before this release.

## [1.34.0] - 2026-05-28

### Added
- **Gather kiosk — full production pass.** The public, unauthenticated
  multi-face check-in kiosk (anyone standing near a geofenced event
  can point a back camera at the room and record attendance for up to
  10 faces per frame) is now production-grade across both screens.
  **Discovery**
  (`features/gather/presentation/gather_screen.dart`) rebuilt:
  header card explains kiosk mode in plain English; events sort into
  "open near you" vs "waiting for window"; each card carries a phase
  pill (Sign-in / Sign-out / Closed, colour + icon), a colour-coded
  distance badge with accuracy (`±NN m`), a venue + time-window line,
  the backend's `phase_message` ("Early check-in opens in 12 min"),
  and a scope chip (Campus-wide, department, or program — collapses
  to `+N` on overflow). Out-of-range state explains why and prompts a
  refresh after moving. **Scan kiosk**
  (`features/gather/presentation/gather_scan_screen.dart`) rebuilt as
  a full-bleed dark surface: top status row (back, event, phase
  pill); camera with calm pulsing two-ring scan overlay + corner
  framing brackets; top-centre live status chip that cross-fades
  through Standby → Looking → Verified / Spoof rejected / Liveness
  bypassed / Out of scope on every frame (220 ms ease-out, never
  from `scale(0)` — emil); top-right geofence + accuracy badge
  reading from the server's `geo` block; bottom-left "last
  recognized" card with name + confidence; bottom bento with mono
  session count, breakdown chips (checked in / signed out / spoofs
  caught / rejected), and a scrollable recent-outcome list. Stop now
  opens a polished `GatherSummarySheet` with the total, breakdown,
  runtime, last five recognitions, and Resume / Done actions.

### Added (new widgets)
- `features/gather/presentation/widgets/gather_phase_pill.dart` —
  reusable phase pill and scope chip used by both the discovery
  cards and the kiosk header. Always colour + icon (a11y).
- `features/gather/presentation/widgets/gather_scanning_ring.dart`
  — calm pulsing two-ring overlay (two ripples 180° out of phase,
  scale 0.85 → 1.10, opacity 0.55 → 0; reduced-motion renders a
  single static outline), corner framing brackets `CustomPainter`,
  and the "Scanning…" capsule.
- `features/gather/presentation/widgets/gather_status_chip.dart` —
  `GatherStatus` enum + animated chip with a 220 ms scale + fade
  swap (asymmetric 140 ms exit). Pulsing dot in the Looking state.
- `features/gather/presentation/widgets/gather_outcome_tile.dart`
  — one outcome row with action-coloured leading chip (success /
  info / warning / danger / neutral via `OutcomeIntent`), display
  name, action label, optional liveness badge (Real / Spoof /
  Bypassed), and mono confidence. One-shot pop on mount (scale 0.94
  → 1.0 + fade, 260 ms ease-out) and a damped 320 ms horizontal
  shake on hard liveness failures.
- `features/gather/presentation/widgets/gather_summary_sheet.dart`
  — end-of-session bottom sheet: mono total, duration chip,
  breakdown chips, last five recognitions, Resume + Done.

### Added (wiring)
- **Entry on the workspaces that run kiosks.** School-IT home
  (`features/schoolit/presentation/schoolit_home_screen.dart`) gains
  a new "Run" section above "Manage" with a single accent-tinted
  `Gather kiosk` `DashboardActionRow`. Governance home
  (`features/governance/presentation/governance_home_screen.dart`)
  gains a fifth `_QuickAction` tile (brand accent), gated by
  `manage_events` (locked + tooltip otherwise). Both push
  `GatherScreen`.

### Added (capabilities)
- **`wakelock_plus: ^1.2.5`** — keeps the screen awake while the
  loop is running. Enabled on Start, disabled on Stop and in
  `dispose()`. The `android.permission.WAKE_LOCK` permission was
  already in the manifest. Errors are swallowed (screen-unavailable
  scenarios shouldn't fail a scan).
- **Audio + haptic feedback** — every successful recognition fires
  `SystemSound.click` + `HapticFeedback.lightImpact`; every spoof
  fires `SystemSound.alert` + `HapticFeedback.heavyImpact`. Both
  skipped when `MediaQuery.disableAnimations` is true. No plugin
  needed — built-in `flutter/services` only.
- **Backgrounding pauses the loop.** `WidgetsBindingObserver` stops
  the loop on any non-resumed lifecycle state; the operator taps
  Start again on return. Keeps the camera from running unobserved
  and lets the OS reclaim it cleanly.

### Added (models)
- **`NearbyEvent`** gains `effectiveDistanceM`, `accuracyM`,
  `departments`, `programs`, plus `phaseLabel`, `isSignIn`, `isOpen`,
  and `insideGeofence` getters.
- **`Liveness`** new — `{label, score?, reason?}` with `isReal`
  / `isFake` / `isBypassed` getters. Parsed from the backend's
  per-face `liveness` block.
- **`GeoStatus`** new — geolocation verification block from the
  multi-scan response (`ok`, `reason`, `distance_m`,
  `effective_distance_m`, `radius_m`, `accuracy_m`).
- **`ScanOutcome`** gains `reasonCode`, `distance`, `confidence`,
  `threshold`, `liveness`, `timeIn`, `timeOut`, `durationMinutes`,
  plus `isSignIn` / `isSignOut` / `isAlreadyRecorded` /
  `isLivenessFailed` / `isOutOfScope` / `isNoMatch` / `isDuplicate`
  / `isCooldownSkipped` / `isRejected` / `isHardFailure` getters,
  `displayName` fallback, and a human `actionLabel`. The new
  `ScanOutcomeIntent` extension maps each action to an
  `OutcomeIntent` and a Material rounded icon — same mapping reused
  by every surface (chip, tile, summary).
- **`MultiScanResult`** gains `geo` (the `GeoStatus` block).
- **`shared/utils/json.dart`** gains `asStrList()` for the
  `departments` / `programs` arrays.

### Changed
- **Failures are now visible.** The previous loop only logged
  successes — spoofs, no-match frames, and out-of-scope hits were
  invisible to the operator (the camera "appeared to do nothing"
  while actually rejecting frames). The kiosk now logs every
  meaningful outcome (suppressing only `duplicate_face` and
  `cooldown_skipped` — frame-internal noise) and counts spoofs and
  out-of-scope rejections in the bottom bento.
- **Per-frame status decision** — the live status chip picks the
  most important state from the frame: a verified real match beats
  a spoof attempt in the same frame (the attendance landed
  successfully), bypassed beats spoof beats out-of-scope.

## [1.33.2] - 2026-05-28

### Fixed
- **Release APKs pointed at the HTTP staging backend no longer brick
  every request with a generic "Unexpected error" / "Couldn't reach
  the server" message.** `DioClient._assertSecureInRelease` previously
  threw a `StateError` unconditionally for any release build with an
  `http://` base URL, so the Dio instance never finished constructing
  and every login / forgot-password call fell into the screens'
  catch-all error blocks. The guard now uses the same allow-list as
  `network_security_config.xml` — the staging IP `18.142.190.113`,
  the Android emulator loopback `10.0.2.2`, `127.0.0.1`, and
  `localhost`. Cleartext to any other host still aborts loudly, so
  the original defence-in-depth posture is preserved for genuine
  production builds.

## [1.33.1] - 2026-05-28

### Added
- **"Learn about Aura" link on the login footer.** Sits next to the
  existing "Forgot your password?" and "Need help?" pressables. Opens
  `https://aura-test.coeofjrmsu.com/` in the user's default browser
  via `url_launcher` (`LaunchMode.externalApplication`). The label
  carries a small `open_in_new_rounded` icon (14 sp, muted) so it's
  obviously an external link before the user taps. Disabled while the
  login form is submitting; surfaces a snackbar if no browser handler
  is available rather than failing silently.
- **`url_launcher: ^6.3.1`** as a direct dependency. Previously only
  pulled in transitively by other plugins, which left the public
  `launchUrl` API unavailable to our code.

## [1.33.0] - 2026-05-28

### Added
- **Event editor now covers every backend knob, in plain English.** The
  form is sectioned for breathing room (one job per card) and no
  longer asks the user to learn jargon. Sections, top to bottom:
    * **About** — name, venue, description.
    * **When** — start / end pickers.
    * **Who can attend** — `Officers only` switch (governance context
      only) + `Year levels` chips. When the switch is on, year chips
      are hidden via `AnimatedSize` (260 ms ease-out) and the audience
      is the governance unit's active members. When off (or outside a
      governance context), the chips are shown with the hint "Leave
      empty to invite every year." Empty selection always sends
      `year_levels: []` — the backend sentinel for "all years".
    * **Timing** — three `_MinuteStepper` rows for **Check-in opens**,
      **Marked late after start**, **Sign-out window after end**. Each
      row has a dynamic plain-English subtitle ("$x minutes before
      start", "Late immediately", "Closes at end time" for the zero
      case). Steppers move in 5-minute steps from 0 → 120; the value
      animates via `AnimatedSwitcher` cross-fade.
    * **Where** — existing geofence section. The map / radius slider
      now lives inside an `AnimatedSize` so toggling location-required
      reveals / hides the map with a smooth height tween.
- **Initial timing values come from `SchoolBranding`**, not hardcoded.
  `_applySchoolDefaultsIfFresh` reads the school's defaults once after
  `schoolProvider` resolves and seeds the three minute fields. Existing
  events preload from the event's per-event override.
- **`AppEvent.governanceUnitId`** (`shared/models/event.dart`) — FK to
  the governance unit when the event was created with
  `governance_context`. Drives the "Officers only" switch in edit mode.
- **`AppEvent.yearLevels`** — parses both the canonical `year_levels`
  list and falls back to deriving from `event_targets[].year_level` so
  existing events created via the legacy shape still light up the
  right chips on edit.
- **`AppEvent.isOfficersOnly`** convenience getter.

### Changed
- **`buildEventEditorPayload`** (`features/events/application/
  event_editor_payload.dart`) now also accepts `yearLevels`,
  `earlyCheckInMinutes`, `lateThresholdMinutes`, `signOutGraceMinutes`.
  `year_levels` is **always** sent (empty list when the user picked no
  chips); the three minute fields are sent when non-null. Out-of-range
  values throw `EventEditorPayloadError` with a plain-English message.
- **Save handler** drops the `governance_context` query param when the
  user turns "Officers only" off — preventing the backend from
  scoping the event to a unit that has no audience. The repository
  `create` / `update` calls receive `null` for `governanceContext` in
  that case.
- **`event_editor_payload_test.dart`** — snapshot updated to include
  `year_levels`, `early_check_in_minutes`, `late_threshold_minutes`,
  `sign_out_grace_minutes`. Added two new cases: "always sends
  year_levels (empty list = open to all)" and "rejects out-of-range
  year levels and minute fields".

### Notes
- Out of scope for this commit, deliberately deferred to keep the diff
  reviewable: an Event Type picker (would need a new repo + provider
  for `GET /api/event-types`), the `notes` / `banner_url` / `venue-vs-
  location` distinction, `geo_max_accuracy_m`, and
  `sign_out_open_delay_minutes`. These can land as separate small
  diffs once the foundation here is verified on a device.

### Build
- **Release signing wired up** in `android/app/build.gradle.kts`. The
  release `signingConfig` now loads credentials from `key.properties`
  (git-ignored) via the standard Gradle pattern. With no
  `key.properties` the release build fails loudly instead of silently
  falling back to the debug keystore — preventing accidental shipping
  of debug-signed artifacts. The `.jks` and `key.properties` are added
  to `.gitignore`.
- The release APK + per-ABI APKs build successfully with `flutter
  build apk --release --dart-define-from-file=config/cloud.json
  --obfuscate --split-debug-info=build/symbols`.

## [1.32.1] - 2026-05-27

### Changed
- **Email is no longer editable in the profile screen** for any role.
  `features/student/presentation/edit_profile_screen.dart` renders the
  Email `AuraTextField` with `enabled: false` and a small inline hint
  ("Email can't be changed here. Contact your campus admin if it's
  wrong."). The PATCH payload to `/users/{id}` no longer includes
  `email` — even if a stale controller still held a value. Email
  changes must go through a campus admin so the audit trail stays
  intact.
- **Help Center "Contact Support" card is now dynamic per school.**
  `features/help/presentation/help_center_screen.dart` `_ContactCard`
  is a `ConsumerWidget`; it reads the signed-in user's `schoolName` and
  workspace from `sessionControllerProvider` and shows the **Campus
  Admin** row only for students and governance officers. The row
  surfaces the user's school name (not a hardcoded email — the API
  doesn't expose the school's campus-admin email and the Flutter app
  must not change the backend); tapping the row opens a snackbar
  hint: "Reach your campus admin at {schoolName} in person or through
  your school's official email." Platform admins (no school) and
  campus admins themselves don't see the row — self-referential or
  not actionable. The row uses the body font, not mono, with an
  info-icon trailing affordance instead of the copy icon.
- **Replaced the hardcoded "IT support: it@aura.school" row** with a
  new **"Aura support"** row that points to
  `auraautomessage@gmail.com`. Documentation row unchanged.

### Added
- **`HelpContent.auraSupportEmail`** constant
  (`auraautomessage@gmail.com`) — single source of truth for the Aura
  platform inbox.
- **`_ContactRow`** now takes optional `isMono` (default true) for
  plain-prose values like a school name, `trailingIcon` for the row's
  trailing affordance, and `onTap` override so info-only rows can
  surface a hint instead of copying to the clipboard.

### Removed
- **`HelpContent.itEmail`** constant — its only consumer (the IT
  support contact row) was replaced by the Aura support row above.

## [1.32.0] - 2026-05-27

### Changed
- **Forgot-password flow is now three stages** to match the new backend
  contract (commit `154c815`): `/auth/forgot-password` → mails a 6-digit
  code; `/auth/verify-reset-code` → returns a short-lived `reset_token`;
  `/auth/reset-password` → consumes `{reset_token, new_password}`. The
  user only sees the new-password form *after* the code is verified —
  no more typing a password against an invalid code, and stage 3 is
  unreachable without a server-returned token.
- **`forgot_password_screen.dart` rewritten** around a `_Stage` enum
  (`email` / `code` / `password`) with three private stage builders and
  a single `AnimatedSwitcher` driving the transitions. Asymmetric cross-
  fade per emil-design-eng: outgoing drops 12 dp + fades; incoming lifts
  8 dp + fades. `AppMotion.modal` (260 ms) / `AppMotion.easeOut`
  throughout — never ease-in. Honours `MediaQuery.disableAnimations`.
- **Three-segment progress strip** (`_StageProgress`) sits above the
  IconBadge so the user always knows where they are in the journey.
  Active segment paints `t.accent`, completed segments paint accent at
  50 % opacity, upcoming segments paint a softened `t.border`; each
  segment's colour animates 240 ms ease-out on stage advance.
- **Inline `email` echo on the code stage** rendered in
  `AppTypography.mono` so the user can sanity-check what they typed
  without scrolling back.
- **Error banner now reveals via `AnimatedSwitcher`** (200 ms fade +
  6 dp downward slide), via a new `_ErrorBanner.show()` helper that
  collapses cleanly when `error == null` — no conditional wrappers in
  the stage builders.
- **Back button is stage-aware.** Stage 1 → pop route. Stage 2 →
  back to stage 1, clears the code. Stage 3 → back to stage 2, clears
  the new-password fields AND drops the reset token (the token is
  single-use and time-bound, so re-verification is the safer recovery
  path).

### Added
- **`auth_repository.verifyResetCode({email, code})`** — `POST
  /auth/verify-reset-code`, returns the opaque `reset_token` string;
  surfaces 400 / 429 as `ApiException`. Includes the standard
  `/api/auth/...` fallback for deployments that mount auth under
  `/api`.
- **`auth_repository.resetPassword({resetToken, newPassword})`** —
  `POST /auth/reset-password` with the new payload shape (token, no
  longer email + code).
- **`AuraTextField` now accepts a `focusNode`** so callers can drive
  focus programmatically. Used to focus the new-password field on the
  password stage advance.

### Removed
- **`auth_repository.resetPasswordWithCode({email, code, newPassword})`**
  — the old 2-step combined endpoint signature. Replaced by the
  `verifyResetCode` + `resetPassword` pair above.

## [1.31.2] - 2026-05-27

### Removed
- **Admin-approval password-reset surface.** Backend dropped
  `GET /auth/password-reset-requests` and
  `POST /auth/password-reset-requests/{id}/approve` (commit `f29fc56`);
  the client-side admin approval queue would just 404 forever. Mirroring
  the official Frontend Implementation Guide:
    * `lib/shared/models/admin.dart` — `PasswordResetRequest` class.
    * `lib/core/network/api_paths.dart` — `passwordResetRequests` constant
      and `approvePasswordReset(id)` builder.
    * `lib/features/admin/data/admin_repository.dart` — `pendingResets()`
      and `approveReset(id)` methods.
    * `lib/features/admin/application/admin_providers.dart` —
      `pendingResetsProvider`.
    * `lib/features/admin/presentation/admin_home_screen.dart` —
      `_approving` set, `_approve` handler, `pendingAsync` watch, the
      `invalidate(pendingResetsProvider)` calls inside pull-to-refresh,
      the paired "Pending resets" metric card, and the entire
      "Pending password resets" section (`AuraCard` queue + Approve
      buttons). Converted `ConsumerStatefulWidget` → `ConsumerWidget`
      since no local state remained; pruned now-unused imports
      (`aura_button.dart`, `widgets/states.dart`, `utils/formatting.dart`,
      `data/admin_repository.dart`).
    * `lib/features/help/data/help_content.dart` —
      `ac-forgot-password` tip line that pointed Admins and Campus
      Admins at the admin-approval flow. Self-service applies to
      students and campus admins; platform admins reset out-of-band.
    * `test/unit/admin_test.dart` — `PasswordResetRequest parses` case
      (the only test of the now-deleted model).

### Changed
- **Admin Home metric row → single full-width Campus admins card.** The
  Row that paired "Campus admins" with "Pending resets" is now a single
  card. Subscription breakdown and Create-school action below it are
  unchanged.

## [1.31.1] - 2026-05-27

### Fixed
- **UI-quality tests now actually exercise their intended viewport.**
  `tester.binding.setSurfaceSize` was silently a no-op in this Flutter
  version — `tester.view.physicalSize` retained the default 800 × 600
  logical surface, so every iteration of the multi-viewport test ran at
  the medium breakpoint. After the v1.31.0 responsive shell that meant
  `DesktopShell` (not the bottom nav) was rendered for *every* viewport,
  including "mobile". `_withViewport` now drives `tester.view.physicalSize`
  / `devicePixelRatio` directly (and resets in `finally`), and the
  layout-exception test only runs the bottom-nav tap loop at
  `Breakpoint.compact` (the bottom nav is *correctly* absent at
  medium/expanded — that's the new design). The two mobile-only tests
  (semantics labels, pressable responses) call a new `_forceMobileViewport`
  helper so they pin to compact regardless of the host's default view.
  Suite back to all green: **142 / 142**, analyze clean.

## [1.31.0] - 2026-05-27

### Added
- **Responsive app shell — sidebar at tablet/desktop sizes.** `AppShell`
  now branches on `BreakpointContext.breakpoint`:
    * `Breakpoint.compact` (< 600 dp) — unchanged mobile path with the
      glass / liquid bottom-nav, byte-identical to the prior build.
    * `Breakpoint.medium` / `Breakpoint.expanded` (≥ 600 dp) — new
      `DesktopShell` (`features/shell/desktop_shell.dart`) with a
      vertical `SidebarNav` rail on the start side and the same tab
      content on the trailing side. Selected-tab state lives in the
      parent so the choice of layout is purely visual: resizing across
      a breakpoint (tablet rotation, desktop window resize) keeps the
      user on the same tab.
- **`lib/core/layout/breakpoints.dart`** — `Breakpoint` enum, threshold
  constants (`Breakpoints.mediumMin=600`, `expandedMin=1024`), sidebar
  widths (`sidebarCollapsedWidth=76`, `sidebarExpandedWidth=264`), a
  pure `Breakpoints.fromWidth` resolver (unit-testable without a
  widget tree), and a `BreakpointContext` extension that reads from
  `MediaQuery.sizeOf`.
- **`SidebarNav`** (`features/shell/sidebar_nav.dart`) — vertical nav
  rail with three zones: brand header (school logo + name from login
  meta), nav list with a single sliding active pill
  (`AnimatedPositioned`, `AppMotion.modal` + `easeOut`), and an
  account card that taps into the Account tab. Rail width animates
  via `AnimatedContainer` when the breakpoint changes mid-session.
  Active pill paints the school's brand accent via `AppTokens.accent`
  — never hardcoded.
- **`AnimatedTabStack`** (`features/shell/animated_tab_stack.dart`) —
  the cross-fade tab transition extracted from `AppShell` into its
  own widget so the mobile shell and the new desktop shell render tab
  switches identically.
- **`test/unit/breakpoints_test.dart`** — pure-function coverage on
  `Breakpoints.fromWidth`, `BreakpointHelpers.sidebarWidth`,
  `isCompact / isMedium / isExpanded`, and the `BreakpointContext`
  extension across the three viewports.

### Changed
- **`scripts/run-web-dev.ps1`** — replaces `flutter run -d chrome`
  with `-d web-server` plus a manual Chrome spawn driven by a polling
  `Start-Job`. **Why:** Chrome 130+/Windows intermittently never
  completes the DevTools handshake when another Chrome session is
  already running, so Flutter's `chrome_device` fails after three
  retries (`Failed to launch browser after 3 tries`). The new
  approach has Flutter bind the port without auto-launching anything,
  and we own the Chrome spawn:
    * Prunes stale `flutter_tools.*` temp dirs older than 24 h
      (these accumulated ~7 GB before this cleanup).
    * Clears `Singleton*` lock files in the Chrome profile from
      crashed / killed prior runs so re-launching the same
      `--user-data-dir` doesn't refuse.
    * Frees `:5174` by stopping only the process bound to that exact
      port (not all dart processes — your IDE / a second project
      may legitimately have its own running).
    * Spawns Chrome from a `Start-Job` that polls the port (180 s
      deadline) and only opens once Flutter is actually serving —
      avoids `ERR_CONNECTION_REFUSED` from racing the compile.
    * Cleans up the launcher job in a `finally` so Ctrl-C / `q`
      exits don't leave the job around.
- **`web/index.html`** — title and metadata `aura_app` → `Aura` so
  the Chrome tab + iOS web-app title read correctly. Description
  bumped from the Flutter starter placeholder to a real one-liner.
- **`features/shell/app_shell.dart`** — branches on
  `context.breakpoint.hasSidebar` to pick the desktop or mobile path.
  The mobile path is byte-identical to before; the inline
  `_AnimatedTabStack` moved to its own file so both shells use it.

### Verified
- `flutter analyze` clean.
- End-to-end run of `scripts/run-web-dev.ps1` confirmed: Flutter
  compiles, binds `:5174`, the polling job spawns Chrome at the
  right moment with the right profile, `main.dart.js` serves 200.
  No console errors in Flutter stdout.

## [1.30.0] - 2026-05-27

### Added
- **Self-service forgot-password screen** with a 6-digit emailed code
  (`lib/features/auth/presentation/forgot_password_screen.dart`).
  Backend now mails a code via Resend (`POST /auth/forgot-password`,
  15-minute expiry) and accepts it back at `POST /auth/reset-password` —
  no Campus Admin in the loop for student / governance users. The
  screen owns a two-stage flow:
    1. **Request** — single email field, "Send reset code" CTA, anti-
       enumeration generic copy. Submitting fires the existing
       `AuthRepository.forgotPassword(email)` call.
    2. **Verify** — six mono OTP cells over a single hidden TextField
       (digit-only, length-limited, supports paste + iOS/Android SMS
       autofill via `AutofillHints.oneTimeCode`), a new-password field,
       confirm-password field, and a "Resend code" link gated by a
       45-second mono countdown (`AppTypography.mono`) to keep users
       under the backend's 5-per-5-min rate limit. Submits to the new
       `AuthRepository.resetPasswordWithCode({email, code, newPassword})`
       and on success pops back to login with a snackbar.
  Stage transition is a cross-fade + small upward lift (`AppMotion.easeOut`,
  260 ms — under the 300 ms UI ceiling). Each OTP cell pop-scales when its
  digit appears (80 ms scale-up, 120 ms settle — asymmetric, feedback-first
  per emil-design-eng). All motion honors `MediaQuery.disableAnimations`.
  Colors and typography come exclusively from `AppTokens` and the textTheme.
- **`AuthRepository.resetPasswordWithCode({email, code, newPassword})`**
  (`lib/features/auth/data/auth_repository.dart`). Mirrors the other auth
  helpers: posts to `/auth/reset-password` with a `/api/auth/reset-password`
  fallback for deployments that mount auth under `/api`. Returns the
  backend's success message. Backend 400 (invalid / expired / used code,
  or unknown email) and 429 (rate-limited) surface as `ApiException`.

### Changed
- **Login screen "Forgot your password?" link** now pushes the new screen
  via `ForgotPasswordScreen.push(context, initialEmail: …)` instead of
  opening the old dialog (`login_screen.dart:16,205`). Behavior preserved:
  pre-fills the email currently typed in the sign-in field, no-ops while
  the sign-in form is loading.
- **Help-center article `ac-forgot-password`** rewritten to describe the
  self-service code flow (6 steps + a tip about resend / admin-only
  carve-out). Keywords gained `6-digit code`, `verification code`,
  `email code`, `resend code`. The article keeps the same `id`, parent
  category, and audience flags, so `quickHelp` chips and the public help
  view continue to work.
- **`AuthRepository.forgotPassword` doc comment** rewritten — no longer
  says "admin-approval"; references `resetPasswordWithCode` as the
  companion step.

### Removed
- **Old `ForgotPasswordDialog`** (`forgot_password_dialog.dart`) deleted.
  Its only callsite was the login screen, now migrated. The dialog
  described the admin-approval flow that the backend has moved away from
  for non-admin users; keeping it would be a footgun.



### Added
- **First-login face-registration gate for students.** Any signed-in
  student whose token meta reports `face_reference_enrolled: false`
  is now routed to a dedicated onboarding screen before they can
  reach their workspace. They cannot bounce around the app without a
  face on file — face is the primary identification for attendance
  check-in, so the alternative was a student getting deep into the
  app and only discovering at the moment they tried to check in that
  they couldn't.
- **`SessionState.needsFaceRegistration`** gate
  (`lib/core/auth/session_controller.dart`). True when the signed-in
  user is a student (`Roles.workspaceFor(roles) == Workspace.student`)
  AND `meta.faceReferenceEnrolled` is false. Privileged accounts
  (admin / school-IT / governance) are intentionally excluded —
  they register from Account → Security → Face ID and their MFA
  flow is the separate `needsPrivilegedFace` gate.
- **`SessionController.markFaceRegistered()`** — called by the new
  screen after the backend confirms enrollment. Flips the meta flag
  and re-persists, so the router's gate clears immediately and the
  student lands on home without a re-login.
- **`/register-face` route + `RegisterFaceScreen`**
  (`lib/features/auth/presentation/register_face_screen.dart`).
  Two-stage flow:
    1. **Intro** — a calm theme-aware screen with the reason ("We use
       this to mark you present at events"), three privacy bullets
       (kept on your school's server / one-time setup / re-take any
       time), and a "Continue" CTA. A low-emphasis "Sign out" link
       sits in the top-right for users who landed here by mistake.
    2. **Capture** — front-camera preview with a face-frame overlay
       and a soft top/bottom vignette so the frame and instructions
       read cleanly. Reuses the same camera plumbing as the existing
       `UpdateFaceScreen`.
  Backend errors from `POST /api/face/register` translate to
  actionable copy: 400 ("Image must contain exactly one face."), 403
  ("We couldn't confirm it was a real face — avoid printed photos or
  screens." — anti-spoof), 413 (too large), 415 (unsupported
  format), 429 (rate-limit), 503 (service starting). Unknown status
  codes still show the actual message with the HTTP code embedded
  for diagnostics.

### Changed
- **`SessionController.logout()` no longer drops the face reference
  flag** — was already the case, just noting that the
  `markFaceRegistered` companion writes through to the same
  persisted `aura_auth_meta` blob so a hot-restart picks up the
  cleared gate.
- **`resolveAppRedirect`** now consults `needsFaceRegistration`
  after `needsPrivilegedFace` and before the workspace redirect.
  `/register-face` joins the "transient" set so a student already on
  it doesn't bounce.

### Backend (no change)
- The backend has **no `must_register_face` server-side flag**. The
  gating is purely client-side off the existing
  `face_reference_enrolled` field that's already in every
  `/token` / `/auth/google` response (verified in
  `backend/app/services/auth_session.py`). `POST /api/face/register`
  is unchanged — same endpoint the existing "Update face" flow in
  Account → Security has been calling since v1.8.0.

### Verified
- `flutter analyze` clean.
- `flutter test` — 133 pass (131 prior + 2 new router tests for the
  gate). Existing `ui_quality_test` fixture student updated with
  `faceReferenceEnrolled: true` so it continues to exercise the
  workspace shell instead of the new gate.

## [1.28.3] - 2026-05-27

### Fixed
- **Sanctions screens no longer paint a red error wall for 404 / 403
  responses.** `mySanctionsProvider`, `activeClearanceDeadlineProvider`,
  and `sanctionsDashboardProvider` now swallow "no data here yet"
  status codes and return empty / null, so the screen renders the
  existing "All clear" empty state instead of "Something went wrong".
  Real failures (500, network, etc.) still surface — and they now
  include the HTTP status code in the message so the actual cause is
  diagnosable from the UI without a debugger.
- **Governance sanctions dashboard 403** is recognized explicitly and
  shown as *"You need officer access to view the sanctions
  dashboard"* instead of a generic error.

### Changed
- **`DioClient` re-reads `AppConfig.apiBaseUrl` on every request** so a
  hot-reload that changes the compile-time default flows into the next
  API call without requiring a full restart. Mirrors what the assistant
  Dio already does (added in v1.28.1). Skipped when the caller passed
  an explicit baseUrl (tests).
- **Account dashboard hierarchy reworked for consistent UI rhythm**
  across every role (student / school-IT / governance / admin all use
  this same screen).
  - Old layout mixed three visual patterns (bare "PREFERENCES" label +
    standalone `_ControlCard`s, plus `SettingsSection`s, plus a
    "Beta features" cluster) and duplicated the Profile entry (top
    card + General > Profile tile both went to the same screen).
  - New hierarchy: **Appearance** (Theme · Reduce motion · App
    appearance · Liquid glass nav) → **Account** (Edit profile ·
    Password · Sign-in & devices · Face ID) → **Notifications**
    (Inbox · Nearby check-in · Auto check-in) → **Tools** (Aura AI ·
    Gather kiosk) → **Compliance** (My sanctions, students only) →
    **Support** (Help Center) → **Workspaces** (Governance, if
    applicable) → Sign out.
  - All sections now use the same `SettingsSection` card pattern. The
    Theme / Reduce motion segmented pickers are wrapped in a new
    `_PreferenceRow` widget so they sit *inside* the Appearance card
    next to their sibling tiles, no nested cards, no visual rhythm
    break. `_ControlCard` is gone.
  - The redundant "General > Profile" tile is removed — the top
    profile summary card is the canonical Profile entry.
  - "Security" section renamed **Account** since the first row is
    "Edit profile" — that read naturally to the user; "Security"
    suggested something different.
  - Beta toggles distributed by *intent*: Liquid glass nav lives in
    Appearance (it's visual), Nearby check-in + Auto check-in live in
    Notifications (they emit prompts). No more catch-all "Beta
    features" bucket.

## [1.28.2] - 2026-05-27

### Changed
- **App appearance moved out of the Account tab and onto its own
  screen.** The inline section (preview card + two `SegmentedButton`
  rows + footnote, all stacked in one `AuraCard`) was eating
  ~360px of scroll height on the Account tab — long page, busy
  visually. The Account tab now exposes a thin one-line `SettingsTile`
  in a new "Personalization" section, with a compact summary
  ("Aura defaults" / "School logo" / "School code" / "School logo &
  code") as the subtitle. Tap → opens
  `AppAppearanceScreen` (`lib/features/shell/app_appearance_screen.dart`).
- **The dedicated screen replaces SegmentedButtons with visual
  option cards.** Each choice (Aura · School logo, Default · School
  code) renders the actual artwork at 64dp so the user picks by
  *seeing* the result, not by reading a label. Selected card gets
  an accent ring + slightly bolder label; press scale `0.97`,
  selection cross-fade `220ms` ease-out. The school-code option
  uses `AppTypography.mono` so codes like `JRMSU` read as data,
  not prose. Disabled cards (school hasn't uploaded a logo / set a
  code) dim to 55% with a one-line "School hasn't…" hint instead
  of just locking.
- **Hero preview at the top of the screen** is now bigger and
  framed with a subtle border so it reads as a card, not just a
  tinted block. `AnimatedSwitcher` fade+scale on both the brand
  mark and the wordmark when the user flips a choice — calm,
  honoring reduced-motion.

### Removed
- `lib/features/shell/app_appearance_section.dart` (rolled into the
  new screen).

## [1.28.1] - 2026-05-27

### Fixed
- **"Network error" on a real Android phone** when running
  `flutter run -d <device>` without
  `--dart-define-from-file=config/cloud.json`. The default in
  `lib/core/config/app_config.dart` was the Android-*emulator*-only
  host-loopback `http://10.0.2.2:8000`; on a real phone that hostname
  doesn't resolve and every API request failed. The default now points
  at the staging cloud backend (`http://18.142.190.113:8001`) so the
  flag is optional. The IP is already in the root README and Android
  network-security-config, so it's not a new secret. Override with
  `--dart-define=AURA_API_BASE_URL=...` for a different environment.
- **`config/cloud.json` had a stray colon** in the assistant URL
  (`":http://18.142.190.113:8500"`), which made the AI assistant
  unreachable whenever the flag *was* passed. Stripped the leading
  colon. (`config/cloud.json` is git-ignored — this only matters for
  contributors who already have the file checked out locally.)

### Changed
- **Liquid glass tab bar — icons now actually bend under the blob**
  (`lib/core/widgets/liquid_glass_nav.dart`). The old build used
  `LiquidGlass.withOwnLayer`, which wraps the shape in an internal
  `RepaintBoundary`; on Impeller the icon row sometimes got isolated
  from the BackdropFilter sample, so only the page beneath the nav
  bent. Now we manage the `LiquidGlassLayer` ourselves and wrap the
  icon row in a `RepaintBoundary` so its pixels are guaranteed to
  land in the parent compositing texture the lens samples. Lens
  settings boosted to iOS-26 territory:
  `thickness 24 → 32`, `refractiveIndex 1.4 → 1.55`,
  `chromaticAberration 4 → 6.5`, `lightIntensity 2.2 → 2.6`,
  `saturation 1.25 → 1.35`. The icon under the blob now reads as
  lensed (~6–8px displacement + visible chromatic fringe at the
  edges), matching the iOS Dynamic-Island feel.

## [1.28.0] - 2026-05-27

### Added
- **In-app branding swap (App appearance).** Account → **App appearance**
  lets the user choose whether the brand mark and app name use the Aura
  defaults or the signed-in school's logo + code. Two independent
  `SegmentedButton<bool>` controls (Brand mark · App name) plus a live
  preview card on top; defaults off until the user opts in. Premium
  layout — one focused `AuraCard`, calm hierarchy, JetBrainsMono for the
  school-code option, `AnimatedSwitcher` fade+scale between states.
  Tiles render even when the school has no logo / code uploaded yet (the
  toggle locks OFF with a friendly hint) so the user can see what's
  possible. Footnote explicitly sets expectation: the **home-screen icon
  stays as Aura** — see "Notes" below.
- **`AppBrandingPref` + `AppBrandingController`**
  (`lib/core/theme/app_branding_controller.dart`). Persists the two
  toggles **plus a snapshot of the school's metadata** (code, name, logo
  URL, primary / secondary hex, school id), refreshed every successful
  login via `captureSchoolSnapshot(meta)`. The snapshot lets the login
  screen and `MaterialApp.title` render the school brand on cold launch
  before any network round-trip, so returning users never see an
  "Aura → school" flash.
- **`SchoolLogoCache`** (`lib/core/cache/school_logo_cache.dart`).
  Disk-backed cache of the school logo bytes in
  `getApplicationSupportDirectory()/school_logo_cache/`, keyed by
  `school_id` + URL hash. After the first network fetch the logo loads
  from disk on every subsequent app launch — no re-download, no flash of
  the fallback initial. Web falls back to an in-memory map. Uses a fresh
  `Dio` instance (no auth interceptor — the logo endpoint is public).
  Cleared on logout.
- **`SchoolLogoImage`** (`lib/core/widgets/school_logo_image.dart`).
  `Image.network` replacement that consults `SchoolLogoCache` first and
  writes through on miss. Used inside `SchoolBadge` so every existing
  badge surface (account header, governance header, profile, etc.)
  inherits the disk-caching benefit transparently.
- **`AppBrandMark` + `AppNameText`** (`lib/core/widgets/app_brand_mark.dart`).
  Composite widgets that pick the Aura mark / wordmark vs. the school's
  logo / code from the `AppBrandingPref`. Drop-in for any chrome that
  previously hardcoded `AuraLogo` + `Text('Aura')`.

### Changed
- **`SchoolBadge` accepts an optional `schoolId`** and renders the logo
  via `SchoolLogoImage`. Callers in `account_tab.dart` pass the schoolId
  so cache keys are stable across logo updates.
- **`MaterialApp.title`** (`lib/app/app.dart`) is now reactive — it
  watches `appBrandingProvider` and uses `resolvedAppName()` so the
  title shown in the OS task switcher and browser tab follows the
  user's choice (Aura by default, the school's code when opted in).
- **`LoginScreen._Brand`** swaps the hardcoded `AuraLogo` chip +
  `Text('Aura')` for `AppBrandMark` + `AppNameText`. The "Aura" import
  on the login screen is now unused and removed.
- **`SessionController.completeLogin`** captures the school snapshot
  via `captureSchoolSnapshot(meta)` and fire-and-forget warms the
  `SchoolLogoCache` with `preload(url, schoolId)`. `logout()` clears the
  cache and snapshot but keeps the user's toggle choices so the same
  person logging back in picks up where they left off.

### Notes — what this deliberately does NOT change
- The **OS launcher icon** (the home-screen icon you tap to open Aura)
  stays as Aura. iOS `UIApplication.setAlternateIconName` and Android
  activity-aliases both require pre-bundled icon variants at build time
  — a school's uploaded logo can't become the OS icon at runtime. The
  settings card surfaces this as a small `info_outline` footnote so
  expectations stay correct.
- The same constraint applies to the **OS launcher label** (the text
  under the home-screen icon). The `MaterialApp.title` — which is what
  shows in the task switcher / app picker / browser tab — *is*
  reactive; the home-screen label is not.

## [1.27.2] - 2026-05-26

### Fixed (root cause for the v1.27.1 sign-in loop)
The actual bug behind "dashboard flashes then logs back out" turned out
to be a schema-vs-ORM type mismatch on the `user_sessions.token_jti`
column. Backend-side fix that takes effect after the migration runs.

- **`backend/alembic/versions/0010_user_sessions_token_jti_text.py`** —
  new migration. Runs
  `ALTER TABLE user_sessions ALTER COLUMN token_jti TYPE TEXT USING rtrim(token_jti)`.
  The `rtrim()` strips the trailing-space padding Postgres added when
  the column was CHAR(64), so rows that already exist resolve
  correctly after the migration; nobody has to re-sign-in. Unique
  constraint and the implicit unique-index are preserved across the
  type change.
- **`backend/alembic/schema.sql`** — fresh-DB bootstrap now uses
  `TEXT NOT NULL UNIQUE` instead of `CHAR(64) NOT NULL UNIQUE`, so
  a clean deploy doesn't reintroduce the same bug.

### Why the bug looked like a Flutter issue
Postgres CHAR is blank-padded. A 36-character UUID stored in CHAR(64)
becomes 36 chars + 28 trailing spaces. The ORM model declares
`token_jti = Column(Text, ...)` and SQLAlchemy binds the WHERE-clause
parameter as TEXT. Postgres's implicit cast between the padded CHAR
column and the TEXT parameter fails the equality test, so
`assert_session_valid` returns None for every freshly-issued JTI.
Login INSERT succeeds → JWT returned → very next authed request 401s
with "Session is not valid" → Flutter logs out → loop.

The v1.27.1 client-side mitigations (3-second login grace,
401-diagnostic logging, login-endpoint exclusion in `DioClient`) stay
in place — they're still defensible regardless of this specific bug
and give the next "logged out mysteriously" report a real lead to
chase.

### Deploy
Required on the cloud backend:
```
git pull origin main
docker compose -f docker-compose.prod.yml run --rm migrate
```
That single migrate run applies `0010` to the live DB. The frontend
needs no rebuild — the fix is purely server-side.

## [1.27.1] - 2026-05-26

### Fixed
- **"Sign in flashes the dashboard then returns to login" loop.** Three
  changes addressing the same root cause from different angles:
  - `DioClient.onError` no longer fires `onUnauthorized` for 401s on
    login-style endpoints (`/token`, `/login`, `/auth/google`,
    `/auth/forgot-password`). A 401 there means "wrong credentials",
    not "session invalidated" — calling `logout()` on the
    already-unauthenticated state was a no-op, but the path is now
    intentionally narrowed so future auth-flow refactors can't get this
    wrong.
  - `SessionController.handleUnauthorized` now honours a **3-second
    login grace window** after `completeLogin()`. A 401 in that window
    is ignored (likely a backend race committing the `user_sessions`
    row, or a parallel dashboard query crossing wires with token
    write). After 3s the normal logout-on-401 behaviour resumes.
  - **Diagnostic 401 logging in debug builds** — the failing
    `METHOD path → detail` is printed to console so future
    "logged out mysteriously" reports include the actual culprit
    endpoint without needing DevTools.

### Backend (deploy required for cloud)
- **`backend/app/services/auth_session.py` no longer silently swallows
  `create_user_session` exceptions.** The previous `try / except
  Exception: db.rollback()` returned a JWT to the client even when the
  `user_sessions` row failed to insert, leaving the client with a
  token whose `jti` was unknown to `assert_session_valid` — every
  authed request thereafter 401'd. Now logs the exception (with stack
  trace) and re-raises so login fails fast with a proper 500, instead
  of producing a "ghost session" that flashes the dashboard then logs
  the user out.

## [1.27.0] - 2026-05-26

### Added
- **Student-facing "My sanctions" screen.** Surfaces
  `GET /api/sanctions/students/me` data that the backend was already
  exposing but had no Flutter UI for. Account → Compliance → My
  sanctions (visible only to students). Summary chips for Pending /
  Cleared counts, an opt-in clearance-deadline banner that intensifies
  colour as the deadline approaches (`>72h` muted → `24–72h` tardy/amber
  → `<24h` absent/red), and one card per sanction record with a 4px
  coloured status bar at the top, status pill, and numbered penalty
  rows. Cleared penalties strike through + show the clearance
  timestamp.
- **`SanctionsRepository.mine()`** — `GET /api/sanctions/students/me`,
  returns the signed-in student's full sanction list.
- **`SanctionsRepository.activeClearanceDeadline()`** —
  `GET /api/sanctions/clearance-deadline`, returns the school-wide
  active deadline (null when none set).
- **`ClearanceDeadline` model** with `isUpcoming` + `hoursRemaining`
  helpers used by the banner heat-up logic.
- **`mySanctionsProvider` + `activeClearanceDeadlineProvider`** in
  `governance_providers.dart` (auto-dispose Riverpod futures).
- **API paths**: `Api.sanctionsMine`, `Api.sanctionsClearanceDeadline`.
- **`_OwnerLevelBadge` on the officer dashboard** — every event row in
  the governance Sanctions screen now shows an SSG / SG / ORG pill
  coloured from the existing brand tokens (`t.ssg` indigo, `t.sg`
  violet, `t.tardy` for ORG). Hierarchy is recognisable at a glance.
- **Diagnostic Android-build script** (`scripts/diagnose-android-build.ps1`).
  Runs `clean → pub get → analyze → build apk --debug` in sequence and
  stops on the first real Flutter error instead of the Gradle wrapper
  swallowing it.

### Changed
- **Gradle JVM heap dropped from 8G to 4G** in `android/gradle.properties`.
  The previous 8G heap left ~5G on a 16GB Windows machine for the
  Flutter Dart compiler + Defender + IDE; mid-build the OS swapped to
  disk, `flutter.bat` timed out internally, and `compileFlutterBuildDebug`
  exited 1 after ~34 minutes. 4G is plenty for our Gradle graph and
  leaves room for the rest of the toolchain.

### Design notes
- Every colour comes from `AppTokens` — nothing hardcoded.
- Status conveyed by colour + icon (per ui-ux-pro-max accessibility
  rule); pending uses `t.tardy` + hourglass, cleared uses `t.present`
  + check.
- Stagger entrance via the existing `staggered()` helper (50ms,
  ease-out), reduced motion respected by `RiseIn`.
- Mono numerals (`AppTypography.mono`) for counts so data is distinct
  from prose; matches the Help Center step style.

## [1.26.1] - 2026-05-26

### Security
Client-side hardening of every Flutter-controllable surface while the
backend still runs HTTP. Wire traffic remains cleartext to the IP-based
staging backend (only HTTPS deployment closes that hole) — everything
else tightens.

#### Network
- **Android Network Security Config**
  (`android/app/src/main/res/xml/network_security_config.xml`).
  Base policy: `cleartextTrafficPermitted="false"`. A narrow
  `<domain-config>` whitelists HTTP only for `18.142.190.113`, `10.0.2.2`,
  `127.0.0.1`, `localhost`. Any other HTTP destination is rejected at the
  network stack. `<debug-overrides>` intentionally omitted so a MITM CA
  can't be installed on a dev device by accident.
- **iOS App Transport Security** rewritten. `NSAllowsArbitraryLoads`
  removed (App Store would reject it anyway). Replaced with
  `NSExceptionDomains` scoped to `18.142.190.113` /
  `localhost` / `127.0.0.1` only; the staging exception requires
  `NSExceptionMinimumTLSVersion = TLSv1.2`.
- **`android:usesCleartextTraffic="true"`** removed from
  `AndroidManifest.xml` (superseded by the network security config).
- **Application-layer HTTPS guard** in `DioClient`
  (`_assertSecureInRelease`). Release builds compiled with a plain-HTTP
  base URL throw `StateError` before the first request fires. Debug
  builds remain permissive for development.
- **TLS certificate-pinning hook** wired as `_pinTlsCertificates` —
  currently a no-op (no HTTPS to pin against yet); flips to enforce a
  SHA-256 SPKI pin the moment the backend ships HTTPS. Code + docs
  ready.

#### Data at rest
- **Android backups disabled.** `AndroidManifest.xml` sets
  `android:allowBackup="false"`, `android:fullBackupContent="false"`,
  and `android:dataExtractionRules="@xml/data_extraction_rules"`. New
  `data_extraction_rules.xml` excludes every path from both
  `cloud-backup` and `device-transfer`, so `adb backup` and Android 12+
  flows cannot pull the EncryptedSharedPreferences blob holding the
  access token.
- Existing JWT storage already used `flutter_secure_storage` with
  `encryptedSharedPreferences: true` (Keystore-backed on Android,
  Keychain on iOS) — unchanged.

#### Reverse-engineering
- **Release-build script for Android**
  (`scripts/build-release-android.ps1`) invokes `flutter build apk` with
  `--obfuscate --split-debug-info=build/symbols/<version>
  --tree-shake-icons`. Dart symbols are replaced with short tokens in
  the APK; the symbol map ships out-of-band so a crash stack trace from
  the wild can't be symbolicated without it.
- **Release-build script for iOS** (`scripts/build-release-ios.ps1`)
  mirrors the Android flags for `flutter build ipa`.

#### Request hygiene
- `X-Requested-With: AuraApp` sent on every request so the backend can
  distinguish app traffic from browser-form-style POSTs if it ever adds
  CSRF heuristics.
- No `User-Agent` override (custom UAs are a fingerprinting hint —
  let Dart's default speak for itself).

### Fixed
- `analysis_options.yaml` excludes `third_party/**` so `flutter analyze`
  no longer reports the vendored `liquid_glass_renderer` package's
  upstream lint findings (it would otherwise show ~9k issues from the
  vendored shader code; none in app source).

### Notes — what this does NOT fix
- The base URL in `cloud.json` is embedded in the compiled binary;
  with HTTPS deployed, leaking the URL is harmless because bytes on
  the wire are encrypted. **Production HTTPS is still required.**
- TLS certificate pinning is wired but disabled until the backend
  ships HTTPS. Flip `_pinTlsCertificates` live once a real cert is
  reachable.

## [1.26.0] - 2026-05-26

### Added
- **Real Google sign-in.** "Continue with Google" on the login screen is
  now functional. New `GoogleSignInService` reads
  `AURA_GOOGLE_WEB_CLIENT_ID` via `--dart-define`, drives the
  `google_sign_in` SDK (web + native), and posts the resulting ID token to
  `POST /auth/google`. Backend errors translate to actionable copy:
  - 403 (Google login disabled) → "Google sign-in is disabled for this
    deployment. Use your school email and password instead."
  - 404 (email not registered) → "No Aura account is linked to that
    Google email. Ask your Campus Admin to register your school email
    first."
  - 401 (invalid token / unverified email) → "Google could not verify
    your account. Make sure your Google email is verified and try
    again."
  - Not configured (empty client ID) → "Sign in with Google isn't
    enabled for this app yet." Service refuses to attempt sign-in.
  - User cancels → silent (no error banner). `AppConfig` gains
    `googleAndroidClientId` + `isGoogleSignInConfigured` helper.
- **Real forgot-password flow.** Replaced "Reset it in the web app for
  now" with a `ForgotPasswordDialog` (Card-styled modal with reset-icon
  badge, email field, Cancel/Send actions, loading + error states). It
  calls `AuthRepository.forgotPassword(email)` → `POST /auth/forgot-password`
  → backend's generic admin-approval message → snackbar. Pre-fills the
  email from the login form. Validates locally for empty/no-@ before
  hitting the network.
- **Public Help Center from the login screen.** New "Need help?" link
  beside "Forgot your password?" opens
  `HelpCenterScreen(audience: HelpAudience.public)` — a trimmed
  catalogue (no privileged or dev-docs content) for unauthenticated
  visitors.
- **Role-based Help Center.** New `HelpAudience` enum
  (`public`/`student`/`campusAdmin`/`governance`/`admin`) tagged on every
  category and on individual articles. The screen derives the viewer
  from the current session — students see attendance + AI + their own
  workflow; campus admins see manage-users / imports / governance setup;
  governance officers see event-management; super-admins see everything
  plus the new Developer docs. Quick-help chips and search are filtered
  to the viewer's tier.
- **Developer docs section (admin-only).** New `developer-docs` category
  visible only to platform admins, with 8 quick-reference articles
  sourced from `docs/technical/`: architecture, tech stack, API
  reference, database/migrations, deployment/CI/CD, local dev setup,
  testing strategy, and SaaS billing + subscription state. Each article
  points to the canonical source-of-truth in the in-repo docs tree.
- **Forgot-password help article.** New `ac-forgot-password` article in
  the Account category, public-visible, with step-by-step admin-approval
  flow. Promoted to the first Quick-help chip ("Forgot password").
- **Audience-aware screen UX.** `_IntroHeader` writes a per-tier
  subtitle ("Attendance, schedule, your account…" for students,
  "Operations, developer docs, and SaaS billing…" for admins).
  `_QuickHelpRow` accepts a pre-filtered list of entries so chips never
  link to articles the viewer can't see.

### Changed
- **Help search bar polish.** Surface-light fill in idle, surface-white
  + accent ring + soft accent-tinted shadow on focus. Search icon
  scales 1.08× when focused. Clear button is now a circular soft chip
  with `AnimatedSwitcher` fade/scale entry. Cursor uses the brand
  accent. Hint copy clarified to "Search guides, FAQ, troubleshooting…"
- **Bottom nav semantics.** `_NavButton` in `glass_bottom_nav.dart` and
  `_NavItem` in `liquid_glass_nav.dart` now wrap the inner button in
  `ExcludeSemantics` and add `container: true` on the parent
  `Semantics` so `find.bySemanticsLabel('Home' | 'Schedule' | …)`
  returns the bottom-nav nodes cleanly (the prior tree merged the child
  Text's label, masking the parent label and breaking
  `ui_quality_test`).
- **Quick-help line-up.** "Forgot password" and "Install the app" join
  the chip row; "Change password" article remains in the Account
  category but is no longer a chip (the forgot-password flow is what
  users actually need pre-signin).
- **Login screen layout.** Footer links use `Wrap` (instead of `Row`)
  so the "Forgot your password? · Need help?" pair wraps to two lines
  at mobile widths instead of overflowing.

### Fixed
- **`ui_quality_test.dart` semantics handle leak.** The
  `key app controls expose accessible semantics labels` test now
  disposes the `SemanticsHandle` via `try/finally` so dispose runs
  before `_endOfTestVerifications` (addTearDown ordering left a stray
  handle and tripped the "SemanticsHandle was active at end of test"
  assertion once the body actually reached the end).

### Verified
- `flutter analyze` clean.
- `flutter test` — 120 tests pass (115 existing + 5 new audience
  filtering tests in `test/unit/help_content_test.dart`).

## [1.25.0] - 2026-05-26

### Added
- **In-app Help Center.** A new "Help Center" tile under Account → Support
  opens a dedicated, searchable help surface that mirrors the
  `docs/user-guide/` content. **9 categories, 45 articles** written as
  step-by-step actions rather than prose: Getting started, Attendance &
  events, Your account, Schedule & events, Aura AI assistant, For staff &
  officers, Troubleshooting, Security & good practice, and About Aura.
  - **Search** is the hero — a focus-animated pill that filters every
    article live, with a 120-char snippet centred on the match and a
    category-coloured badge above each result. Empty-state suggests common
    queries (login, face, password, permissions, late, reset).
  - **Quick-help chips** above the search field deep-link straight into
    the top-asked articles (cannot log in, face scan failed, change
    password, grant permissions).
  - **Accordion category cards** with an animated chevron, tinted icon
    tile, and a JetBrains Mono count pill. Tap → reveal the article list
    via `AnimatedSize`/`ClipRect`; honours `MediaQuery.disableAnimations`.
  - **Article bottom sheet** (`DraggableScrollableSheet`, initial 0.75,
    drag 0.45–0.95) shows the category chip, headline-sized title, body,
    numbered steps (mono numerals in a tinted square), and an optional
    italic tip callout with a left accent bar.
  - **Contact card** with three tap-to-copy rows — Campus Admin email, IT
    support email, full documentation URL — using `Clipboard.setData` and
    a confirmation snackbar.
  - **Footer** prints `Aura v{version} · build {build} · powered by Jose
    AI` in mono.
  - Motion follows `AppMotion`: ease-out under 300ms, press scale 0.97,
    50ms stagger entrance, reduced-motion respected. Manrope display +
    body, JetBrains Mono for numerals.
  - New files: `lib/features/help/data/help_content.dart` (pure-data
    catalogue with `HelpCategory`, `HelpArticle`, `search()`,
    `findArticle()`, `findCategory()`) and
    `lib/features/help/presentation/help_center_screen.dart`.
  - Wired into `account_tab.dart` as a new "Support" `SettingsSection`
    between Security and Workspaces — rose-coloured
    `Icons.help_outline_rounded` tile with subtitle "Guides, FAQ,
    troubleshooting & contact".
  - **12 new unit tests** in `test/unit/help_content_test.dart` lock the
    catalogue's invariants: unique category and article IDs, non-empty
    bodies and steps, case-insensitive search, keyword-list matching, and
    quick-help link integrity. analyze clean, 54 tests.

## [1.24.0] - 2026-05-23
### Added
- **Edit governance events.** The event monitor screen now has an Edit action
  (gated by `manage_events`) that opens the editor **prefilled from the event**
  and saves via `PATCH /api/events/{id}` (`EventsRepository.update`,
  `EventEditorScreen(event:)`), scoped by `governance_context`; the geofence can
  be changed or turned off. `DioClient.patch` now forwards query params.
### Notes
- Event **creation** still returns HTTP 500 from the backend (cloud **and**
  local). Traced server-side: a valid `EventCreate` payload (name + start/end,
  status defaults to `upcoming`) reaches the handler and fails during processing —
  most likely the deployed/local DB is missing newer `events` / `event_targets`
  columns because migrations didn't run (those columns live only in `schema.sql`,
  not a versioned alembic migration). The app sends a correct request; the fix is
  a backend migration/redeploy, not a client change.

## [1.23.2] - 2026-05-23
### Fixed
- **Governance Members screen had no back button** when opened from a dashboard
  quick action (e.g. after drilling into a child SG/ORG), and its title sat under
  the status bar. It's now wrapped in `AppScaffold` like the Events screen — a
  proper "Members" app bar with an automatic back button when pushed, the "Add
  officer" action moved into the app bar, and the unit name shown as a context
  line. Still works as a bottom-nav tab.

## [1.23.1] - 2026-05-23
### Changed
- **App name is now "Aura"** (was `aura_app`) — Android `android:label` + iOS
  `CFBundleDisplayName`.
- **Real launcher icon.** The Aura mark now ships as the app icon: legacy density
  buckets (mdpi–xxxhdpi) **plus an Android adaptive icon** (`mipmap-anydpi-v26`,
  the mark centred in the safe zone over a near-black background) so it renders
  correctly on Android 12+. Sourced from the clean `pwa-512` brand asset — the
  `frontend-apk` icon copies were CRLF-corrupted (an extra `0D` in the PNG header)
  and undecodable.

## [1.23.0] - 2026-05-23
### Added
- **Governance hierarchy management UI (SSG → SG → ORG).** Officers can now build
  the governance tree in-app — the backend already supported it, but Flutter had no
  view to do it.
  - **Create child units.** A permission-gated action on the governance dashboard:
    "Create college SG" (when an SSG officer holds `create_sg`) and "Create program
    ORG" (when an SG officer holds `create_org`); locked with a "Not permitted"
    tooltip otherwise. New `UnitCreatorScreen` (`unit_creator_screen.dart`) — SG mode
    shows a college picker (`govDepartmentsProvider`), ORG mode shows the college
    inherited from the parent SG plus a program picker scoped to that college
    (`Program.departmentIds`); it sends `department_id` / `program_id` per the backend
    contract and surfaces validation errors (e.g. one SG per college) inline.
    (`governance_repository.createUnit`, `createGovernanceUnit` helper)
  - **Child units + drill-in.** The dashboard lists child units (SGs under an SSG,
    ORGs under an SG); tapping one switches the workspace into it — carrying the
    management permissions the backend propagates from a *direct* parent membership
    (`manage_members` / `assign_permissions`) — with a back control to return.
  - **Empower officers down the chain.** A shared `OfficerEditor`
    (`officer_editor.dart`) replaces the SSG-only one and offers exactly the
    permissions each unit type allows (matching the backend whitelist — only SSG can
    grant `create_sg`, only SG `create_org`). Wired into the campus-admin SSG panel and
    the governance Members screen (add **and** edit officers with position +
    permissions), so an SSG can appoint SG officers and an SG can appoint ORG officers.
### Changed
- `GovernanceUnitSummary` now parses `department_id` / `program_id`; `GovUnitAccess`
  gains `fromSummary` for tap-to-switch. The Members screen's add flow moved from a
  search-only bottom sheet to the full `OfficerEditor`.

## [1.22.1] - 2026-05-23
### Added
- **Personalized greeting.** The Aura AI chat opens with an instant, client-side
  greeting — "Hi <name>! I'm Aura, powered by Jose AI …" (no model call, no waiting).
  (`chat_controller.dart`)
### Fixed
- **Don't mislabel a slow model as unreachable.** The chat now waits up to 5 min for a
  reply (`receiveTimeout` 300s) and, on a timeout, says "Aura is taking a while to
  think" — "could not reach" is now reserved for a real connection failure
  (`DioException` type check). (`assistant_service.dart`, `chat_controller.dart`)
- **Fast/Think toggle overflow.** Moved the segmented control out of the cramped app
  bar to a row above the input. (`chat_screen.dart`)
- Local model stays warm (`run_local.ps1` adds `--mlock`) so replies don't crawl after
  idle (cold ~64s → ~6s).

## [1.22.0] - 2026-05-23
### Added
- **Assistant Fast / Think toggle.** A compact segmented control in the Aura AI app
  bar switches the assistant between **Fast** (slim prompt, no tools — quick replies,
  ideal for the on-device/local model) and **Think** (full prompt + data tools +
  charts, slower). Persisted (`fast_mode_controller.dart`); sent per message
  (`fast: bool`) and honored per request by the backend. Sliding accent pill,
  ease-out, reduce-motion aware, tooltips, no emoji.
  (`chat_screen.dart` `_ModeToggle`, `assistant_service.dart`, `chat_controller.dart`)

## [1.21.0] - 2026-05-23
### Added
- **Aura AI renders charts.** The assistant chat now parses the backend's
  `visualization` SSE events (Chart.js-style spec) and draws them inline with
  `fl_chart` — bar / line / pie / doughnut, themed, with a legend
  (`features/assistant/presentation/widgets/assistant_chart.dart`,
  `ChartSpec` + `AssistantChart`). `assistant_service.dart` now captures the
  `visual` payload, `chat_controller.dart` attaches parsed charts to the reply,
  and `chat_screen.dart` renders text **and** charts in the bubble. Previously the
  client dropped these events (text-only).
### Changed
- AI assistant identity is now **"Aura, powered by Jose AI"** (assistant *backend*:
  new `assistant/assistant_identity.py` prepended to the system prompt; `.env`
  points at a local llama.cpp server serving `jose.gguf`). Setup in
  `assistant/RUN_LOCAL_JOSE.md`. No change to the Flutter app to use the local model.

## [1.20.2] - 2026-05-23
### Fixed
- **Smoother settings (and any long-list) scrolling.** `RiseIn` was replaying its
  rise/fade — and running an `Opacity` layer — every time a row mounted, which a
  `ListView` does lazily *while scrolling*. Now only the initial on-load burst
  animates (a shared reveal window opened by the list head); rows scrolled into view
  render instantly with no wrapper. (`rise_in.dart`)

## [1.20.1] - 2026-05-23
### Fixed
- **Export no longer stalls at 60% ("Adding brand logo").** The logo + student
  roster are cached per session and fetched **in parallel** with stats/attendees
  (was sequential, with the logo blocking last on an 8s timeout). Logo timeout cut
  to 3s; the "Adding branding" blocking step is gone. Repeat exports skip the fetches
  entirely → ~1–5s typical. (`export_sheet.dart`)
- **Smooth light/dark switch.** `AppTheme.light/dark` are now memoized — the
  expensive `ColorScheme.fromSeed` was being recomputed on every app rebuild (and
  both themes every time), which caused the toggle jank. (`app_theme.dart`)
- **Trimmed the crowded Beta-features descriptions** to one short line each
  (`account_tab.dart`).

## [1.20.0] - 2026-05-23
### Added
- **Background event check-in notifications + one-tap check-in.** With "Nearby
  event check-in" on, the app registers OS-level geofences (`native_geofence`) for
  the user's ongoing geofenced events; entering one fires an OS notification
  ("You're at <event> — tap to check in") **even when the app is closed**, and
  tapping it opens the **attendance / face-scan screen directly** (deep-link via
  `pendingCheckInProvider` → `student_home` listener). `geofence_background.dart`
  (background isolate callback) + `flutter_local_notifications`. The 1.19.0
  in-app prompt still works in the foreground.
- **"Beta features" settings group** — Account groups the experimental toggles
  (Liquid glass tab bar, Nearby event check-in) into an iOS-style section with BETA
  pills, plus a new **Auto check-in** toggle (BETA) that shows **"Coming soon"**
  (hands-free, no-scan check-in — placeholder, `autoCheckFullProvider`).

### Changed
- Android: core library desugaring enabled (`app/build.gradle.kts`) +
  geofence/notification permissions + native_geofence receivers/service in the
  manifest. iOS: background-location usage string + `UIBackgroundModes` in Info.plist.
- Swapped `geofence_service` → `native_geofence` (OS geofences are Android-14-safe —
  no typed foreground service needed).

### Notes
- The background trigger + notification need **on-device field testing** (walk into a
  geofenced event) and a geofenced event to exist (after the backend redeploy).
  Gated behind the off-by-default toggle. analyze clean, 42 tests, debug APK builds.

## [1.19.0] - 2026-05-23
### Added
- **Nearby event check-in (opt-in).** Account → Preferences → **"Nearby event
  check-in"** (off by default, persisted — `auto_checkin_controller.dart`). When on,
  while the student Home is open the app polls device location — but only when
  there's an ongoing **geofenced** event to match — and if the student is inside an
  event's radius it shows an in-app prompt (`NearbyEventBanner`): tap **Check in** to
  go straight to the face scan, no navigating to the event. Detection in
  `nearby_event_provider.dart` (latlong2 distance vs `ongoingEventsProvider` +
  `geolocation_service`). Nothing hardcoded — radius/centre/window come from each
  event.

### Notes
- Foreground only (works while the app is open). True always-on background geofence
  + OS push would need `flutter_local_notifications` + background-location + a
  foreground service (future work). analyze clean, 42 tests.

## [1.18.2] - 2026-05-23
### Fixed
- **Liquid nav stopped rendering (esp. on web).** Reverted the blob from the
  `liquid_glass_widgets` `GlassPanel` (which 404s its shaders on web) back to
  `liquid_glass_renderer`'s `LiquidGlass`, and removed the `kIsWeb` guard that had
  disabled the Liquid nav on web. It renders again on web **and** mobile (real
  refraction on Impeller). `main.dart` no longer needs `initialize()`/`wrap()`.

### Added
- **BETA pill** on the "Liquid glass tab bar" toggle (`account_tab.dart`,
  `_BetaPill`).

## [1.18.1] - 2026-05-23
On-device refinements (tested on an entry-level Android).

### Fixed
- **Manrope rendered super-thin.** The bundled Manrope is a **variable** font but
  its weight axis wasn't being driven, so every weight looked thin/unreadable. Now
  set `fontVariations: [FontVariation('wght', …)]` per style (`app_typography.dart`)
  so regular/medium/bold render correctly.
- **Laggy light↔dark switch** on low-end GPUs — set
  `themeAnimationDuration: Duration.zero` (`app.dart`); the animated cross-fade was
  re-rendering the glass nav every frame.
- **School logo** now shows the school letter while the network image loads instead
  of a blank disc (`school_badge.dart`, `loadingBuilder` + `gaplessPlayback`).

### Changed
- **Dropped the package `GlassBottomBar` option** (kept the custom **Liquid** nav,
  which won on device). The beta control is back to a simple **Off / Liquid** switch
  (`beta_controller.dart` is a bool again; `app_shell.dart` no longer imports
  `liquid_glass_widgets`, which is now used only by the Liquid blob).

## [1.18.0] - 2026-05-23
### Added
- **iOS 26 liquid glass via `liquid_glass_widgets`** + a **3-way nav selector**
  (Account → "Liquid glass tab bar": **Off / Liquid / Glass bar**, persisted, fully
  reversible). **Liquid** = the custom animated capsule blob, now rendered with the
  package's `GlassPanel` (shader refraction). **Glass bar** = the package's
  `GlassBottomBar` (iOS-26 bar, `standard` quality + `maskingQuality.off` so it
  stays smooth on older/entry-level GPUs) for comparison. `main.dart` calls
  `LiquidGlassWidgets.initialize()` + `wrap()`.

### Changed
- The beta nav flag (`beta_controller.dart`) is now an enum `BetaNavStyle` (was a bool).

### Fixed
- **Android build** — `camera_android_camerax` (camera-core 1.5.x) failed to compile
  ("CallbackToFutureAdapter not found"); inject `androidx.concurrent:concurrent-futures`
  into that module (`android/build.gradle.kts`).

### Notes
- The glass shaders need **Impeller (mobile/desktop)**; on **web** the package 404s
  its shaders, so web skips `initialize()`/`wrap()` and the nav falls back to the
  standard frosted nav (`kIsWeb` guards). Test the glass on a device/emulator.
- analyze clean, 42 tests, debug APK builds.

## [1.17.13] - 2026-05-23
### Changed
- **Beta nav blob: no edge overlap.** The blob clamps to the pill's inner bounds,
  so on the first/last tab its edge **compresses** instead of spilling out of the
  pill. The tap/slide zoom still pops out.

## [1.17.12] - 2026-05-23
### Changed
- **Beta nav blob: always a wide pill (even with many tabs) + bigger.** The blob
  now has a minimum width (≥ 1.6× its height) and is centered on the tab, so it
  stays a horizontal pill instead of a circle on 5-tab bars (it can overflow the
  slot/pill — that's fine). Taller resting size and a bigger tap/slide zoom (1.4×)
  that pops out of the pill.

## [1.17.11] - 2026-05-23
### Changed
- **Beta nav blob bigger at rest.** The resting blob is now larger (≈ the old
  zoomed size — taller `_blobH` 62, smaller side gap), so tap/slide zooms to an
  even bigger size.

## [1.17.10] - 2026-05-23
### Changed
- **Beta nav blob: zoom on tap too, faster, no stretch.** The blob no longer
  stretches/elongates — it just **slides + zooms**. Tapping now zooms (a quick
  pop in/out) like dragging does, and the slide is faster (240ms).

## [1.17.9] - 2026-05-23
### Changed
- **Beta nav blob: Dynamic-Island capsule that zooms while sliding.** The blob is
  rendered outside the pill clip (`Clip.none`) and **zooms bigger (1.32×) while you
  drag** — popping out of the pill like a Dynamic Island — settling back on release.
  Shape is a horizontal capsule (radius = height/2, width > height).

## [1.17.8] - 2026-05-23
### Changed
- **Beta nav blob: wider pill, pop-on-tap, clearer refraction.** The blob fills
  more of its slot (a real horizontal pill, not an oval), **pops bigger** on tap
  then settles back to a normal pill, and the frosted pill is lighter/less-blurred
  so the page shows through — making the blob's refraction (thickness 28,
  refractiveIndex 1.5, chromatic aberration 5) actually visible.

## [1.17.7] - 2026-05-23
### Changed
- **Beta nav: smooth drag, glitch-free tap.** The blob now follows the finger
  **continuously** while dragging (a free fractional position) instead of snapping
  tab-to-tab, and settles to the nearest tab on release. Tapping animates the blob
  from its real current position with the elastic stretch, so it no longer glitches.
  The active icon colour tracks the blob during the drag.

## [1.17.6] - 2026-05-23
### Changed
- **Beta nav blob is now a proper pill.** Its corner radius equals half its height
  (fully rounded ends) and it's a bit shorter with a smaller side gap, so it reads
  as a horizontal capsule instead of a rounded square / vertical oval.

## [1.17.5] - 2026-05-23
### Changed
- **Beta liquid glass nav — elastic blob + centered icons.** The blob now
  **stretches** as it slides between tabs (restores the liquid feel on both tap and
  drag) via a stateful elastic animation — the leading edge leads and the trailing
  edge lags (two eased curves). Reshaped to a content-fitting rounded blob (was a
  tall oval) and the icons + labels are now properly centered in each slot.

## [1.17.4] - 2026-05-23
### Changed
- **Beta liquid glass nav — bigger pill, drag-to-slide, and real refraction.** The
  pill is taller (82) with roomier icons/labels; the blob now slides via **tap or
  drag** (`onHorizontalDragUpdate`). The frosted pill tint is now **translucent
  dark** so the page shows through it — giving the `liquid_glass_renderer` blob
  actual light to **refract** (refractiveIndex 1.45 + thickness 24 + chromatic
  aberration). The refraction is on the **blob only**; the back pill stays frosted.

## [1.17.3] - 2026-05-23
### Changed
- **Beta liquid glass nav — visual rework** to match the iOS reference. Replaced
  the package-styled bar with a custom `core/widgets/liquid_glass_nav.dart`: a
  neutral **frosted, tinted pill** (pure UI — no backend brand colour, same size
  and pill shape as the standard nav) holding a **colourless `liquid_glass_renderer`
  blob** that slides to the active tab. Only the **active icon + label** takes the
  university **primary** colour (animated). `liquid_bottom_nav_bar` is no longer
  used by the shell.

## [1.17.2] - 2026-05-23
### Changed
- **Smoother tab switching (all roles).** The view transition is now a
  state-preserving **cross-fade** — the outgoing view fades out as the incoming
  fades in, with no slide and no blank flash (was an abrupt slide-in that left a
  gap). `_AnimatedTabStack` in `app_shell.dart`.
- **Beta liquid nav: the blob now slides on tap.** Added an explicit snap
  `animationDuration` (320ms) + `easeOutCubic` curve so tapping a tab glides the
  liquid blob to it instead of teleporting.

## [1.17.1] - 2026-05-23
### Changed
- **Beta liquid glass tab bar is now real liquid glass.** The beta nav is wrapped
  in a `liquid_glass_renderer` `LiquidGlass` pill (transparent
  `liquid_bottom_nav_bar` container) for genuine refraction with **chromatic
  aberration** over the page behind it, plus light/thickness tuned for the native
  iOS look. The shape is now a **pill** (was a rounded square — the radius was
  smaller than half the bar height). Impeller-only; stays behind the beta toggle.

## [1.17.0] - 2026-05-23
Beta: opt-in iOS liquid glass tab bar (all roles).

### Added
- **Liquid glass tab bar (Beta)** — Account → Preferences → "Liquid glass tab bar".
  When on, every workspace's bottom navigation becomes an iOS-style liquid bar
  (`liquid_bottom_nav_bar`: liquid blob animation + glass blur, themed with the
  brand accent); off keeps the standard nav. The choice is persisted
  (`core/theme/beta_controller.dart`) and the toggle warns it's beta and may lag on
  low-end devices.

### Notes
- analyze clean, 42 tests.

## [1.16.2] - 2026-05-23
Event creation fixed; PDF font + Events-screen crash fixed; report names + progress.

### Fixed
- **Creating an event failed** (looked like an "internal server error"). The
  **deployed backend requires `location`**, but the form only sent it when
  non-empty — confirmed live: `422 {"loc":["body","location"],"msg":"Field
  required"}`. The venue field is now required and always sent.
- **Governance "Events" showed a red Flutter error** when opened from the
  dashboard quick action — the screen was a bare `Column` with no `Material`
  ancestor, so its `ChoiceChip`/`TextField` threw "No Material widget found".
  Wrapped in `AppScaffold` (works as a tab and when pushed; the create "+" moved
  to the app bar).
- **PDF export failed on dashes** — the built-in Helvetica font can't draw
  "–"/"—" (U+2013/U+2014). All report text is now sanitized to Latin-1
  (typographic glyphs → ASCII).

### Added
- **Report attendee columns: Name | Student ID | Time in | Time out | Status** —
  names/numbers resolved via `GET /api/governance/students`.
- **Real step progress bar** on export (Loading attendance → Matching names →
  Branding → Building), not a fixed-duration dummy.

### Notes
- analyze clean, 42 tests.

## [1.16.1] - 2026-05-23
### Fixed
- **Report export (PDF / Excel / CSV) hung and lagged the app.** Byte generation
  ran on the UI isolate — the heavy PDF/XLSX building froze the app, and a slow
  logo fetch could spin forever. Generation now runs in a **background isolate**
  (`compute`) and the logo fetch has an 8s timeout, so the sheet stays responsive
  and the share dialog opens promptly.

## [1.16.0] - 2026-05-23
Governance event creation + a map view with range on events.

### Added
- **Governance officers can create events.** The governance Events screen (and the
  dashboard quick action) now has a **New event** button — shown when the unit
  grants `manage_events` — opening the event editor scoped to the unit via
  `POST /api/events?governance_context=SSG|SG|ORG` (the backend auto-scopes
  department/program). The new event appears under the unit immediately.
- **Map view with range** on events — a read-only `EventLocationMap`
  (`core/widgets/event_location_map.dart`) showing the geofence centre + radius
  circle, on the **event detail** (student) and **governance monitor** screens.

### Notes
- analyze clean, 42 tests.

## [1.15.0] - 2026-05-23
University logo now displays everywhere; secondary brand colour applied.

### Fixed
- **University logo never displayed.** The backend returns `logo_url` as a
  **relative** path (`{public_prefix}/{file}`); the app rendered it raw and every
  check gated on `startsWith('http')`, so it was silently dropped. Added
  `core/network/media_url.dart` (`mediaUrl()`) to resolve relative paths against the
  backend root, used wherever the logo is shown (account, settings, export, …).

### Added
- **`SchoolBadge`** (`core/widgets/school_badge.dart`) — the school logo inside a
  primary→secondary **gradient ring** (so the **secondary brand colour is now
  used**), with an initial fallback. Placed next to the greeting/name on the
  **student** and **school-IT** home, in the **governance** header, the **account**
  profile card, and the **profile** screen (with the university name).

### Notes
- analyze clean, 42 tests.

## [1.14.0] - 2026-05-23
Campus-admin Student Government panel; blank University settings fixed.

### Fixed
- **University settings was a blank screen** — a full-width `AuraButton` (the
  "Choose" logo button) sat directly inside a `Row` (unbounded width), throwing an
  infinite-width layout assertion that failed the whole body subtree. Constrained
  it. (Not a backend or data problem — confirmed from the render exception.)

### Added
- **Campus-admin "Student Government" panel** (School-IT home → Student Government):
  auto-creates the school **SSG** (`GET /api/governance/ssg/setup`) and lets the
  campus admin **add / edit / remove the President & officers** — search a student,
  set the position title, and grant per-officer permissions. New repository methods
  `ssgSetup()` + `updateMember()`.

### Notes
- analyze clean, 42 tests.

## [1.13.1] - 2026-05-23
### Fixed
- **Assigning an "Unassigned" student now works.** Users-by-College was listing
  non-student accounts (which have no student profile, hence no "Assign to a
  college" action) under "Unassigned". The view is now restricted to actual
  students, so every entry under "Unassigned" is assignable (open it → "Assign to
  a college").

## [1.13.0] - 2026-05-23
Critical pagination fix, governance→student switch, localization.

### Fixed
- **Users list pagination.** The backend paginates by **`page`** and ignores
  `skip`; the previous skip-loop re-fetched page 1 repeatedly → **duplicate
  accounts, very slow / endless skeleton loading, "--" counts**, and accounts past
  the first page never loaded (the "already exists but can't find it" account —
  e.g. `aclaogloryzann30@gmail.com`, id 2232, COE — sat on page 2). Now walks
  `page=1..total_pages` with de-dup.
- **Governance "Switch to student"** now actually opens the student view (was a
  no-op `maybePop`).

### Added
- **System language** support — `flutter_localizations` delegates + supported
  locales (en, fil); the app follows the device language for Material widgets and
  date/number formatting.

### Notes
- analyze clean, 42 tests.

## [1.12.0] - 2026-05-23
Fixes: full user list, schedule filters, college management.

### Fixed
- **Users by college now loads ALL users** (paginated). A newly-created account on
  a large school (e.g. JRMSU) sat beyond the first page (id ASC), so it was
  invisible to the list + search even though it existed — the "already exists but
  can't find it" bug.
- **University settings no longer shows a blank screen** — it renders from the
  in-token branding instantly (name/code/logo/colours); the network call only
  refreshes.

### Added
- **Schedule filter pills** (All / Today / Upcoming / Past) in every calendar.
- **Rename / Delete a college** from each college card (⋯ menu); unassigned
  students remain assignable to a college from the student detail.

### Notes
- analyze clean, 42 tests.

## [1.11.0] - 2026-05-23
Student analytics polish.

### Added
- **Insights** redesigned: attendance **arc gauge**, a **Now & next** section
  (ongoing + upcoming events), present/late/absent/excused/incomplete breakdown,
  monthly trend, an **event-type pie**, and recent events with per-event status.

### Notes
- Completes the governance dashboard / calendars / analytics plan
  (1.9.0 → 1.11.0). analyze clean, 42 tests.

## [1.10.0] - 2026-05-23
Calendars with search for all three workspaces.

### Added
- **Calendars** (`core/widgets/event_calendar.dart`, table_calendar) with
  status-colored day markers, a selected-day list, and **search**:
  - Student "Schedule" — their events; tap → detail + status.
  - School-IT "Schedule" — all school events (upcoming/ongoing/done) + new event.
  - Governance "Events" — scoped to the active unit (its college/org).

### Notes
- analyze clean, 42 tests.

## [1.9.0] - 2026-05-23
Governance event-management dashboard, report export, and a map event picker.

### Added
- **Governance dashboard** rebuilt: shows the officer's **position**, a compliance
  **arc gauge**, real metric chips, **permission-aware quick actions** (greyed +
  locked when not permitted), and a **Manage events** list with a **live
  attendance progress bar** for ongoing events (15s polling).
- **Export an event report** to **PDF / CSV / XLSX** (university logo + name,
  college, date/time, schedule, attendance summary + attendee list) —
  `features/reports/event_report_service.dart` + `ExportSheet`.
- **Event-creation form** redesigned (sectioned) with an interactive **map**
  (flutter_map / OpenStreetMap) to set the geofence centre + a **radius slider**.
- Campus-admin **profile avatar = school logo**.
- **Splash** always plays its bloom now (minimum-display gate).
- Shared `core/widgets/arc_gauge.dart` (semicircle % gauge).

### Notes
- New deps: table_calendar, pdf, printing, excel, share_plus, path_provider,
  flutter_map, latlong2. analyze clean, 42 tests.

## [1.8.0] - 2026-05-23
Face re-enroll from the camera.

### Added
- **Update face** (Account → Security → Face ID): capture a new photo with the
  front camera to set your face reference. Role-routed — students hit
  `/api/face/register`, admin/School-IT hit `/auth/security/face-reference`. The
  backend enforces liveness + a single face; failures (e.g. "Face not found.")
  show inline. Reuses the attendance camera pipeline; no new dependencies.

## [1.7.0] - 2026-05-23
School-IT customization, college management, and bundled fonts.

### Added
- **Bundled Manrope + JetBrains Mono** as asset fonts — correct typography in
  release/offline builds (no runtime font fetch).
- **University settings** redesigned (iOS Display style): a live brand **preview**,
  **logo upload** (web + APK), **primary & secondary** brand colours, name/code,
  and a compact event-policy row. Saving applies the primary colour to the theme
  live.
- **College management**: add a college, rename/delete a college (delete warns +
  surfaces the backend error when students are still assigned).
- **Assign / reassign a student to a college** from the student detail screen.
- Add students **manually** per college (alongside bulk import).
- **Governor → student** quick switch in the Governance header.

### Notes
- The duplicate-email check is global across schools on the backend, so the
  add-student form now surfaces the backend's exact reason (e.g. "registered in
  another school").
- 42 tests; analyze clean.

## [1.6.0] - 2026-05-22
Animated splash, Apple-style navbar, and a Security section.

### Added
- **Security** settings (Account → Security): **Edit profile** (name/email →
  `PATCH /api/users/{id}`), **Change password** (real form →
  `/auth/change-password`), **Sign-in & devices** (active sessions + revoke
  others + recent sign-ins via `/auth/security/*`), and a **Face ID** status tile.
- **Animated bloom splash** — a native recreation of `aura_animated_bloom.svg`
  (green aura reveal + white-logo elastic bloom); honours Reduce motion. (The SVG
  itself can't render in Flutter — CSS/SMIL + chroma filters — so it's rebuilt.)

### Changed
- **Bottom navigation** redesigned: switching tabs now **slides + fades** in the
  swipe direction (state-preserving, no overlap); the tap **ripple is removed**
  (Pressable scale); the active item gets a soft accent pill + label.

### Notes
- 42 tests; analyze clean. Face re-enrollment is admin/kiosk-only (the backend
  face endpoints are privileged), so the tile shows status + guidance.

## [1.5.0] - 2026-05-22
School IT branding customization.

### Added
- School IT can customize their school in **School settings**: edit the school
  **name** + **code** and pick a **primary brand colour** (swatch picker). Saving
  posts to `PUT /api/school/update` and applies the colour to the app theme
  **live** (`theme_controller`), so the accent reflects the school brand. The
  school **logo** is shown when set.

## [1.4.0] - 2026-05-22
Apple-style polish: iOS settings, staggered motion, per-school AI toggle.

### Added
- **Staggered "rise-up" entrance** on every dashboard + the Account screen (cards
  fade + rise in, sequenced) — plays only when Reduce motion is off
  (`RiseIn` / `staggered` in `core/widgets/rise_in.dart`).
- **iOS-style Account / Settings**: grouped inset sections with soft colored icon
  tiles (`SettingsTile` / `SettingsSection`), a tappable profile row, and
  preference cards.
- **Per-school Aura AI toggle** in the admin school detail — turn the AI assistant
  on/off for a school. (Saved on-device for now; platform-wide enforcement needs a
  backend `ai_enabled` field, flagged in code.)

### Notes
- 42 tests; analyze clean.

## [1.3.1] - 2026-05-22
### Fixed
- Tab views no longer overlap when switching between workspace tabs — the
  animated tab stack now `Offstage`s inactive tabs (only the active one is laid
  out + painted; state is still preserved). They were painting through before.

## [1.3.0] - 2026-05-22
Dashboard redesign across all workspaces.

### Added
- **Student / School IT / Governance home screens redesigned** to match the Admin
  dashboard — hero ring + metric cards with icon chips + a real chart:
  - Student: attendance ring, present/absence chips, monthly-attendance bar chart,
    and the next upcoming event (was a Phase-0 placeholder — now real data).
  - School IT: students ring (face-enrolled %), department/program chips, and a
    students-by-department bar chart.
  - Governance: compliance ring + pending sanctions (sanctions dashboard),
    students/published chips, an absences-by-event bar chart, recent announcements.
- Shared `core/widgets/dashboard.dart` (HeroRingCard, MetricChipCard,
  DashboardActionRow, DashboardBarChart) so every workspace home stays consistent.

## [1.2.0] - 2026-05-22
Admin dashboard redesign + Apple-style tab transitions.

### Added
- **Admin Overview redesigned** as a chart-led dashboard: an active-schools hero
  ring, metric cards with icon chips, and a **Subscriptions** bar chart (fl_chart)
  — airy and readable instead of plain stat boxes.
- App-wide **cross-fade + lift** transition when switching bottom-nav tabs
  (state-preserving, Apple-style fade-through); honours Reduce motion.
- Status-colored icon chips on school cards.

### Changed
- Bottom navigation sits a little lower (smaller bottom inset).

## [1.1.0] - 2026-05-22
Admin parity, the real Aura logo + web preview, and Apple-style motion.

### Added
- **Admin school detail** opens reliably (renders from the loaded summary — the
  deployed backend has no per-school detail GET) with a **subscription status**
  control (active/trial/suspended) and a **Plan & limits** editor
  (`/api/subscription/me`) — the per-school capability lever.
- **Admin Logs** tab: audit logs (`/api/audit-logs`, search + status filters) and
  notification logs (`/api/notifications/logs`).
- **Reduce motion** setting (System / On / Off) in Account → Appearance; app-wide
  Apple-style page transitions (Cupertino) that collapse when motion is reduced.
  Reduce-motion also gates the stat ring + bottom-nav indicator.
- Official **Aura logo** (from the web app) on splash + login via `AuraLogo`;
  `device_preview` phone-frame preview; web platform enabled (`--web-port=5173`).

### Changed
- Semantic colors: Sign out, attendance **sign-out**, and suspended/deactivated
  states are **red**; attendance **check-in** is **green**.
- Splash + login brand mark switched from the text "A" to the real Aura logo.
- `intl` bumped to `^0.20.2`.

### Fixed
- Tapping a school in Admin no longer shows "Something went wrong" (it called a
  detail route absent from the deployed backend).

### Tests
- Audit/notification log + subscription parsing tests. 42 total; analyze clean.

## [1.0.0] - 2026-05-22
Phase 5 — cross-cutting polish. First complete release: all four role workspaces.

### Added
- Offline read-cache: a Dio interceptor caches successful GETs and serves them on
  network failure (cleared on logout) — schedules, dashboards, and lists keep
  working offline.
- CI: GitHub Actions workflow (`aura-app-ci.yml`) running analyze + test, then a
  debug APK build, on changes to `frontend-app/`.
- Accessibility: tooltips on icon-only actions (new event/school/member/
  announcement, password visibility) atop existing Semantics, reduced-motion, and
  text-scaling support.
- `RELEASE.md`: Android/iOS signing, store-metadata checklist, and credential-gated
  follow-ups (FCM push, deep links).

### Notes
- 38 tests; `flutter analyze` clean. Push notifications, deep links, app icon, and
  store signing are documented in `RELEASE.md` (need the team's Firebase project /
  keystore / store accounts).

## [0.5.0] - 2026-05-22
Phase 4 — Platform Admin workspace. All four role workspaces are now functional.

### Added
- Overview: platform metrics (schools / campus admins / pending) + pending
  password-reset approvals (`/auth/password-reset-requests` + approve at root).
- Schools: list (`/api/school/admin/list`), detail with activate/deactivate
  (`PATCH /api/school/admin/{id}/status`), and create-school + campus-admin in one
  step (`POST /api/school/admin/create-school-it`, multipart) showing the generated
  temporary password.
- Accounts: campus-admin list (`/api/school/admin/school-it-accounts`) with
  activate/deactivate and password reset.
- Admin models/repository. Retired the placeholder tabs — every workspace now
  renders real screens.

### Tests
- Admin model-parsing tests. 38 total; analyze clean.

## [0.4.0] - 2026-05-22
Phase 3 — School IT (campus admin) workspace.

### Added
- Dashboard with school metrics (students / departments / programs) and management
  entry points.
- Users tab: students list with live search, mapped to department/program names,
  plus a student detail screen.
- Schedule tab: events list, an event editor (name, location, start/end pickers,
  optional device-location geofence) creating via `POST /api/events/`, and the
  live attendance monitor.
- Bulk import: pick a CSV/XLSX, preview validation, commit, and poll job status
  with a progress bar and per-row errors (`file_picker` added).
- School settings: school info + editable default event policy (`/api/school/me`,
  `PUT /api/school/update`).
- School IT models/repository; events repo gains create/delete. Verified School IT
  routes live under `/api`.

### Tests
- School IT model-parsing tests. 34 total; analyze clean.

## [0.3.0] - 2026-05-22
Phase 2 — Governance (student government) workspace.

### Added
- Governance access discovery (`/governance/access/me`) with a workspace entry in
  Account (shown only when the user belongs to a unit) and an SSG>SG>ORG
  active-unit switcher.
- Dashboard overview (`/governance/units/{id}/dashboard-overview`): student +
  published-announcement counts, recent announcements, quick actions.
- Members tab: officers of the active unit, with add (student search → assign)
  and remove.
- Events tab: events in the unit's governance context, with a live attendance
  monitor (stats ring + status breakdown + attendee list).
- Announcements: list + create.
- Sanctions: dashboard (`/sanctions/dashboard`), per-event sanctioned students,
  and compliance approval.
- Governance + sanctions models/repositories; events repo gains a
  `governance_context` filter. Verified governance/sanctions routes live under `/api`.

### Tests
- Governance + sanctions parsing tests. 31 total; analyze clean.

## [0.2.1] - 2026-05-22
Phase 1 — Student workspace complete.

### Added
- AI assistant chat: streamed SSE replies from `/assistant/stream` with live
  typing, conversation continuity, and user context.
- Gather kiosk: nearby-event discovery (`/public-attendance/events/nearby`) plus an
  auto-scanning multi-face check-in loop (`/multi-face-scan`) with a recorded count
  and per-person outcomes; recorded students go on a cooldown set.
- Account → Manage links to Aura AI and Gather (kiosk).

### Security
- Backend + assistant URLs moved to a git-ignored `config/cloud.json` (loaded with
  `--dart-define-from-file`); no endpoints are hardcoded in source. Dev-only
  cleartext HTTP enabled (Android `usesCleartextTraffic`, iOS ATS) for the IP-based
  staging server — switch to HTTPS for production.

### Fixed
- API path prefix set to `/api` (verified against the staging server: `/api/events/`
  responds, `/api/v1/...` 404s); overridable via `--dart-define=AURA_API_PREFIX`.

## [0.2.0] - 2026-05-22
Phase 1 — Student workspace (core surfaces).

### Added
- Student data models (event, attendance, profile, notifications, analytics) with
  lenient JSON parsing, plus typed repositories over the cloud API.
- Schedule (grouped by day) and Event Detail with live attendance-window status.
- Face-scan attendance: front-camera capture + geolocation posted to
  `/face/face-scan-with-recognition`, with a result sheet. Native camera/location
  permissions added for Android + iOS.
- Quick "Scan" tab listing ongoing events for one-tap check-in.
- Insights: attendance-rate ring, status breakdown, monthly trend chart
  (fl_chart), and recent history.
- Profile and Notifications screens; Account tab links to both.
- `camera` + `geolocator` plugins and a geolocation service wrapper.

### Tests
- Added model-parsing tests (event/attendance/report/profile). 27 total; analyze clean.

## [0.1.0] - 2026-05-22
Phase 0 — foundation.

### Added
- Flutter Android + iOS client `aura_app` (appId `com.aura.aura_app`).
- Design system: light/dark theme + per-school brand primary, Manrope +
  JetBrains Mono type scale, spacing/radii/elevation, motion tokens (emil),
  YIQ contrast helper. Documented in `DESIGN_SYSTEM.md`.
- Component library: `AuraButton`, `AuraCard`, `AuraPill`/`StatusChip`,
  `AuraTextField`, `GlassBottomNav`, `StatRing`, `AppScaffold`, `SectionHeader`,
  `AuraSkeleton`, `Pressable`.
- Networking: Dio client with bearer interceptor, base-URL normalization,
  FastAPI error mapping (`ApiException`), paginated envelope (`Paginated`).
- Auth: secure token store, token-payload/role parsing, session controller with
  401 handling; email/password login via `POST /token` (fallback `/api/token`).
- Role-based router (go_router) with auth / password-change / privileged-face
  gates routing to Student / School IT / Admin / Governance shells.
- Workspace shells with glass bottom nav and home previews; shared Account tab
  (theme switch + sign out).
- Tests (23): roles, base-URL, token meta, pagination, contrast, `AuraButton`.

### Notes
- Reuses the existing cloud FastAPI backend unchanged; base URLs via
  `--dart-define`. No codegen (hand-written Riverpod + plain models).
- `flutter analyze` clean; `flutter test` green.

[Unreleased]: #unreleased
[1.29.0]: #1290---2026-05-27
[1.28.3]: #1283---2026-05-27
[1.28.2]: #1282---2026-05-27
[1.28.1]: #1281---2026-05-27
[1.28.0]: #1280---2026-05-27
[1.20.1]: #1201---2026-05-23
[1.20.0]: #1200---2026-05-23
[1.19.0]: #1190---2026-05-23
[1.18.2]: #1182---2026-05-23
[1.18.1]: #1181---2026-05-23
[1.18.0]: #1180---2026-05-23
[1.17.13]: #11713---2026-05-23
[1.17.12]: #11712---2026-05-23
[1.17.11]: #11711---2026-05-23
[1.17.10]: #11710---2026-05-23
[1.17.9]: #1179---2026-05-23
[1.17.8]: #1178---2026-05-23
[1.17.7]: #1177---2026-05-23
[1.17.6]: #1176---2026-05-23
[1.17.5]: #1175---2026-05-23
[1.17.4]: #1174---2026-05-23
[1.17.3]: #1173---2026-05-23
[1.17.2]: #1172---2026-05-23
[1.17.1]: #1171---2026-05-23
[1.17.0]: #1170---2026-05-23
[1.16.2]: #1162---2026-05-23
[1.16.1]: #1161---2026-05-23
[1.16.0]: #1160---2026-05-23
[1.15.0]: #1150---2026-05-23
[1.14.0]: #1140---2026-05-23
[1.13.1]: #1131---2026-05-23
[1.13.0]: #1130---2026-05-23
[1.12.0]: #1120---2026-05-23
[1.11.0]: #1110---2026-05-23
[1.10.0]: #1100---2026-05-23
[1.9.0]: #190---2026-05-23
[1.8.0]: #180---2026-05-23
[1.7.0]: #170---2026-05-23
[1.6.0]: #160---2026-05-22
[1.5.0]: #150---2026-05-22
[1.4.0]: #140---2026-05-22
[1.3.1]: #131---2026-05-22
[1.3.0]: #130---2026-05-22
[1.2.0]: #120---2026-05-22
[1.1.0]: #110---2026-05-22
[1.0.0]: #100---2026-05-22
[0.5.0]: #050---2026-05-22
[0.4.0]: #040---2026-05-22
[0.3.0]: #030---2026-05-22
[0.2.1]: #021---2026-05-22
[0.2.0]: #020---2026-05-22
[0.1.0]: #010---2026-05-22
