<div align="center">

# 🩺 Doctor Care & Appointment App

### A cross-platform, enterprise-ready healthcare booking application built with Flutter, Firebase, and SQL Backend Architecture.

[![Live Demo](https://img.shields.io/badge/Live%20Demo-Hosted%20on%20Firebase-0F67FE?style=for-the-badge&logo=firebase&logoColor=white)](https://doctor-appointment-2026.web.app)
[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20RTDB-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![GitHub](https://img.shields.io/badge/GitHub-Repository-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Benjidagoat-maker/doctor-appointment-app)

---

</div>

## 🌟 Overview

The **Doctor Care Application** is designed to streamline the connection between patients and healthcare providers. It provides patients with effortless doctor discovery, custom scheduling, real-time presence indicators, and synchronized digital medical records, while offering healthcare managers an administrative control center to oversee providers and appointments.

---

## 🚀 Live Demo

Experience the live web build deployed via Firebase Hosting:
👉 **[doctor-appointment-2026.web.app](https://doctor-appointment-2026.web.app)**

---

## 💡 Key Features

### 👤 For Patients
- **Email Verification Guard**: Requires new users to verify their Gmail/email before granting access, featuring automatic real-time polling and re-send throttles.
- **Doctor Directory & Instant Search**: Filter medical professionals by specialty, name, or phone number in real-time.
- **Custom Booking System**: Interactive Date and Time picker to schedule visits with instant feedback.
- **My Appointments Management**: View upcoming visits, check status (Confirmed / Cancelled), or cancel appointments.
- **SQL Medical Records Sheet**: Interactive bottom-sheet view pulling historical medical records and diagnoses connected to external relational SQL databases.

### 🛡️ Real-Time & Security
- **Firebase App Check**: Safeguards backend APIs against bots, scraping, and abuse using reCAPTCHA Enterprise and platform attestation.
- **Live Presence & Notification Sync (Realtime Database)**: Live indicator displaying if doctors are online or in consultation, accompanied by instant push notifications upon appointment booking.
- **Role-Based Access Control**: Strict segregation between patient interfaces and administrator panels powered by Cloud Firestore security rules.

### 👨‍⚕️ For Administrators
- **Doctor Catalog Management**: Register new medical specialists and update availability toggles.
- **System-Wide Appointment Oversight**: Monitor all booked consultations in real time.

---

## 🛠️ Tech Stack & Architecture

```
┌────────────────────────────────────────────────────────┐
│                   Flutter Client                       │
│    (Web / Android / Windows / iOS / Material 3)        │
└───────────┬─────────────────┬─────────────────┬────────┘
            │                 │                 │
            ▼                 ▼                 ▼
 ┌──────────────────┐ ┌───────────────┐ ┌───────────────┐
 │  Firebase Auth   │ │  Firestore &  │ │   REST API    │
 │   & App Check    │ │  Realtime DB  │ │  (SQL Gateway)│
 └──────────────────┘ └───────────────┘ └───────┬───────┘
                                                │
                                                ▼
                                     ┌─────────────────────┐
                                     │ MySQL / PostgreSQL  │
                                     │    / Cloud SQL      │
                                     └─────────────────────┘
```

| Domain | Technology / Service | Description |
| :--- | :--- | :--- |
| **Framework** | **Flutter 3.47+ & Dart** | Cross-platform UI toolkit targeting Web, Android, and Desktop |
| **UI Design System** | **Material 3 / Custom AppTheme** | Clinical Blue (`#0F67FE`), rounded card geometries, custom typography |
| **Authentication** | **Firebase Authentication** | Email/Password with mandatory email verification handshake |
| **App Security** | **Firebase App Check** | reCAPTCHA Enterprise & device attestation against API abuse |
| **Primary Database** | **Cloud Firestore** | Document-based NoSQL storage for users, doctors, and appointments |
| **Live Updates** | **Firebase Realtime Database** | Sub-second sync for doctor live presence badges & instant alerts |
| **Relational DB** | **SQL REST API Layer** | Connects to PostgreSQL, MySQL, or Google Cloud SQL for medical records |
| **Deployment** | **Firebase Hosting & CI/CD** | Production-ready web distribution and automated deployment |

---

## 📂 Project Structure

```text
lib/
├── firebase_options.dart         # Auto-generated Firebase platform configs
├── main.dart                     # App entry point & App Check activation
├── models/
│   ├── appointment_model.dart    # Appointment schema & serialization
│   ├── doctor_model.dart         # Doctor entity definition
│   └── user_model.dart           # User profile & RBAC representation
├── screens/
│   ├── admin_dashboard.dart      # Admin management console
│   ├── appointments_screen.dart  # User booking overview & cancellations
│   ├── doctor_details_screen.dart# Doctor profile, date-time booking & sync
│   ├── email_verification_screen.dart # Realtime Gmail verification listener
│   ├── home_screen.dart          # Searchable doctor feed & SQL sheet trigger
│   ├── login_screen.dart         # Secure sign-in with verification handling
│   └── signup_screen.dart        # User registration flow
├── services/
│   ├── auth_service.dart         # Authentication, sign-out & verification logic
│   ├── firestore_service.dart    # Firestore CRUD operations & streams
│   ├── realtime_db_service.dart  # Realtime presence & notification engine
│   └── sql_api_service.dart      # MySQL / PostgreSQL / Cloud SQL connector
└── theme/
    └── app_theme.dart            # Medical theme, palette, and component styles
```

---

## ⚡ Getting Started

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.13+ / 3.47+)
- [Git](https://git-scm.com/)
- [Firebase CLI](https://firebase.google.com/docs/cli)

### 2. Clone & Install
```bash
git clone https://github.com/Benjidagoat-maker/doctor-appointment-app.git
cd doctor-appointment-app
flutter pub get
```

### 3. Run Locally
```bash
# Run in Chrome
flutter run -d chrome

# Run on Windows Desktop
flutter run -d windows
```

### 4. Build & Deploy
```bash
# Build production web bundle
flutter build web

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

---

## 📄 License
This project is open-source and available under the [MIT License](LICENSE).
