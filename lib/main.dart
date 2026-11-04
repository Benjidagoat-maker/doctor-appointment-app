import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firebase App Check - protects backend resources from abuse
  // Uses reCAPTCHA v3 on web, DeviceCheck on iOS, Play Integrity on Android.
  // Switch to AndroidProvider.playIntegrity / AppleProvider.deviceCheck for production.
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,   // change to playIntegrity in prod
    appleProvider: AppleProvider.debug,       // change to deviceCheck in prod
    webProvider: ReCaptchaEnterpriseProvider('YOUR_RECAPTCHA_SITE_KEY'), // replace with your key
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Appointment App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
