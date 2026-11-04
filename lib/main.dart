import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

/// Public reCAPTCHA Enterprise site key (safe to ship). Override per
/// environment with `--dart-define=RECAPTCHA_SITE_KEY=...`.
const String _recaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_SITE_KEY',
  defaultValue: '6LcMohAuAAAAANSO0kqvuUvymNd26CZBqlZjL6J2',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Must run before the first Firestore call. Auto-detect falls back to HTTP
  // long-polling when the WebChannel stream is blocked (proxies, ad-blockers,
  // some networks) - a classic cause of "client is offline" on web.
  FirebaseFirestore.instance.settings =
      const Settings(webExperimentalAutoDetectLongPolling: true);

  await _activateAppCheck();
  runApp(const MyApp());
}

/// App Check must never be able to stop the app from starting.
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      // Debug builds use the debug providers (register the printed debug
      // token in Firebase Console > App Check > Apps > Manage debug tokens).
      providerWeb: kDebugMode
          ? WebDebugProvider()
          : ReCaptchaEnterpriseProvider(_recaptchaSiteKey),
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: const AppleDeviceCheckProvider(),
    );
  } catch (e) {
    debugPrint('App Check activation failed (continuing without it): $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Care',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}
