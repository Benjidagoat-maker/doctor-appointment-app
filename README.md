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

The app uses Firebase Authentication for sign-in, Cloud Firestore for doctors and appointments, and Firebase Realtime Database for live doctor presence. An optional REST API integration can retrieve medical-record data from a SQL-backed service. Without that API configured, the app displays clearly labeled demo records instead.

> **Important:** This project is a software demo, not a medical service. Do not use it to store or process real patient information without appropriate security, privacy, and regulatory review.

## Features

### Patients
- Create an account and sign in with email and password; email verification is required.
- Search the doctor directory by name, specialty, or phone number.
- View doctor availability and live presence when Realtime Database is configured.
- Choose a date and time to book an appointment, then view or cancel bookings.
- View SQL-backed medical records when an API is configured; otherwise, see sample demo data.

### Administrators
- Add and remove doctors and update their availability.
- Review appointments across the app.
- Admin access is controlled by the `role` field in the Firestore `users` collection; users cannot grant themselves admin access.

### Security and backend
- Firestore security rules restrict user data and appointment access.
- Firebase App Check is initialized by the app. Production enforcement must also be configured in the Firebase Console.
- Appointment booking prevents past appointments and duplicate bookings by the same patient in the client. Preventing different patients from booking the same slot requires an additional trusted server-side check.

## Technology

- **App:** Flutter, Dart, Material Design
- **Authentication:** Firebase Authentication
- **Data:** Cloud Firestore and Firebase Realtime Database
- **Optional integration:** SQL-backed REST API
- **Hosting:** Firebase Hosting
- **Automation:** GitHub Actions for analysis, tests, and hosting deployment

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

Set `SQL_API_URL` to the base URL of a compatible REST API. The app expects the following endpoints:

- `GET <SQL_API_URL>/patients/<patientId>/records` — returns a JSON array of records.
- `POST <SQL_API_URL>/appointments/sync` — accepts appointment JSON.

For example:

```bash
flutter run -d chrome --dart-define=SQL_API_URL=https://your-api.example.com/api
```

When `SQL_API_URL` is unset, the service uses its placeholder URL and returns demo records without making a network request. The sample client does not add authentication to these API requests; configure a trusted backend and appropriate authentication/authorization before connecting real data.

## Build and deploy

Build the web app:

```bash
flutter build web --release
```

The Firebase Hosting configuration serves `build/web`. To deploy, authenticate with Firebase CLI and select/configure the intended Firebase project first, then run:

```bash
firebase deploy --only hosting
```

Firebase resources and rules can be deployed separately after reviewing the project configuration:

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
```

## Known limitations

- The client cannot guarantee that two different patients will not book the same doctor and time. Add a server-side transaction or trusted booking function before using this for real scheduling.
- The optional SQL API integration is a client-side example and does not authenticate requests. Do not connect it to sensitive data without adding server-side identity checks and access controls.
- Configure Firebase services, authorized domains, App Check, and security rules for your own environment before deployment.

## Contributing

Issues and pull requests are welcome. For changes, run `flutter analyze` and `flutter test` before submitting a pull request.
