import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey",
};

const REPLICATE_URL = "https://api.replicate.com/v1/predictions";

// Pinned model version for cuuupid/idm-vton. Update if the model is revised.
// Get the latest hash from replicate.com/cuuupid/idm-vton/api
const MODEL_VERSION =
  "0513734a452173b8173e907e3a59d19a36266e55b48528559432bd21c7d7e985";

// One credit per garment application. A prediction is ~$0.024 of Replicate
// spend, so this is the only place real money leaves the project.
const CREDITS_PER_GARMENT = 1;

// Backstop against a runaway client loop or an abuser draining the Replicate
// balance: no more than this many predictions per UTC day across all users.
// At ~$0.024 a run, 300 caps a bad day at roughly $7.
const DEFAULT_DAILY_GLOBAL_CAP = 300;

// Only these garment-input fields from the client are forwarded to Replicate.
// Everything else (version, steps, crop) is fixed server-side.
interface CreateBody {
  action: "create";
  human_img: string;
  garm_img: string;
  category: string;
  garment_des: string;
}
interface PollBody {
  action: "poll";
  id: string;
}

interface Env {
  replicateKey: string;
  supabaseUrl: string;
  serviceKey: string;
  dailyCap: number;
}

interface TryOnJob {
  id: string;
  user_id: string;
  refunded: boolean;
  credits_charged: number;
}

export async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  try {
    const replicateKey = Deno.env.get("REPLICATE_API_TOKEN") ?? "";
    if (!replicateKey) {
      console.error("[try-on] REPLICATE_API_TOKEN not configured");
      return json({ error: "Server not configured" }, 500);
    }

    // Injected automatically by the Supabase Edge runtime.
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceKey) {
      console.error("[try-on] SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not configured");
      return json({ error: "Server not configured" }, 500);
    }

    const env: Env = {
      replicateKey,
      supabaseUrl,
      serviceKey,
      dailyCap: Number(Deno.env.get("TRYON_DAILY_GLOBAL_CAP")) || DEFAULT_DAILY_GLOBAL_CAP,
    };

    // Credits are per-user, so an anonymous caller can never reach Replicate.
    // The client used to fall back to the publishable key here; that key is not
    // a user token and is rejected by the /auth/v1/user check below.
    const jwt = bearer(req.headers.get("Authorization"));
    if (!jwt) return json({ error: "Sign in to use try-on", code: "unauthenticated" }, 401);

    const payload = await req.json() as CreateBody | PollBody;

    // Shape validation happens before the network round-trip to /auth/v1/user
    // so obviously-malformed calls cost nothing.
    if (payload.action === "create") {
      if (!payload.human_img || !payload.garm_img || !payload.category) {
        return json({ error: "Missing human_img, garm_img or category" }, 400);
      }
    } else if (payload.action === "poll") {
      if (!payload.id) return json({ error: "Missing prediction id" }, 400);
    } else {
      return json({ error: "Unknown action" }, 400);
    }

    const userId = await resolveUserId(jwt, env);
    if (!userId) {
      return json({ error: "Sign in to use try-on", code: "unauthenticated" }, 401);
    }

    return payload.action === "create"
      ? await createPrediction(payload, userId, env)
      : await pollPrediction(payload, userId, env);
  } catch (err) {
    console.error("[try-on]", err);
    return json({ error: String(err) }, 500);
  }
}

// Only start the server when run directly (not when imported by a test).
if (import.meta.main) serve(handler);

// ── create ──────────────────────────────────────────────────────────────────

async function createPrediction(
  body: CreateBody,
  userId: string,
  env: Env,
): Promise<Response> {
  const { human_img, garm_img, category, garment_des } = body;

  if (await dailySpendExceeded(env)) {
    console.warn("[try-on] global daily cap reached");
    return json({
      error: "Try-on is at capacity for today. Please try again tomorrow.",
      code: "daily_cap_reached",
    }, 503);
  }

  // Reserve the job first: its id is the ledger's idempotency key, so the debit
  // is recorded against something durable before any money is spent.
  const jobId = await createJob(userId, env);
  if (!jobId) return json({ error: "Could not start try-on" }, 500);

  const balance = await spendCredit(userId, jobId, env);
  if (balance === "insufficient") {
    await updateJob(jobId, { status: "rejected" }, env);
    return json({
      error: "You're out of try-on credits.",
      code: "insufficient_credits",
      credits_remaining: 0,
    }, 402);
  }
  if (balance === "error") {
    await updateJob(jobId, { status: "rejected" }, env);
    return json({ error: "Could not start try-on" }, 500);
  }

  const res = await fetch(REPLICATE_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${env.replicateKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      version: MODEL_VERSION,
      input: {
        human_img,
        garm_img,
        category,
        garment_des: garment_des ?? "",
        crop: true, // person photos are rarely a perfect 3:4
        steps: 30,
      },
    }),
  });

  const data = await res.json();
  if (res.status !== 201) {
    console.error("[try-on] create failed", res.status, data);
    // Nothing was rendered, so the user must not pay for it.
    await refundCredit(userId, jobId, env);
    await updateJob(jobId, { status: "failed", refunded: true }, env);
    return json({ error: data?.detail ?? "Replicate create failed" }, 502);
  }

  await updateJob(jobId, { prediction_id: data.id, status: data.status }, env);

  return json({ id: data.id, status: data.status, credits_remaining: balance }, 200);
}

// ── poll ────────────────────────────────────────────────────────────────────

async function pollPrediction(
  body: PollBody,
  userId: string,
  env: Env,
): Promise<Response> {
  // Proves the prediction belongs to the caller before we return its output or
  // credit anything back. A miss and a foreign job look identical from outside.
  const job = await findJobByPrediction(body.id, env);
  if (!job || job.user_id !== userId) {
    return json({ error: "Unknown prediction" }, 404);
  }

  const res = await fetch(`${REPLICATE_URL}/${body.id}`, {
    headers: { "Authorization": `Bearer ${env.replicateKey}` },
  });

  const data = await res.json();
  if (!res.ok) {
    console.error("[try-on] poll failed", res.status, data);
    return json({ error: data?.detail ?? "Replicate poll failed" }, 502);
  }

  const status = data.status as string;

  if (status === "failed" || status === "canceled") {
    // refund_credit is idempotent, so the client polling a dead prediction in a
    // loop still only ever gets one credit back.
    if (!job.refunded) {
      await refundCredit(userId, job.id, env, job.credits_charged);
      await updateJob(job.id, { status, refunded: true, completed_at: nowIso() }, env);
    }
  } else if (status === "succeeded") {
    await updateJob(job.id, { status, completed_at: nowIso() }, env);
  }

  // Forward only the fields the client needs — never the raw Replicate URLs.
  return json({
    status,
    output: data.output ?? null,
    error: data.error ?? null,
  }, 200);
}

// ── supabase helpers (raw PostgREST, no SDK dependency) ─────────────────────

function restHeaders(env: Env): HeadersInit {
  return {
    "apikey": env.serviceKey,
    "Authorization": `Bearer ${env.serviceKey}`,
    "Content-Type": "application/json",
  };
}

/// Verifies the caller's JWT and returns their user id, or null if the token is
/// missing, expired, or an API key rather than a user session.
async function resolveUserId(jwt: string, env: Env): Promise<string | null> {
  try {
    const res = await fetch(`${env.supabaseUrl}/auth/v1/user`, {
      headers: { "apikey": env.serviceKey, "Authorization": `Bearer ${jwt}` },
    });
    if (!res.ok) return null;
    const user = await res.json();
    return typeof user?.id === "string" ? user.id : null;
  } catch (err) {
    console.error("[try-on] auth lookup failed", err);
    return null;
  }
}

async function dailySpendExceeded(env: Env): Promise<boolean> {
  const since = new Date();
  since.setUTCHours(0, 0, 0, 0);

  try {
    // `rejected` rows never reached Replicate, so they cost nothing and must
    // not count. Otherwise a crowd of users with empty balances could exhaust
    // the cap and lock out the people who actually paid.
    const query = "select=id&status=neq.rejected" +
      `&created_at=gte.${since.toISOString()}`;
    const res = await fetch(
      `${env.supabaseUrl}/rest/v1/tryon_jobs?${query}`,
      { headers: { ...restHeaders(env), "Prefer": "count=exact", "Range": "0-0" } },
    );
    // "0-0/42" — the total is what we want, not the page.
    const total = Number(res.headers.get("content-range")?.split("/")[1]);
    await res.body?.cancel();
    return Number.isFinite(total) && total >= env.dailyCap;
  } catch (err) {
    // A failed count must not block paying users; the per-user balance is still
    // enforced, so the worst case is the soft cap not applying for one request.
    console.error("[try-on] daily cap check failed", err);
    return false;
  }
}

async function createJob(userId: string, env: Env): Promise<string | null> {
  try {
    const res = await fetch(`${env.supabaseUrl}/rest/v1/tryon_jobs`, {
      method: "POST",
      headers: { ...restHeaders(env), "Prefer": "return=representation" },
      body: JSON.stringify({
        user_id: userId,
        status: "pending",
        credits_charged: CREDITS_PER_GARMENT,
      }),
    });
    if (!res.ok) {
      console.error("[try-on] job insert failed", res.status, await res.text());
      return null;
    }
    const rows = await res.json();
    return rows?.[0]?.id ?? null;
  } catch (err) {
    console.error("[try-on] job insert failed", err);
    return null;
  }
}

async function updateJob(
  jobId: string,
  patch: Record<string, unknown>,
  env: Env,
): Promise<void> {
  try {
    const res = await fetch(
      `${env.supabaseUrl}/rest/v1/tryon_jobs?id=eq.${jobId}`,
      { method: "PATCH", headers: restHeaders(env), body: JSON.stringify(patch) },
    );
    await res.body?.cancel();
  } catch (err) {
    // Bookkeeping only — never fail the user's request over it.
    console.error("[try-on] job update failed", err);
  }
}

async function findJobByPrediction(
  predictionId: string,
  env: Env,
): Promise<TryOnJob | null> {
  try {
    const query = "select=id,user_id,refunded,credits_charged" +
      `&prediction_id=eq.${encodeURIComponent(predictionId)}&limit=1`;
    const res = await fetch(`${env.supabaseUrl}/rest/v1/tryon_jobs?${query}`, {
      headers: restHeaders(env),
    });
    if (!res.ok) {
      await res.body?.cancel();
      return null;
    }
    const rows = await res.json();
    return rows?.[0] ?? null;
  } catch (err) {
    console.error("[try-on] job lookup failed", err);
    return null;
  }
}

/// Returns the new balance, or a marker for the two failure modes the caller
/// has to treat differently: no credits (402) versus a broken ledger (500).
async function spendCredit(
  userId: string,
  jobId: string,
  env: Env,
): Promise<number | "insufficient" | "error"> {
  try {
    const res = await fetch(`${env.supabaseUrl}/rest/v1/rpc/spend_credit`, {
      method: "POST",
      headers: restHeaders(env),
      body: JSON.stringify({
        p_user_id: userId,
        p_ref: jobId,
        p_amount: CREDITS_PER_GARMENT,
      }),
    });
    const data = await res.json();
    if (res.ok) return typeof data === "number" ? data : 0;
    if (data?.message === "insufficient_credits") return "insufficient";
    console.error("[try-on] spend_credit failed", res.status, data);
    return "error";
  } catch (err) {
    console.error("[try-on] spend_credit failed", err);
    return "error";
  }
}

async function refundCredit(
  userId: string,
  jobId: string,
  env: Env,
  amount: number = CREDITS_PER_GARMENT,
): Promise<void> {
  try {
    const res = await fetch(`${env.supabaseUrl}/rest/v1/rpc/refund_credit`, {
      method: "POST",
      headers: restHeaders(env),
      body: JSON.stringify({ p_user_id: userId, p_ref: jobId, p_amount: amount }),
    });
    if (!res.ok) console.error("[try-on] refund failed", res.status, await res.text());
    else await res.body?.cancel();
  } catch (err) {
    console.error("[try-on] refund failed", err);
  }
}

// ── misc ────────────────────────────────────────────────────────────────────

function bearer(header: string | null): string | null {
  if (!header) return null;
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match ? match[1] : null;
}

function nowIso(): string {
  return new Date().toISOString();
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
