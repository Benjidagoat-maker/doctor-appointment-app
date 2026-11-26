import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as functions from "firebase-functions/v1";
import { auth, db } from "./admin.js";
import { FieldValue } from "firebase-admin/firestore";

const ROLES = new Set(["user", "admin"]);

export const setUserRole = onCall(
  { enforceAppCheck: true, region: "europe-west1", maxInstances: 10 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    if (request.auth.token.role !== "admin") {
      throw new HttpsError("permission-denied", "Administrator access required.");
    }

    const { uid, role } = request.data as { uid?: unknown; role?: unknown };
    if (
      typeof uid !== "string" ||
      uid.length === 0 ||
      typeof role !== "string" ||
      !ROLES.has(role)
    ) {
      throw new HttpsError("invalid-argument", "A valid user ID and role are required.");
    }

    let target;
    try {
      target = await auth.getUser(uid);
    } catch {
      throw new HttpsError("not-found", "User not found.");
    }

    await auth.setCustomUserClaims(uid, {
      ...target.customClaims,
      role,
    });
    await db.doc(`users/${uid}`).set({ role }, { merge: true });
    return { ok: true };
  },
);

export const initializeNewUser = functions.auth.user().onCreate(async (user) => {
  await auth.setCustomUserClaims(user.uid, {
    ...user.customClaims,
    role: "user",
  });
  await db.doc(`users/${user.uid}`).set(
    {
      email: user.email ?? "",
      name: user.displayName ?? "",
      role: "user",
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
});
