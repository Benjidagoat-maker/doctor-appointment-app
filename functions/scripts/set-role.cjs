const { applicationDefault, initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");

const [uid, role] = process.argv.slice(2);
if (!uid || !["user", "admin"].includes(role)) {
  console.error("Usage: npm run set-role -- <firebase-auth-uid> <user|admin>");
  process.exitCode = 2;
} else {
  initializeApp({ credential: applicationDefault() });
  getAuth().getUser(uid)
    .then(async (user) => {
      await getAuth().setCustomUserClaims(uid, {
        ...user.customClaims,
        role,
      });
      await getFirestore().doc(`users/${uid}`).set({ role }, { merge: true });
      console.log(`Set ${uid} role to ${role}. The user must sign in again.`);
    })
    .catch((error) => {
      console.error("Could not set role:", error.message);
      process.exitCode = 1;
    });
}
