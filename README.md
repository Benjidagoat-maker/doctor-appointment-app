<div align="center">

# 🩺 Doctor Care

A Flutter application for discovering doctors, booking appointments, and managing doctor availability with Firebase.

[![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Live demo](https://img.shields.io/badge/Live%20demo-Open-0F67FE?style=for-the-badge)](https://doctor-appointment-2026.web.app)

[Open the web app](https://doctor-appointment-2026.web.app) · [Report a bug](https://github.com/Benjidagoat-maker/doctor-appointment-app/issues)

</div>

---

## About

Doctor Care is a cross-platform appointment-booking app built with Flutter and Dart. Patients can find doctors, view availability, book and cancel appointments, and see their appointment history. Administrators can manage the doctor directory and oversee bookings.

The app uses Firebase Authentication for sign-in, Cloud Firestore for doctors and appointments, and Firebase Realtime Database for live doctor presence. Medical records require a separately configured, authenticated SQL-backed API; when it is unavailable, the app does not display fabricated records.

> **Important:** This project is a software demo, not a medical service. Do not use it to store or process real patient information without appropriate security, privacy, and regulatory review.

## Features

### Patients
- Create an account and sign in with email and password; email verification is required.
- Search the doctor directory by name, specialty, or phone number.
- View doctor availability and live presence when Realtime Database is configured.
- Choose a date and time to book an appointment, then view or cancel bookings.
- View SQL-backed medical records only when an authenticated API is configured.

### Administrators
- Add and remove doctors and update their availability.
- Review appointments across the app.
- Admin access is controlled by Firebase Authentication custom claims. The Firestore role field is a display mirror and is never used for authorization.

### Security and backend
- Firestore rules deny all client writes to appointment records and slot locks. Callable Cloud Functions validate patient bookings and handle admin appointment management transactionally.
- Booking validates the doctor's active state, configured timezone and schedule, patient limits, and overlapping visits on the server.
- Callable functions enforce Firebase App Check. Register the app providers and debug tokens in Firebase Console before enabling production traffic.
- Existing accounts need an explicit admin claim before admin features are available; legacy accounts can still book as patients.

## Technology

- **App:** Flutter, Dart, Material Design
- **Authentication:** Firebase Authentication
- **Data:** Cloud Firestore and Firebase Realtime Database
- **Trusted backend:** Firebase Cloud Functions (TypeScript)
- **Optional integration:** SQL-backed REST API
- **Hosting:** Firebase Hosting
- **Automation:** GitHub Actions for analysis, tests, and Firebase deployment

## Run locally

### Prerequisites

- Flutter SDK on the stable channel, with a Dart SDK satisfying the constraint in `pubspec.yaml`
- Git
- A configured Firebase project for authentication and Firestore-backed app functionality
- Firebase CLI if you plan to deploy Firebase resources or hosting

### Install dependencies

```bash
git clone https://github.com/Benjidagoat-maker/doctor-appointment-app.git
cd doctor-appointment-app
flutter pub get
```

### Firebase configuration

The repository includes FlutterFire configuration files for its existing Firebase project. To use your own project, create/configure the Firebase apps and regenerate the platform configuration with the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup):

```bash
flutterfire configure
```

In the Firebase Console, enable Email/Password sign-in and create a Cloud Firestore database. Add the domains you use (for example, `localhost` and your hosting domain) to Authentication's authorized domains. Review `firestore.rules` and `database.rules.json` before deploying rules to your project.

Install the Functions dependencies with Node.js 22:

```bash
npm --prefix functions ci
npm --prefix functions run build
```

### Deploying the secure booking backend

Deploy the callable functions before changing the rules:

```bash
firebase deploy --only functions
```

Existing accounts do not receive custom claims automatically. Use an Admin SDK credential to assign roles. The script uses Application Default Credentials; run `gcloud auth application-default login` or set `GOOGLE_APPLICATION_CREDENTIALS` to a protected service-account file:

```bash
npm --prefix functions run set-role -- YOUR_PATIENT_UID user
npm --prefix functions run set-role -- YOUR_ADMIN_UID admin
# Or identify an existing account by email:
npm --prefix functions run set-role -- --email admin@example.com admin
```

Assign `admin` only to explicitly approved administrator accounts. A missing role claim is treated as a patient role for booking only; it never grants admin access. New accounts receive the `user` claim through the `initializeNewUser` Auth trigger. Users whose roles change must sign in again to refresh their token.

On pushes to `main` or `master`, GitHub Actions now deploys Functions, Firestore rules/indexes, and Hosting in that order. The `FIREBASE_SERVICE_ACCOUNT` repository secret must have permission to deploy each resource. Pull-request runs deploy only a Hosting preview.

For a manual backend deployment, run `firebase deploy --only functions` first, assign roles to existing accounts, then run `firebase deploy --only firestore:rules,firestore:indexes`.

For local App Check development, debug providers are used by debug builds. Register the debug token shown by the app in Firebase Console → App Check. For production, configure the appropriate App Check provider and enforcement settings in the console.

### Start the app

```bash
# Run in Chrome
flutter run -d chrome

# Run on Windows (requires the Windows desktop toolchain)
flutter run -d windows
```

Other supported targets depend on the Flutter SDK and platform toolchains installed on your machine.

### Optional SQL API

The app's records API is a Supabase Edge Function at the configured `SQL_API_URL` (default: `https://yuddnebxjvulyvrjhugf.supabase.co/functions/v1/api`). The migration in `supabase/migrations/` creates the PostgreSQL tables. Deploy the schema and Edge Function with the Supabase CLI:

```bash
supabase link --project-ref yuddnebxjvulyvrjhugf
supabase db push
supabase secrets set FIREBASE_PROJECT_ID=doctor-appointment-2026
supabase functions deploy api --no-verify-jwt
```

The function verifies Firebase ID tokens itself, derives patient identity from the verified UID, and logs record access. The Supabase `service_role` key is used only inside the Edge Function; never add it to Flutter or GitHub variables. Direct `anon`/`authenticated` database access remains revoked by the migration. The app sends its Firebase ID token as `Authorization: Bearer <token>` and the public Supabase anon key as `apikey`.

Set the Supabase anon/publishable key as the GitHub Actions variable `SUPABASE_ANON_KEY` so production web builds can call the function. This key is intentionally public; it does not grant database access. For local builds:

```bash
flutter run -d chrome --dart-define=SQL_API_URL=https://yuddnebxjvulyvrjhugf.supabase.co/functions/v1/api --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_SUPABASE_ANON_KEY
```

The records endpoint is read-only for patients and returns only finalized/amended records for the signed-in user. An empty table produces an empty list; no sample medical data is generated. Appointment booking remains server-authoritative in Firebase and is not copied to SQL by the client.

## Build and deploy

Build the web app:

```bash
flutter build web --release
```

The Firebase Hosting configuration serves `build/web`. To deploy, authenticate with Firebase CLI and select/configure the intended Firebase project first, then run:

```bash
firebase deploy --only hosting
```

Other Firebase resources can be deployed after reviewing the project configuration:

```bash
firebase deploy --only firestore:rules,database
```

The GitHub Actions workflow in `.github/workflows/deploy.yml` runs `flutter analyze` and `flutter test` and includes a Firebase Hosting deployment job. Configure the required `FIREBASE_SERVICE_ACCOUNT` repository secret before relying on automated deployment.

## Tests and analysis

```bash
flutter analyze
flutter test
```

## Project layout

```text
lib/
├── main.dart                 # Firebase initialization and app entry point
├── firebase_options.dart     # FlutterFire platform configuration
├── models/                   # User, doctor, and appointment data models
├── screens/                  # Authentication, patient, and admin screens
├── services/                 # Firebase and SQL REST API access
├── theme/                    # App theme
└── utils/                    # Shared helpers

firestore.rules               # Cloud Firestore security rules
 database.rules.json           # Realtime Database security rules
firebase.json                 # Firebase Hosting and service configuration
functions/                     # Trusted booking and role-management callables
```

## Known limitations

- Stripe, video visits, and the authenticated SQL records API are not implemented yet; do not treat the current app as production-ready for real payments, telehealth, or protected health information.
- The optional SQL API integration is a client-side example and does not authenticate requests. Do not connect it to sensitive data without adding server-side identity checks and access controls.
- Configure Firebase services, authorized domains, App Check, and security rules for your own environment before deployment.

## Contributing

Issues and pull requests are welcome. For changes, run `flutter analyze` and `flutter test` before submitting a pull request.
