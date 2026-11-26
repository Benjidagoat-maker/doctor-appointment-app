const { applicationDefault, initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");

const args = process.argv.slice(2);
const emailLookup = args[0] === "--email";
const target = emailLookup ? args[1]?.trim().toLowerCase() : args[0];
const role = args[emailLookup ? 2 : 1];

if (
  !target ||
  (emailLookup && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(target)) ||
  !["user", "admin"].includes(role)
) {
  console.error(
    "Usage: npm run set-role -- <firebase-auth-uid> <user|admin>\n" +
      "   or: npm run set-role -- --email <email> <user|admin>",
  );
  process.exitCode = 2;
} else {
  initializeApp({
    credential: applicationDefault(),
    projectId:
      process.env.GCLOUD_PROJECT ??
      process.env.GOOGLE_CLOUD_PROJECT ??
      "doctor-appointment-2026",
  });
  const auth = getAuth();
  const lookup = emailLookup
    ? auth.getUserByEmail(target)
    : auth.getUser(target);
  lookup
    .then(async (user) => {
      await auth.setCustomUserClaims(user.uid, {
        ...user.customClaims,
        role,
      });
      await getFirestore().doc(`users/${user.uid}`).set({ role }, { merge: true });
      console.log(
        `Set ${emailLookup ? user.email : user.uid} role to ${role}. ` +
          "The user must sign out and sign in again.",
      );
    })
    .catch((error) => {
      console.error("Could not set role:", error.message);
      process.exitCode = 1;
    });
}
