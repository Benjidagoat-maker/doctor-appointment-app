import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { auth, db } from "./admin.js";

const REGION = "europe-west1";
const MINIMUM_LEAD_TIME_MS = 15 * 60_000;
const MAXIMUM_BOOKING_DAYS = 60;
const MAX_ACTIVE_APPOINTMENTS = 3;
const DAY_KEYS: Record<string, string> = {
  Mon: "mon",
  Tue: "tue",
  Wed: "wed",
  Thu: "thu",
  Fri: "fri",
  Sat: "sat",
  Sun: "sun",
};

function requireUser(request: {
  auth?: { uid: string; token: Record<string, unknown> } | null;
}): string {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (request.auth.token.email_verified !== true) {
    throw new HttpsError("permission-denied", "Verify your email before booking.");
  }
  if (request.auth.token.role !== "user") {
    throw new HttpsError("permission-denied", "A patient account is required.");
  }
  return request.auth.uid;
}

function requireAdmin(request: {
  auth?: { uid: string; token: Record<string, unknown> } | null;
}): string {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (request.auth.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Administrator access required.");
  }
  return request.auth.uid;
}

function assertPatientAvailability(
  appointments: Array<{ id: string; data: () => Record<string, unknown> }>,
  start: Date,
  durationMin: number,
  excludedAppointmentId?: string,
): void {
  const now = Date.now();
  const active = appointments.filter(({ id, data: getData }) => {
    if (id === excludedAppointmentId) return false;
    const appointment = getData();
    const status = String(appointment.status ?? "").toLowerCase();
    const appointmentDate = appointment.date;
    return status !== "cancelled" &&
      status !== "cancelled_late" &&
      status !== "completed" &&
      appointmentDate instanceof Timestamp &&
      appointmentDate.toMillis() > now;
  });
  if (active.length >= MAX_ACTIVE_APPOINTMENTS) {
    throw new HttpsError("failed-precondition", "Maximum of 3 upcoming active appointments reached.");
  }
  const startMs = start.getTime();
  const endMs = startMs + durationMin * 60_000;
  const hasOverlap = active.some(({ data: getData }) => {
    const appointment = getData();
    const existingStart = (appointment.date as Timestamp).toMillis();
    const existingEnd = existingStart + Number(appointment.durationMin ?? 30) * 60_000;
    return startMs < existingEnd && endMs > existingStart;
  });
  if (hasOverlap) {
    throw new HttpsError("failed-precondition", "The patient already has an appointment during this time.");
  }
}

function parseDate(value: unknown): Date {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "A valid appointment date is required.");
  }
  const date = new Date(value);
  if (!Number.isFinite(date.getTime()) || date.getUTCSeconds() !== 0 ||
      date.getUTCMilliseconds() !== 0) {
    throw new HttpsError("invalid-argument", "A valid appointment date is required.");
  }
  return date;
}

function partsInZone(date: Date, timeZone: string): Record<string, string> {
  let parts: Intl.DateTimeFormatPart[];
  try {
    parts = new Intl.DateTimeFormat("en-US", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
      weekday: "short",
    }).formatToParts(date);
  } catch {
    throw new HttpsError("failed-precondition", "Doctor schedule has an invalid time zone.");
  }
  return Object.fromEntries(parts.map(({ type, value }) => [type, value]));
}

function isWithinDoctorSchedule(
  doctor: Record<string, unknown>,
  start: Date,
  durationMin: number,
): boolean {
  const timezone = typeof doctor.timezone === "string" ? doctor.timezone : "Africa/Tunis";
  const parts = partsInZone(start, timezone);
  const weekday = DAY_KEYS[parts.weekday];
  if (!weekday) return false;
  const localDate = `${parts.year}-${parts.month}-${parts.day}`;
  const daysOff = Array.isArray(doctor.daysOff) ? doctor.daysOff : [];
  if (daysOff.includes(localDate)) return false;

  const hour = Number(parts.hour);
  const minute = Number(parts.minute);
  const startMinute = hour * 60 + minute;
  const configuredDuration = Number(doctor.slotDurationMin ?? 30);
  if (!Number.isInteger(configuredDuration) || configuredDuration !== durationMin) {
    return false;
  }

  const schedule = doctor.schedule as Record<string, unknown> | undefined;
  const ranges = schedule?.[weekday];
  if (!Array.isArray(ranges)) return false;
  return ranges.some((range) => {
    if (range === null || typeof range !== "object") return false;
    const { start: rangeStart, end: rangeEnd } = range as {
      start?: unknown;
      end?: unknown;
    };
    if (typeof rangeStart !== "string" || typeof rangeEnd !== "string") return false;
    const toMinutes = (value: string): number | null => {
      const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(value);
      return match ? Number(match[1]) * 60 + Number(match[2]) : null;
    };
    const rangeStartMin = toMinutes(rangeStart);
    const rangeEndMin = toMinutes(rangeEnd);
    return rangeStartMin !== null &&
      rangeEndMin !== null &&
      startMinute >= rangeStartMin &&
      (startMinute - rangeStartMin) % durationMin === 0 &&
      startMinute + durationMin <= rangeEndMin;
  });
}

function lockIds(doctorId: string, start: Date): { current: string; legacy: string } {
  const utc = start;
  const padded = (n: number, width = 2) => String(n).padStart(width, "0");
  return {
    current: `${doctorId}_${Math.floor(start.getTime() / 60_000)}`,
    legacy: `${padded(utc.getUTCFullYear(), 4)}${padded(utc.getUTCMonth() + 1)}${padded(utc.getUTCDate())}${padded(utc.getUTCHours())}${padded(utc.getUTCMinutes())}`,
  };
}

export const bookAppointment = onCall(
  { enforceAppCheck: true, region: REGION, maxInstances: 20 },
  async (request) => {
    const userId = requireUser(request);
    const { doctorId, reason } = request.data as {
      doctorId?: unknown;
      date?: unknown;
      reason?: unknown;
    };
    if (typeof doctorId !== "string" || doctorId.length === 0 || doctorId.includes("/")) {
      throw new HttpsError("invalid-argument", "A valid doctor ID is required.");
    }
    if (typeof reason !== "string" || reason.length > 500) {
      throw new HttpsError("invalid-argument", "The appointment reason must be 500 characters or fewer.");
    }

    const start = parseDate((request.data as { date?: unknown }).date);
    const now = Date.now();
    if (start.getTime() < now + MINIMUM_LEAD_TIME_MS) {
      throw new HttpsError("failed-precondition", "Choose an appointment at least 15 minutes from now.");
    }
    if (start.getTime() > now + MAXIMUM_BOOKING_DAYS * 24 * 60 * 60_000) {
      throw new HttpsError("failed-precondition", "Appointments can only be booked up to 60 days ahead.");
    }

    const doctorRef = db.doc(`doctors/${doctorId}`);
    const userRef = db.doc(`users/${userId}`);
    const appointmentRef = db.collection("appointments").doc();
    const ids = lockIds(doctorId, start);
    const lockRef = db.doc(`bookedSlots/${ids.current}`);
    const legacyLockRef = db.doc(`doctors/${doctorId}/bookedSlots/${ids.legacy}`);
    const startTimestamp = Timestamp.fromDate(start);

    await db.runTransaction(async (transaction) => {
      const mineQuery = db.collection("appointments").where("userId", "==", userId);
      const doctorSlotQuery = db.collection("appointments")
        .where("doctorId", "==", doctorId)
        .where("date", "==", startTimestamp);
      const [
        doctorSnapshot,
        userSnapshot,
        lockSnapshot,
        legacySnapshot,
        mineSnapshot,
        doctorSlotSnapshot,
      ] =
        await Promise.all([
          transaction.get(doctorRef),
          transaction.get(userRef),
          transaction.get(lockRef),
          transaction.get(legacyLockRef),
          transaction.get(mineQuery),
          transaction.get(doctorSlotQuery),
        ]);
      if (!doctorSnapshot.exists || doctorSnapshot.data()?.active === false ||
          doctorSnapshot.data()?.available === false) {
        throw new HttpsError("not-found", "Doctor unavailable.");
      }
      if (!userSnapshot.exists) {
        throw new HttpsError("failed-precondition", "Your user profile is not ready.");
      }
      if (lockSnapshot.exists || legacySnapshot.exists) {
        throw new HttpsError("failed-precondition", "This appointment time was just taken.");
      }
      if (doctorSlotSnapshot.docs.some((document) => {
        const status = String(document.data().status ?? "").toLowerCase();
        return status !== "cancelled" && status !== "cancelled_late" &&
          status !== "completed";
      })) {
        throw new HttpsError("failed-precondition", "This appointment time was just taken.");
      }

      const doctor = doctorSnapshot.data()!;
      const durationMin = Number(doctor.slotDurationMin ?? 30);
      if (!Number.isInteger(durationMin) || durationMin < 5 || durationMin > 240 ||
          !isWithinDoctorSchedule(doctor, start, durationMin)) {
        throw new HttpsError("failed-precondition", "This time is outside the doctor's schedule.");
      }
      assertPatientAvailability(mineSnapshot.docs, start, durationMin);
      const endMs = start.getTime() + durationMin * 60_000;

      const user = userSnapshot.data()!;
      transaction.create(lockRef, {
        doctorId,
        start: startTimestamp,
        status: "booked",
        appointmentId: appointmentRef.id,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(legacyLockRef, {
        appointmentId: appointmentRef.id,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(appointmentRef, {
        userId,
        doctorId,
        doctorName: String(doctor.name ?? ""),
        patientName: String(user.name ?? request.auth?.token.name ?? ""),
        patientEmail: String(request.auth?.token.email ?? ""),
        specialty: String(doctor.specialty ?? "General"),
        date: startTimestamp,
        durationMin,
        endAt: Timestamp.fromMillis(endMs),
        status: "confirmed",
        reason: reason.trim(),
        lockId: ids.current,
        amountMinor: Number.isInteger(doctor.consultationFeeMinor)
          ? doctor.consultationFeeMinor
          : 0,
        currency: typeof doctor.currency === "string" ? doctor.currency : "TND",
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    return { appointmentId: appointmentRef.id, status: "confirmed" };
  },
);

export const createAdminAppointment = onCall(
  { enforceAppCheck: true, region: REGION, maxInstances: 10 },
  async (request) => {
    requireAdmin(request);
    const { doctorId, patientEmail, reason = "" } = request.data as {
      doctorId?: unknown;
      patientEmail?: unknown;
      date?: unknown;
      reason?: unknown;
    };
    if (typeof doctorId !== "string" || doctorId.length === 0 || doctorId.includes("/") ||
        typeof patientEmail !== "string" || patientEmail.length === 0 ||
        typeof reason !== "string" || reason.length > 500) {
      throw new HttpsError("invalid-argument", "Doctor, patient email, and a valid reason are required.");
    }

    const patient = await auth.getUserByEmail(patientEmail.trim()).catch(() => {
      throw new HttpsError("not-found", "Patient account not found.");
    });
    if (!patient.emailVerified) {
      throw new HttpsError("failed-precondition", "The patient must verify their email before booking.");
    }
    const start = parseDate((request.data as { date?: unknown }).date);
    const now = Date.now();
    if (start.getTime() < now + MINIMUM_LEAD_TIME_MS ||
        start.getTime() > now + MAXIMUM_BOOKING_DAYS * 24 * 60 * 60_000) {
      throw new HttpsError("failed-precondition", "Choose a time within the next 60 days and at least 15 minutes away.");
    }

    const doctorRef = db.doc(`doctors/${doctorId}`);
    const userRef = db.doc(`users/${patient.uid}`);
    const appointmentRef = db.collection("appointments").doc();
    const ids = lockIds(doctorId, start);
    const lockRef = db.doc(`bookedSlots/${ids.current}`);
    const legacyLockRef = db.doc(`doctors/${doctorId}/bookedSlots/${ids.legacy}`);
    const startTimestamp = Timestamp.fromDate(start);

    await db.runTransaction(async (transaction) => {
      const mineQuery = db.collection("appointments").where("userId", "==", patient.uid);
      const doctorSlotQuery = db.collection("appointments")
        .where("doctorId", "==", doctorId)
        .where("date", "==", startTimestamp);
      const [doctorSnapshot, userSnapshot, lockSnapshot, legacySnapshot, mineSnapshot, doctorSlotSnapshot] =
        await Promise.all([
          transaction.get(doctorRef),
          transaction.get(userRef),
          transaction.get(lockRef),
          transaction.get(legacyLockRef),
          transaction.get(mineQuery),
          transaction.get(doctorSlotQuery),
        ]);
      if (!doctorSnapshot.exists || doctorSnapshot.data()?.active === false ||
          doctorSnapshot.data()?.available === false) {
        throw new HttpsError("not-found", "Doctor unavailable.");
      }
      if (!userSnapshot.exists) {
        throw new HttpsError("failed-precondition", "The patient profile is not ready.");
      }
      if (lockSnapshot.exists || legacySnapshot.exists ||
          doctorSlotSnapshot.docs.some((document) => {
            const status = String(document.data().status ?? "").toLowerCase();
            return status !== "cancelled" && status !== "cancelled_late" &&
              status !== "completed";
          })) {
        throw new HttpsError("failed-precondition", "This appointment time was just taken.");
      }

      const doctor = doctorSnapshot.data()!;
      const durationMin = Number(doctor.slotDurationMin ?? 30);
      if (!Number.isInteger(durationMin) || durationMin < 5 || durationMin > 240 ||
          !isWithinDoctorSchedule(doctor, start, durationMin)) {
        throw new HttpsError("failed-precondition", "This time is outside the doctor's schedule.");
      }
      assertPatientAvailability(mineSnapshot.docs, start, durationMin);
      const endMs = start.getTime() + durationMin * 60_000;
      const user = userSnapshot.data()!;
      transaction.create(lockRef, {
        doctorId,
        start: startTimestamp,
        status: "booked",
        appointmentId: appointmentRef.id,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(legacyLockRef, {
        appointmentId: appointmentRef.id,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(appointmentRef, {
        userId: patient.uid,
        doctorId,
        doctorName: String(doctor.name ?? ""),
        patientName: String(user.name ?? patient.displayName ?? ""),
        patientEmail: patient.email ?? patientEmail.trim(),
        specialty: String(doctor.specialty ?? "General"),
        date: startTimestamp,
        durationMin,
        endAt: Timestamp.fromMillis(endMs),
        status: "confirmed",
        reason: reason.trim(),
        lockId: ids.current,
        amountMinor: Number.isInteger(doctor.consultationFeeMinor)
          ? doctor.consultationFeeMinor
          : 0,
        currency: typeof doctor.currency === "string" ? doctor.currency : "TND",
        createdAt: FieldValue.serverTimestamp(),
      });
    });
    return { appointmentId: appointmentRef.id };
  },
);

export const cancelAppointment = onCall(
  { enforceAppCheck: true, region: REGION, maxInstances: 20 },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");
    const { appointmentId } = request.data as { appointmentId?: unknown };
    if (typeof appointmentId !== "string" || appointmentId.length === 0) {
      throw new HttpsError("invalid-argument", "A valid appointment ID is required.");
    }
    const role = request.auth.token.role;
    const appointmentRef = db.doc(`appointments/${appointmentId}`);

    await db.runTransaction(async (transaction) => {
      const appointmentSnapshot = await transaction.get(appointmentRef);
      if (!appointmentSnapshot.exists) {
        throw new HttpsError("not-found", "Appointment not found.");
      }
      const appointment = appointmentSnapshot.data()!;
      const isAdmin = role === "admin";
      const isDoctor = role === "doctor" &&
        request.auth?.token.doctorId === appointment.doctorId;
      if (appointment.userId !== request.auth?.uid && !isAdmin && !isDoctor) {
        throw new HttpsError("permission-denied", "You cannot cancel this appointment.");
      }
      if (["cancelled", "cancelled_late"].includes(String(appointment.status).toLowerCase())) {
        return;
      }
      if (!["confirmed", "booked"].includes(String(appointment.status).toLowerCase())) {
        throw new HttpsError("failed-precondition", "This appointment cannot be cancelled.");
      }
      const start = appointment.date;
      if (!(start instanceof Timestamp)) {
        throw new HttpsError("failed-precondition", "Appointment date is invalid.");
      }
      if (!isAdmin && !isDoctor && start.toMillis() - Date.now() < 48 * 60 * 60_000) {
        throw new HttpsError("failed-precondition", "Appointments can only be cancelled at least 48 hours ahead.");
      }

      const derivedIds = lockIds(String(appointment.doctorId), start.toDate());
      const lockId = typeof appointment.lockId === "string" ? appointment.lockId : derivedIds.current;
      const lockRef = db.doc(`bookedSlots/${lockId}`);
      const legacyLockRef = db.doc(`doctors/${appointment.doctorId}/bookedSlots/${derivedIds.legacy}`);
      const [lockSnapshot, legacySnapshot] = await Promise.all([
        transaction.get(lockRef),
        transaction.get(legacyLockRef),
      ]);
      transaction.update(appointmentRef, {
        status: "cancelled",
        cancelledBy: request.auth?.uid,
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (lockSnapshot.data()?.appointmentId === appointmentId) transaction.delete(lockRef);
      if (legacySnapshot.data()?.appointmentId === appointmentId) transaction.delete(legacyLockRef);
    });
    return { ok: true };
  },
);

export const setAppointmentStatus = onCall(
  { enforceAppCheck: true, region: REGION, maxInstances: 10 },
  async (request) => {
    requireAdmin(request);
    const { appointmentId, status } = request.data as {
      appointmentId?: unknown;
      status?: unknown;
    };
    const nextStatus = typeof status === "string" ? status.toLowerCase() : "";
    if (typeof appointmentId !== "string" || appointmentId.length === 0 ||
        !["confirmed", "completed", "cancelled", "no_show"].includes(nextStatus)) {
      throw new HttpsError("invalid-argument", "A valid appointment and status are required.");
    }

    const appointmentRef = db.doc(`appointments/${appointmentId}`);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(appointmentRef);
      if (!snapshot.exists) throw new HttpsError("not-found", "Appointment not found.");
      const appointment = snapshot.data()!;
      const start = appointment.date;
      if (!(start instanceof Timestamp)) {
        throw new HttpsError("failed-precondition", "Appointment date is invalid.");
      }

      const doctorId = String(appointment.doctorId);
      const ids = lockIds(doctorId, start.toDate());
      const lockId = typeof appointment.lockId === "string" ? appointment.lockId : ids.current;
      const lockRef = db.doc(`bookedSlots/${lockId}`);
      const legacyLockRef = db.doc(`doctors/${doctorId}/bookedSlots/${ids.legacy}`);
      const [lockSnapshot, legacySnapshot] = await Promise.all([
        transaction.get(lockRef),
        transaction.get(legacyLockRef),
      ]);

      if (nextStatus === "confirmed") {
        if (start.toMillis() < Date.now() + MINIMUM_LEAD_TIME_MS) {
          throw new HttpsError("failed-precondition", "Past appointments cannot be confirmed.");
        }
        const doctorRef = db.doc(`doctors/${doctorId}`);
        const doctorSlotQuery = db.collection("appointments")
          .where("doctorId", "==", doctorId)
          .where("date", "==", start);
        const mineQuery = db.collection("appointments")
          .where("userId", "==", appointment.userId);
        const [doctorSnapshot, doctorSlotSnapshot, mineSnapshot] = await Promise.all([
          transaction.get(doctorRef),
          transaction.get(doctorSlotQuery),
          transaction.get(mineQuery),
        ]);
        if (!doctorSnapshot.exists || doctorSnapshot.data()?.active === false ||
            doctorSnapshot.data()?.available === false) {
          throw new HttpsError("failed-precondition", "Doctor unavailable.");
        }
        if (doctorSlotSnapshot.docs.some((document) => {
          if (document.id === appointmentId) return false;
          const otherStatus = String(document.data().status ?? "").toLowerCase();
          return otherStatus !== "cancelled" && otherStatus !== "cancelled_late" &&
            otherStatus !== "completed";
        })) {
          throw new HttpsError("failed-precondition", "This appointment time is already taken.");
        }
        const durationMin = Number(appointment.durationMin ?? 30);
        if (!isWithinDoctorSchedule(doctorSnapshot.data()!, start.toDate(), durationMin)) {
          throw new HttpsError("failed-precondition", "This time is outside the doctor's schedule.");
        }
        assertPatientAvailability(mineSnapshot.docs, start.toDate(), durationMin, appointmentId);
        for (const lock of [lockSnapshot, legacySnapshot]) {
          if (lock.exists && lock.data()?.appointmentId !== appointmentId) {
            throw new HttpsError("failed-precondition", "This appointment time is already taken.");
          }
        }
        if (!lockSnapshot.exists) {
          transaction.create(lockRef, {
            doctorId,
            start,
            status: "booked",
            appointmentId,
            createdAt: FieldValue.serverTimestamp(),
          });
        }
        if (!legacySnapshot.exists) {
          transaction.create(legacyLockRef, {
            appointmentId,
            createdAt: FieldValue.serverTimestamp(),
          });
        }
        transaction.update(appointmentRef, {
          status: nextStatus,
          lockId,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      transaction.update(appointmentRef, {
        status: nextStatus,
        ...(nextStatus === "cancelled" ? { cancelledBy: request.auth?.uid } : {}),
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (lockSnapshot.data()?.appointmentId === appointmentId) transaction.delete(lockRef);
      if (legacySnapshot.data()?.appointmentId === appointmentId) transaction.delete(legacyLockRef);
    });
    return { ok: true };
  },
);

export const rescheduleAppointment = onCall(
  { enforceAppCheck: true, region: REGION, maxInstances: 10 },
  async (request) => {
    requireAdmin(request);
    const { appointmentId } = request.data as { appointmentId?: unknown };
    if (typeof appointmentId !== "string" || appointmentId.length === 0) {
      throw new HttpsError("invalid-argument", "A valid appointment ID is required.");
    }
    const newStart = parseDate((request.data as { date?: unknown }).date);
    const now = Date.now();
    if (newStart.getTime() < now + MINIMUM_LEAD_TIME_MS ||
        newStart.getTime() > now + MAXIMUM_BOOKING_DAYS * 24 * 60 * 60_000) {
      throw new HttpsError("failed-precondition", "Choose a time within the next 60 days and at least 15 minutes away.");
    }

    const appointmentRef = db.doc(`appointments/${appointmentId}`);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(appointmentRef);
      if (!snapshot.exists) throw new HttpsError("not-found", "Appointment not found.");
      const appointment = snapshot.data()!;
      if (!["confirmed", "booked"].includes(String(appointment.status).toLowerCase())) {
        throw new HttpsError("failed-precondition", "Only active appointments can be rescheduled.");
      }
      const oldStart = appointment.date;
      if (!(oldStart instanceof Timestamp)) {
        throw new HttpsError("failed-precondition", "Appointment date is invalid.");
      }
      const doctorId = String(appointment.doctorId);
      const durationMin = Number(appointment.durationMin ?? 30);
      const newIds = lockIds(doctorId, newStart);
      const oldIds = lockIds(doctorId, oldStart.toDate());
      const oldLockId = typeof appointment.lockId === "string" ? appointment.lockId : oldIds.current;
      const newLockRef = db.doc(`bookedSlots/${newIds.current}`);
      const newLegacyLockRef = db.doc(`doctors/${doctorId}/bookedSlots/${newIds.legacy}`);
      const oldLockRef = db.doc(`bookedSlots/${oldLockId}`);
      const oldLegacyLockRef = db.doc(`doctors/${doctorId}/bookedSlots/${oldIds.legacy}`);
      const newStartTimestamp = Timestamp.fromDate(newStart);
      const doctorRef = db.doc(`doctors/${doctorId}`);
      const doctorSlotQuery = db.collection("appointments")
        .where("doctorId", "==", doctorId)
        .where("date", "==", newStartTimestamp);
      const mineQuery = db.collection("appointments")
        .where("userId", "==", appointment.userId);
      const [
        doctorSnapshot,
        newLockSnapshot,
        newLegacySnapshot,
        oldLockSnapshot,
        oldLegacySnapshot,
        doctorSlotSnapshot,
        mineSnapshot,
      ] = await Promise.all([
        transaction.get(doctorRef),
        transaction.get(newLockRef),
        transaction.get(newLegacyLockRef),
        transaction.get(oldLockRef),
        transaction.get(oldLegacyLockRef),
        transaction.get(doctorSlotQuery),
        transaction.get(mineQuery),
      ]);
      if (!doctorSnapshot.exists || doctorSnapshot.data()?.active === false ||
          doctorSnapshot.data()?.available === false ||
          !isWithinDoctorSchedule(doctorSnapshot.data()!, newStart, durationMin)) {
        throw new HttpsError("failed-precondition", "This time is outside the doctor's active schedule.");
      }
      if (doctorSlotSnapshot.docs.some((document) => {
        if (document.id === appointmentId) return false;
        const status = String(document.data().status ?? "").toLowerCase();
        return status !== "cancelled" && status !== "cancelled_late" &&
          status !== "completed";
      })) {
        throw new HttpsError("failed-precondition", "This appointment time is already taken.");
      }
      for (const lock of [newLockSnapshot, newLegacySnapshot]) {
        if (lock.exists && lock.data()?.appointmentId !== appointmentId) {
          throw new HttpsError("failed-precondition", "This appointment time is already taken.");
        }
      }
      assertPatientAvailability(mineSnapshot.docs, newStart, durationMin, appointmentId);

      const sameLock = newIds.current === oldLockId;
      const sameLegacyLock = newIds.legacy === oldIds.legacy;
      if (!sameLock && oldLockSnapshot.data()?.appointmentId === appointmentId) {
        transaction.delete(oldLockRef);
      }
      if (!sameLegacyLock && oldLegacySnapshot.data()?.appointmentId === appointmentId) {
        transaction.delete(oldLegacyLockRef);
      }
      if (!newLockSnapshot.exists) {
        transaction.create(newLockRef, {
          doctorId,
          start: newStartTimestamp,
          status: "booked",
          appointmentId,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
      if (!newLegacySnapshot.exists) {
        transaction.create(newLegacyLockRef, {
          appointmentId,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.update(appointmentRef, {
        date: newStartTimestamp,
        endAt: Timestamp.fromMillis(newStart.getTime() + durationMin * 60_000),
        lockId: newIds.current,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
  },
);

export const deleteAppointment = onCall(
  { enforceAppCheck: true, region: REGION, maxInstances: 10 },
  async (request) => {
    requireAdmin(request);
    const { appointmentId } = request.data as { appointmentId?: unknown };
    if (typeof appointmentId !== "string" || appointmentId.length === 0) {
      throw new HttpsError("invalid-argument", "A valid appointment ID is required.");
    }
    const appointmentRef = db.doc(`appointments/${appointmentId}`);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(appointmentRef);
      if (!snapshot.exists) throw new HttpsError("not-found", "Appointment not found.");
      const appointment = snapshot.data()!;
      const start = appointment.date;
      if (!(start instanceof Timestamp)) {
        transaction.delete(appointmentRef);
        return;
      }
      const ids = lockIds(String(appointment.doctorId), start.toDate());
      const lockId = typeof appointment.lockId === "string" ? appointment.lockId : ids.current;
      const lockRef = db.doc(`bookedSlots/${lockId}`);
      const legacyLockRef = db.doc(`doctors/${appointment.doctorId}/bookedSlots/${ids.legacy}`);
      const [lockSnapshot, legacySnapshot] = await Promise.all([
        transaction.get(lockRef),
        transaction.get(legacyLockRef),
      ]);
      if (lockSnapshot.data()?.appointmentId === appointmentId) transaction.delete(lockRef);
      if (legacySnapshot.data()?.appointmentId === appointmentId) transaction.delete(legacyLockRef);
      transaction.delete(appointmentRef);
    });
    return { ok: true };
  },
);
