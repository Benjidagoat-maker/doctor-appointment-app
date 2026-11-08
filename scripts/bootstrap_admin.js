/**
 * Doctor Care - Firebase Super Admin Bootstrapper (Dashboard V22)
 *
 * This script ensures that kenjirobenji@gmail.com is set up as an ADMIN in
 * Firebase Authentication and Firestore.
 *
 * Requirements:
 * 1. Admin Email: kenjirobenji@gmail.com
 * 2. Admin Pass:  bjbjmonjeya17
 * 3. Role:        'admin'
 */

import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import * as fs from 'fs';
import * as path from 'path';

const ADMIN_EMAIL = 'kenjirobenji@gmail.com';
const ADMIN_PASSWORD = 'bjbjmonjeya17';
const ADMIN_NAME = 'Super Admin Kenji';

async function bootstrapAdmin() {
  console.log('⚡ Bootstrapping Doctor Care Super Admin (Firebase)...');

  // Check if service account is available
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || './serviceAccountKey.json';

  if (!fs.existsSync(serviceAccountPath)) {
    console.log(`ℹ️ Note: No service account key found at ${serviceAccountPath}.`);
    console.log(`   The client app automatically recognizes ${ADMIN_EMAIL} on login / sign-up`);
    console.log(`   and sets role: 'admin' directly via Firestore security rules and AuthService.`);
    return;
  }

  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

  if (!getApps().length) {
    initializeApp({
      credential: cert(serviceAccount),
    });
  }

  const auth = getAuth();
  const db = getFirestore();

  try {
    let user;
    try {
      user = await auth.getUserByEmail(ADMIN_EMAIL);
      console.log(`✅ Existing user found: ${user.uid}`);
      // Ensure password and email verified
      await auth.updateUser(user.uid, {
        password: ADMIN_PASSWORD,
        emailVerified: true,
        displayName: ADMIN_NAME,
      });
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        user = await auth.createUser({
          email: ADMIN_EMAIL,
          password: ADMIN_PASSWORD,
          displayName: ADMIN_NAME,
          emailVerified: true,
        });
        console.log(`✅ Created new Admin user: ${user.uid}`);
      } else {
        throw e;
      }
    }

    // Set custom claims
    await auth.setCustomUserClaims(user.uid, { role: 'admin', admin: true });

    // Upsert Firestore user record
    await db.collection('users').doc(user.uid).set(
      {
        name: ADMIN_NAME,
        email: ADMIN_EMAIL,
        role: 'admin',
        is_online: true,
        last_login: FieldValue.serverTimestamp(),
        created_at: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    console.log(`✨ Success: ${ADMIN_EMAIL} is configured as 'admin' in Firebase Auth & Firestore.`);
  } catch (err) {
    console.error('❌ Error bootstrapping admin:', err);
  }
}

bootstrapAdmin().catch(console.error);

