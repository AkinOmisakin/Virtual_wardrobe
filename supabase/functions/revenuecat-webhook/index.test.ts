import { assert, assertEquals, assertFalse } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { CREDIT_PACKS, handler, isRefund, secretsMatch } from "./index.ts";

const URL = "http://localhost/revenuecat-webhook";
const SECRET = "shared-secret-value";
const USER = "3f2504e0-4f89-41d3-9a0c-0305e82c3301";

function post(event: unknown, auth: string | null = SECRET): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (auth !== null) headers.authorization = auth;
  return new Request(URL, { method: "POST", headers, body: JSON.stringify({ event }) });
}

function setEnv() {
  Deno.env.set("REVENUECAT_WEBHOOK_SECRET", SECRET);
  Deno.env.set("SUPABASE_URL", "http://localhost:54321");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
}

function clearEnv() {
  Deno.env.delete("REVENUECAT_WEBHOOK_SECRET");
  Deno.env.delete("SUPABASE_URL");
  Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
  Deno.env.delete("ALLOW_SANDBOX_PURCHASES");
}

Deno.test("non-POST methods are rejected", async () => {
  const res = await handler(new Request(URL, { method: "GET" }));
  await res.text();
  assertEquals(res.status, 405);
});

Deno.test("returns 500 when the shared secret is not configured", async () => {
  clearEnv();
  const res = await handler(post({ type: "TEST" }));
  const json = await res.json();
  assertEquals(res.status, 500);
  assertEquals(json.error, "Server not configured");
});

Deno.test("rejects callers without the shared secret", async (t) => {
  setEnv();
  try {
    await t.step("missing header → 401", async () => {
      const res = await handler(post({ type: "NON_RENEWING_PURCHASE" }, null));
      await res.body?.cancel();
      assertEquals(res.status, 401);
    });

    await t.step("wrong secret → 401", async () => {
      const res = await handler(post({ type: "NON_RENEWING_PURCHASE" }, "nope"));
      await res.body?.cancel();
      assertEquals(res.status, 401);
    });

    // Same length as the real secret, so this exercises the byte comparison
    // rather than the length short-circuit.
    await t.step("same-length wrong secret → 401", async () => {
      const res = await handler(post({ type: "TEST" }, "x".repeat(SECRET.length)));
      await res.body?.cancel();
      assertEquals(res.status, 401);
    });
  } finally {
    clearEnv();
  }
});

Deno.test("events that must not touch the ledger (no network)", async (t) => {
  setEnv();
  try {
    await t.step("TEST event is acknowledged", async () => {
      const res = await handler(post({ type: "TEST" }));
      const json = await res.json();
      assertEquals(res.status, 200);
      assertEquals(json.status, "test event acknowledged");
    });

    await t.step("sandbox purchases are ignored by default", async () => {
      const res = await handler(post({
        type: "NON_RENEWING_PURCHASE",
        environment: "SANDBOX",
        app_user_id: USER,
        product_id: "credits_20",
        transaction_id: "GPA.1",
      }));
      const json = await res.json();
      assertEquals(res.status, 200);
      assertEquals(json.status, "sandbox event ignored");
    });

    // RevenueCat sends $RCAnonymousID:… when the app never called logIn().
    await t.step("anonymous app_user_id grants nothing", async () => {
      const res = await handler(post({
        type: "NON_RENEWING_PURCHASE",
        app_user_id: "$RCAnonymousID:abc123",
        product_id: "credits_20",
        transaction_id: "GPA.2",
      }));
      const json = await res.json();
      assertEquals(res.status, 200);
      assertEquals(json.status, "no linked account");
    });

    await t.step("unknown product grants nothing", async () => {
      const res = await handler(post({
        type: "NON_RENEWING_PURCHASE",
        app_user_id: USER,
        product_id: "credits_9999",
        transaction_id: "GPA.3",
      }));
      const json = await res.json();
      assertEquals(res.status, 200);
      assertEquals(json.status, "unknown product");
    });

    await t.step("event without an idempotency key grants nothing", async () => {
      const res = await handler(post({
        type: "NON_RENEWING_PURCHASE",
        app_user_id: USER,
        product_id: "credits_20",
      }));
      const json = await res.json();
      assertEquals(res.status, 200);
      assertEquals(json.status, "no idempotency key");
    });

    await t.step("unrelated event types are ignored", async () => {
      const res = await handler(post({
        type: "EXPIRATION",
        app_user_id: USER,
        transaction_id: "GPA.4",
      }));
      const json = await res.json();
      assertEquals(res.status, 200);
      assertEquals(json.status, "ignored EXPIRATION");
    });
  } finally {
    clearEnv();
  }
});

Deno.test("isRefund only fires for cancellations that returned money", () => {
  assert(isRefund("CANCELLATION", "CUSTOMER_SUPPORT"));
  assert(isRefund("CANCELLATION", "DEVELOPER_INITIATED"));
  assert(isRefund("CANCELLATION", "BILLING_ERROR"));
  assert(isRefund("REFUND"));

  // Turning off auto-renew is not a refund — revoking here would take credits
  // the user paid for.
  assertFalse(isRefund("CANCELLATION", "UNSUBSCRIBE"));
  assertFalse(isRefund("CANCELLATION", "PRICE_INCREASE"));
  assertFalse(isRefund("CANCELLATION", undefined));
  assertFalse(isRefund("NON_RENEWING_PURCHASE", "CUSTOMER_SUPPORT"));
});

Deno.test("secretsMatch compares exactly", () => {
  assert(secretsMatch(SECRET, SECRET));
  assertFalse(secretsMatch(null, SECRET));
  assertFalse(secretsMatch("", SECRET));
  assertFalse(secretsMatch(SECRET + "x", SECRET));
  assertFalse(secretsMatch(SECRET.toUpperCase(), SECRET));
});

Deno.test("credit packs are positive and distinct", () => {
  const amounts = Object.values(CREDIT_PACKS);
  assert(amounts.length > 0);
  assert(amounts.every((n) => Number.isInteger(n) && n > 0));
  assertEquals(new Set(amounts).size, amounts.length);
});
