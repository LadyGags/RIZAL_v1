// Mockup screenshot capture for designer hand-off.
//
// Renders four flagship surfaces of the app at iPad-portrait size
// (1024 x 1366 logical, DPR 1.0) — Login and Dashboard, each in
// light and dark themes — and writes the captured frames as PNGs
// into the operator's Windows Downloads folder.
//
// The DPR is intentionally 1.0 so the output file dimensions match
// the logical viewport one-to-one (1024 x 1366 pixels), which is
// what designers expect from a tablet mock-up.
//
// Limitations called out explicitly:
//   - Custom fonts (Manrope, JetBrainsMono) are NOT loaded; the
//     test framework substitutes its built-in fallback. Layout is
//     1:1 but the typeface differs from a real device.
//   - Network images (school logo, OpenStreetMap tiles) do not
//     resolve in widget tests.
//   - Animations are pumped past, but anything that runs past the
//     pumpAndSettle bound (slow Lottie, infinite spinners) will be
//     captured mid-animation.
//
// Run:
//   flutter test test/screenshots/capture_screenshots.dart
//
// Output files (overwritten each run):
//   C:\Users\DjMhel\Downloads\aura-login-light-tablet.png
//   C:\Users\DjMhel\Downloads\aura-login-dark-tablet.png
//   C:\Users\DjMhel\Downloads\aura-dashboard-light-tablet.png
//   C:\Users\DjMhel\Downloads\aura-dashboard-dark-tablet.png
//
// Mock account for the dashboard:
//   gabrielryanpduterte@gmail.com — Gabriel Duterte (student fixture)
//   The dashboard shows the user's name in the sidebar header and
//   avatar. No real backend call happens; the session is overridden.

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

import 'package:aura_app/app/app.dart';
import 'package:aura_app/app/splash_gate.dart';
import 'package:aura_app/core/auth/auth_meta.dart';
import 'package:aura_app/core/auth/session_controller.dart';
import 'package:aura_app/core/theme/beta_controller.dart';
import 'package:aura_app/core/theme/theme_controller.dart';
import 'package:aura_app/features/events/application/events_providers.dart';
import 'package:aura_app/features/events/application/geofence_background.dart';
import 'package:aura_app/features/governance/application/governance_providers.dart';
import 'package:aura_app/features/student/application/student_providers.dart';
import 'package:aura_app/shared/models/analytics.dart';
import 'package:aura_app/shared/models/event.dart';
import 'package:aura_app/shared/models/governance.dart';
import 'package:aura_app/shared/models/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _downloadsDir = r'C:\Users\DjMhel\Downloads';

// iPad landscape — the wider format that designers usually want for
// dashboard hand-offs because it shows the sidebar AND the full content
// canvas in one shot. Same logical pixel count as portrait, just
// rotated. At 1366 dp the sidebar still sits at `Breakpoint.expanded`.
const Size _ipadLandscape = Size(1366, 1024);

// ─────────────────────────────────────────────────────────────────────
// Overrides
// ─────────────────────────────────────────────────────────────────────

class _ReadySplashGate extends SplashGate {
  @override
  bool build() => true;
}

class _FixedBetaNavController extends BetaNavController {
  @override
  bool build() => false;
}

class _TestSessionController extends SessionController {
  _TestSessionController(this.initial);
  final SessionState initial;
  @override
  SessionState build() => initial;
}

class _FixedThemeController extends ThemeController {
  _FixedThemeController(this.mode);
  final ThemeMode mode;
  @override
  ThemeState build() => ThemeState(mode: mode);
}

const _signedOutSession = SessionState(status: SessionStatus.unauthenticated);

const _gabrielSession = SessionState(
  status: SessionStatus.authenticated,
  meta: AuthMeta(
    email: 'gabrielryanpduterte@gmail.com',
    roles: ['student'],
    firstName: 'Gabriel',
    lastName: 'Duterte',
    schoolName: 'JRMSU',
    faceReferenceEnrolled: true,
  ),
);

final _sampleEvent = AppEvent(
  id: 1,
  name: 'University Orientation',
  location: 'Main Auditorium',
  status: 'upcoming',
  startDatetime: DateTime.now().add(const Duration(days: 3)),
  endDatetime: DateTime.now().add(const Duration(days: 3, hours: 2)),
);

const _sampleProfile = UserProfile(
  id: 1,
  email: 'gabrielryanpduterte@gmail.com',
  firstName: 'Gabriel',
  lastName: 'Duterte',
  roles: ['student'],
  studentProfile: StudentProfile(id: 1, studentNumber: 'JRMSU-2024-0001'),
);

const _sampleReport = StudentReport(
  summary: StudentSummary(
    studentName: 'Gabriel Duterte',
    totalEvents: 12,
    attendedEvents: 10,
    lateEvents: 1,
    absentEvents: 1,
    attendanceRate: 83,
  ),
  monthly: {
    '2026-01': {'present': 3},
    '2026-02': {'present': 4},
    '2026-03': {'present': 3},
  },
);

List<Override> _overrides({
  required SessionState session,
  required ThemeMode mode,
}) {
  return [
    sessionControllerProvider
        .overrideWith(() => _TestSessionController(session)),
    splashGateProvider.overrideWith(() => _ReadySplashGate()),
    betaNavProvider.overrideWith(() => _FixedBetaNavController()),
    themeControllerProvider.overrideWith(() => _FixedThemeController(mode)),
    geofenceBackgroundProvider.overrideWith((ref) {}),
    governanceAccessProvider
        .overrideWith((ref) async => const GovernanceAccess()),
    myProfileProvider.overrideWith((ref) async => _sampleProfile),
    studentReportProvider.overrideWith((ref) async => _sampleReport),
    scheduleEventsProvider.overrideWith((ref) async => [_sampleEvent]),
    ongoingEventsProvider.overrideWith((ref) async => const <AppEvent>[]),
  ];
}

// ─────────────────────────────────────────────────────────────────────
// Capture helpers
// ─────────────────────────────────────────────────────────────────────

const _screenshotKey = ValueKey<String>('aura-screenshot-root');

Future<void> _pumpAndCapture(
  WidgetTester tester, {
  required SessionState session,
  required ThemeMode mode,
  required String fileName,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _ipadLandscape;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    RepaintBoundary(
      key: _screenshotKey,
      child: ProviderScope(
        key: UniqueKey(),
        overrides: _overrides(session: session, mode: mode),
        child: const AuraApp(),
      ),
    ),
  );

  // Settle initial layout and any provider futures + router redirect.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }

  final path = '$_downloadsDir\\$fileName';

  // `boundary.toImage()` only writes real pixels when called inside
  // `tester.runAsync` — outside the async zone the widget-test
  // framework uses a fake rasterizer and the resulting Image has zero
  // bytes when toByteData runs. Doing the encode + file write inside
  // the same zone keeps us on the real Skia pipeline end-to-end.
  await tester.runAsync(() async {
    try {
      final boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(_screenshotKey));
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        // ignore: avoid_print
        print('SCREENSHOT FAILED ($fileName): toByteData returned null');
        return;
      }
      final pngBytes = byteData.buffer.asUint8List();
      await File(path).writeAsBytes(pngBytes);
      // ignore: avoid_print
      print('SCREENSHOT WROTE: $path  (${pngBytes.length} bytes, '
          '${image.width}x${image.height})');
    } catch (e, st) {
      // ignore: avoid_print
      print('SCREENSHOT FAILED ($fileName): $e\n$st');
      rethrow;
    }
  });
}

// ─────────────────────────────────────────────────────────────────────
// Tests (one capture per test)
// ─────────────────────────────────────────────────────────────────────

/// Load the bundled app fonts (Manrope + JetBrainsMono) AND the
/// Flutter framework's icon fonts (MaterialIcons, CupertinoIcons) into
/// the test font registry. Without app fonts, text rasterises as
/// "tofu" boxes; without icon fonts, every `Icon()` widget rasterises
/// as the same tofu box. Both are needed for usable design hand-off.
Future<void> _loadAppFonts() async {
  Future<void> loadAsset(String family, String assetPath) async {
    final loader = FontLoader(family);
    final bytes = await rootBundle.load(assetPath);
    loader.addFont(Future.value(bytes));
    await loader.load();
  }

  Future<void> loadFile(String family, String filePath) async {
    final loader = FontLoader(family);
    final raw = await File(filePath).readAsBytes();
    loader.addFont(Future.value(ByteData.view(raw.buffer)));
    await loader.load();
  }

  await loadAsset('Manrope', 'assets/fonts/Manrope.ttf');
  await loadAsset('JetBrainsMono', 'assets/fonts/JetBrainsMono.ttf');
  // Framework + cupertino_icons fonts live outside the app's asset
  // bundle. Absolute paths are operator-machine-specific but stable
  // across Flutter SDK installs; the test fails fast if either is
  // missing so misconfiguration is obvious.
  await loadFile(
    'MaterialIcons',
    r'C:\Users\DjMhel\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
  );
  await loadFile(
    'CupertinoIcons',
    r'C:\Users\DjMhel\AppData\Local\Pub\Cache\hosted\pub.dev\cupertino_icons-1.0.9\assets\CupertinoIcons.ttf',
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadAppFonts();
  });

  testWidgets('login • light • tablet', (tester) async {
    await _pumpAndCapture(
      tester,
      session: _signedOutSession,
      mode: ThemeMode.light,
      fileName: 'aura-login-light-tablet.png',
    );
  });

  testWidgets('login • dark • tablet', (tester) async {
    await _pumpAndCapture(
      tester,
      session: _signedOutSession,
      mode: ThemeMode.dark,
      fileName: 'aura-login-dark-tablet.png',
    );
  });

  testWidgets('dashboard • light • tablet', (tester) async {
    await _pumpAndCapture(
      tester,
      session: _gabrielSession,
      mode: ThemeMode.light,
      fileName: 'aura-dashboard-light-tablet.png',
    );
  });

  testWidgets('dashboard • dark • tablet', (tester) async {
    await _pumpAndCapture(
      tester,
      session: _gabrielSession,
      mode: ThemeMode.dark,
      fileName: 'aura-dashboard-dark-tablet.png',
    );
  });
}
