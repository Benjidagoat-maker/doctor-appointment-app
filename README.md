# Doctor Appointment App

Flutter + Firebase Auth + Cloud Firestore. Roles: `user` (browse doctors, book/cancel) and `admin` (manage doctors, see all appointments). Hosted on Firebase Hosting.

## Setup
1. Create a Firebase project; enable **Authentication → Email/Password** and **Firestore**.
2. `./setup.sh` (generates platform folders + `lib/firebase_options.dart`).
3. `firebase login && firebase use <project-id>`
4. `firebase deploy --only firestore:rules` then `flutter build web && firebase deploy --only hosting`

## Admin
Sign-up always creates role `user`. To promote someone: Firestore console → `users/<uid>` → set `role` to `admin`.

## CI/CD
`.github/workflows/deploy.yml` deploys on every push to `main`. Add the secret `FIREBASE_SERVICE_ACCOUNT` (set up automatically by `firebase init hosting:github`).
