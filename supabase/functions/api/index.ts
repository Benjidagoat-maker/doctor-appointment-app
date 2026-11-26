import { createRemoteJWKSet, jwtVerify } from "npm:jose@6.2.18";
import { createClient } from "npm:@supabase/supabase-js@2.119.2";

type Actor = { uid: string; role: "user" | "admin" };

class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

const firebaseJwks = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function jsonResponse(body: unknown, status = 200): Response {
  return Response.json(body, {
    status,
    headers: corsHeaders,
  });
}

async function authenticate(request: Request): Promise<Actor> {
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  if (!projectId) {
    throw new ApiError(503, "Firebase authentication is not configured.");
  }

  const authorization = request.headers.get("authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(authorization);
  if (!match) throw new ApiError(401, "A Firebase ID token is required.");

  try {
    const { payload } = await jwtVerify(match[1], firebaseJwks, {
      algorithms: ["RS256"],
      audience: projectId,
      issuer: `https://securetoken.google.com/${projectId}`,
    });
    if (
      typeof payload.sub !== "string" ||
      payload.sub.length === 0 ||
      payload.email_verified !== true
    ) {
      throw new ApiError(403, "A verified Firebase account is required.");
    }

    const role = payload.role;
    if (role !== undefined && role !== "user" && role !== "admin") {
      throw new ApiError(403, "This account cannot access medical records.");
    }
    return { uid: payload.sub, role: role === "admin" ? "admin" : "user" };
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(401, "The Firebase ID token is invalid or expired.");
  }
}

function getSupabaseClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) {
    throw new ApiError(503, "The records database is not configured.");
  }
  return createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (request.method !== "GET") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const route = new URL(request.url).pathname.replace(/\/+$/, "");
  if (!route.endsWith("/records")) {
    return jsonResponse({ error: "Not found." }, 404);
  }

  try {
    const actor = await authenticate(request);
    const url = new URL(request.url);
    const requestedPatientUid = url.searchParams.get("patient_uid");
    if (
      actor.role !== "admin" &&
      requestedPatientUid !== null &&
      requestedPatientUid !== actor.uid
    ) {
      throw new ApiError(403, "You cannot access another patient's records.");
    }
    const patientUid =
      actor.role === "admin" && requestedPatientUid
        ? requestedPatientUid
        : actor.uid;
    const database = getSupabaseClient();

    const { error: auditError } = await database.from("access_log").insert({
      actor_uid: actor.uid,
      actor_role: actor.role,
      action: "read_medical_records",
      patient_uid: patientUid,
    });
    if (auditError) {
      console.error("Medical record audit write failed:", auditError.message);
      throw new ApiError(503, "Medical records are temporarily unavailable.");
    }

    let query = database
      .from("medical_records")
      .select("id, doctor_name, diagnosis, record_date, status")
      .eq("patient_uid", patientUid)
      .order("record_date", { ascending: false });
    if (actor.role !== "admin") {
      query = query.in("status", ["final", "amended"]);
    }

    const { data, error } = await query;
    if (error) {
      console.error("Medical record query failed:", error.message);
      throw new ApiError(503, "Medical records are temporarily unavailable.");
    }
    return jsonResponse(data ?? []);
  } catch (error) {
    if (error instanceof ApiError) {
      return jsonResponse({ error: error.message }, error.status);
    }
    console.error("Unexpected medical records API error:", error);
    return jsonResponse({ error: "Medical records are temporarily unavailable." }, 500);
  }
});
