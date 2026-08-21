import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { handler } from "./index.ts";

const URL = "http://localhost/delete-account";
const AUTH = { authorization: "Bearer fake-user-jwt" };

function post(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request(URL, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

function setEnv() {
  Deno.env.set("SUPABASE_URL", "http://localhost:54321");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
}

function clearEnv() {
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

Deno.test("returns 500 when the service role key is not configured", async () => {
  clearEnv();
  const res = await handler(post({ confirm: "DELETE" }, AUTH));
  const json = await res.json();
  assertEquals(res.status, 500);
  assertEquals(json.error, "Server not configured");
});

Deno.test("guards before anything is deleted (no network)", async (t) => {
  setEnv();
  try {
    await t.step("no Authorization header → 401", async () => {
      const res = await handler(post({ confirm: "DELETE" }));
      const json = await res.json();
      assertEquals(res.status, 401);
      assertEquals(json.error, "Not signed in");
    });

    // Deletion is irreversible, so an authenticated POST alone must never be
    // enough to trigger it.
    await t.step("missing confirmation → 400", async () => {
      const res = await handler(post({}, AUTH));
      const json = await res.json();
      assertEquals(res.status, 400);
      assertEquals(json.error, "Missing confirmation");
    });

    await t.step("wrong confirmation token → 400", async () => {
      const res = await handler(post({ confirm: "delete" }, AUTH));
      const json = await res.json();
      assertEquals(res.status, 400);
      assertEquals(json.error, "Missing confirmation");
    });

    await t.step("confirmation must be the exact string, not truthy", async () => {
      const res = await handler(post({ confirm: true }, AUTH));
      const json = await res.json();
      assertEquals(res.status, 400);
      assertEquals(json.error, "Missing confirmation");
    });
  } finally {
    clearEnv();
  }
});
