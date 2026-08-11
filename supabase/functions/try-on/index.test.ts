import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { handler } from "./index.ts";

const URL = "http://localhost/try-on";

// Any non-empty bearer gets past the header check; the tests below all return
// before the token is actually verified against /auth/v1/user, so none of them
// touch the network.
const AUTH = { authorization: "Bearer fake-user-jwt" };

function post(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request(URL, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

function setEnv() {
  Deno.env.set("REPLICATE_API_TOKEN", "test-token");
  Deno.env.set("SUPABASE_URL", "http://localhost:54321");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
}

function clearEnv() {
  Deno.env.delete("REPLICATE_API_TOKEN");
  Deno.env.delete("SUPABASE_URL");
  Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
}

Deno.test("OPTIONS returns CORS preflight headers", async () => {
  const res = await handler(new Request(URL, { method: "OPTIONS" }));
  await res.body?.cancel();
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("non-POST methods are rejected", async () => {
  const res = await handler(new Request(URL, { method: "GET" }));
  await res.text();
  assertEquals(res.status, 405);
});

Deno.test("returns 500 when the Replicate token is not configured", async () => {
  clearEnv();
  const res = await handler(post({ action: "poll", id: "abc" }, AUTH));
  const json = await res.json();
  assertEquals(res.status, 500);
  assertEquals(json.error, "Server not configured");
});

Deno.test("returns 500 when the service role key is not configured", async () => {
  clearEnv();
  Deno.env.set("REPLICATE_API_TOKEN", "test-token");
  try {
    const res = await handler(post({ action: "poll", id: "abc" }, AUTH));
    const json = await res.json();
    assertEquals(res.status, 500);
    assertEquals(json.error, "Server not configured");
  } finally {
    clearEnv();
  }
});

Deno.test("credit gating requires an authenticated user", async (t) => {
  setEnv();
  try {
    await t.step("no Authorization header → 401", async () => {
      const res = await handler(post({ action: "create", human_img: "h", garm_img: "g", category: "upper_body" }));
      const json = await res.json();
      assertEquals(res.status, 401);
      assertEquals(json.code, "unauthenticated");
    });

    // The old client fell back to the publishable key when there was no
    // session. That is not a bearer token and must not reach Replicate.
    await t.step("raw API key instead of a bearer token → 401", async () => {
      const res = await handler(
        post({ action: "create", human_img: "h", garm_img: "g", category: "upper_body" }, {
          authorization: "sb_publishable_abc123",
        }),
      );
      const json = await res.json();
      assertEquals(res.status, 401);
      assertEquals(json.code, "unauthenticated");
    });
  } finally {
    clearEnv();
  }
});

Deno.test("validation paths (env + auth header present, no network)", async (t) => {
  setEnv();
  try {
    await t.step("unknown action → 400", async () => {
      const res = await handler(post({ action: "frobnicate" }, AUTH));
      const json = await res.json();
      assertEquals(res.status, 400);
      assertEquals(json.error, "Unknown action");
    });

    await t.step("create with missing garment fields → 400", async () => {
      const res = await handler(post({ action: "create", human_img: "u" }, AUTH));
      const json = await res.json();
      assertEquals(res.status, 400);
      assertEquals(json.error, "Missing human_img, garm_img or category");
    });

    await t.step("poll with missing id → 400", async () => {
      const res = await handler(post({ action: "poll" }, AUTH));
      const json = await res.json();
      assertEquals(res.status, 400);
      assertEquals(json.error, "Missing prediction id");
    });
  } finally {
    clearEnv();
  }
});
