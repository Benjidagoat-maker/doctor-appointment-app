#!/usr/bin/env bash
# Run once after cloning. Needs: Flutter SDK, Node (for firebase-tools), a Firebase project.
set -e
if [ ! -d web ]; then
  mv lib /tmp/_lib_src
  flutter create . --platforms=web,android,ios --project-name doctor_appointment_app
  rm -rf lib test && mv /tmp/_lib_src lib
fi
flutter pub add firebase_core firebase_auth cloud_firestore
dart pub global activate flutterfire_cli
flutterfire configure          # generates lib/firebase_options.dart
flutter pub get
echo "Done. Next: firebase use <project-id> && flutter build web && firebase deploy"
