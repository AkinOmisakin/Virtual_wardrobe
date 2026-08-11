import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { timingSafeEqual } from "https://deno.land/std@0.208.0/crypto/timing_safe_equal.ts";

// RevenueCat calls this endpoint directly, so there is no Supabase JWT and the
// platform's verify_jwt gate must be off (see deploy-functions.yml). The shared
// secret below is the only thing standing between the internet and free
// credits — it is checked before anything else happens.

// How many credits each store product grants. This map is the authority: the
// webhook never trusts a quantity from the payload, so a tampered or replayed
// event cannot grant more than the product is worth. Keys must match the
// product ids configured in Google Play and RevenueCat exactly.
export const CREDIT_PACKS: Record<string, number> = {
  "credits_20": 20,
  "credits_55": 55,
  "credits_140": 140,
};

// A CANCELLATION is only a refund for some reasons. UNSUBSCRIBE just means
// auto-renew was turned off and must never claw back credits already bought.
const REFUND_REASONS = new Set([
  "CUSTOMER_SUPPORT",
  "DEVELOPER_INITIATED",
  "BILLING_ERROR",
]);

const GRANT_EVENTS = new Set([
  "NON_RENEWING_PURCHASE", // consumable credit packs — what we sell today
  "INITIAL_PURCHASE",
  "RENEWAL",
]);

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

interface RcEvent {
  id?: string;
  type?: string;
  app_user_id?: string;
  product_id?: string;
  transaction_id?: string;
  cancel_reason?: string;
  environment?: string;
  store?: string;
}

interface Env {
  supabaseUrl: string;
  serviceKey: string;
  allowSandbox: boolean;
}

export async function handler(req: Request): Promise<Response> {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  if (!secret || !supabaseUrl || !serviceKey) {
    console.error("[revenuecat] not configured");
    return json({ error: "Server not configured" }, 500);
  }

  if (!secretsMatch(req.headers.get("Authorization"), secret)) {
    console.warn("[revenuecat] rejected: bad or missing shared secret");
    return json({ error: "Unauthorized" }, 401);
  }

  const env: Env = {
    supabaseUrl,
    serviceKey,
    allowSandbox: Deno.env.get("ALLOW_SANDBOX_PURCHASES") === "true",
  };

  let event: RcEvent;
  try {
    const body = await req.json();
    event = body?.event ?? {};
  } catch {
    // Malformed JSON will never succeed on retry.
    return json({ error: "Invalid payload" }, 400);
  }

  const type = event.type ?? "";

  // RevenueCat's dashboard "send test event" button.
  if (type === "TEST") return ok("test event acknowledged");

  // Play license testers produce SANDBOX events. Ignoring them by default keeps
  // your closed-testing group from minting real credits; flip
  // ALLOW_SANDBOX_PURCHASES=true while you are actually testing the flow.
  if (event.environment === "SANDBOX" && !env.allowSandbox) {
    return ok("sandbox event ignored");
  }

  // The app must call Purchases.logIn(<supabase user id>) before purchasing.
  // Without that, RevenueCat sends an anonymous id ($RCAnonymousID:…) and there
  // is no account to credit. Retrying cannot fix it, so this is a 200.
  const userId = event.app_user_id ?? "";
  if (!UUID_RE.test(userId)) {
    console.error("[revenuecat] unusable app_user_id", { type, id: event.id });
    return ok("no linked account");
  }

  // Idempotency key. transaction_id is stable across RevenueCat's retries and
  // across duplicate events for the same purchase; the event id is not.
  const ref = event.transaction_id || event.id;
  if (!ref) {
    console.error("[revenuecat] event has no transaction_id or id");
    return ok("no idempotency key");
  }

  if (GRANT_EVENTS.has(type)) {
    const amount = CREDIT_PACKS[event.product_id ?? ""];
    if (!amount) {
      // An unmapped product means the store and this map have drifted. Loud in
      // the logs, but a retry would not help.
      console.error("[revenuecat] unknown product", event.product_id);
      return ok("unknown product");
    }
    const result = await rpc("grant_credits", {
      p_user_id: userId,
      p_amount: amount,
      p_reason: "purchase",
      p_ref: ref,
    }, env);
    // A DB failure here is transient and costs the user money, so let
    // RevenueCat retry it.
    if (!result.ok) return json({ error: "Could not record purchase" }, 500);

    console.info("[revenuecat] granted", { amount, product: event.product_id });
    return ok("credits granted", result.value);
  }

  if (isRefund(type, event.cancel_reason)) {
    const result = await rpc("revoke_credits", {
      p_user_id: userId,
      p_ref: ref,
    }, env);
    if (!result.ok) return json({ error: "Could not record refund" }, 500);

    console.info("[revenuecat] revoked", { ref });
    return ok("credits revoked", result.value);
  }

  return ok(`ignored ${type}`);
}

if (import.meta.main) serve(handler);

// ── helpers ─────────────────────────────────────────────────────────────────

/// True only for cancellations that represent money going back to the user.
export function isRefund(type: string, cancelReason?: string): boolean {
  if (type === "REFUND") return true;
  if (type !== "CANCELLATION") return false;
  return REFUND_REASONS.has(cancelReason ?? "");
}

/// Constant-time comparison of the configured secret against the header, so a
/// caller cannot discover it byte by byte from response timings.
export function secretsMatch(header: string | null, secret: string): boolean {
  if (!header) return false;
  const encoder = new TextEncoder();
  const a = encoder.encode(header);
  const b = encoder.encode(secret);
  if (a.byteLength !== b.byteLength) return false;
  return timingSafeEqual(a, b);
}

async function rpc(
  fn: string,
  args: Record<string, unknown>,
  env: Env,
): Promise<{ ok: boolean; value?: number }> {
  try {
    const res = await fetch(`${env.supabaseUrl}/rest/v1/rpc/${fn}`, {
      method: "POST",
      headers: {
        "apikey": env.serviceKey,
        "Authorization": `Bearer ${env.serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(args),
    });
    const data = await res.json();
    if (!res.ok) {
      console.error(`[revenuecat] ${fn} failed`, res.status, data);
      return { ok: false };
    }
    return { ok: true, value: typeof data === "number" ? data : undefined };
  } catch (err) {
    console.error(`[revenuecat] ${fn} failed`, err);
    return { ok: false };
  }
}

/// RevenueCat retries any non-2xx, so everything we have deliberately decided
/// not to act on still returns 200.
function ok(message: string, balance?: number): Response {
  return json({ status: message, balance }, 200);
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
