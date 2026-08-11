import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { handler } from "./index.ts";

const URL = "http://localhost/tag-clothing";

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

Deno.test("returns 500 when the API key is not configured", async () => {
  Deno.env.delete("ANTHROPIC_API_KEY");
  const body = new FormData();
  body.append("image_file", new Blob([new Uint8Array([1, 2, 3])]), "x.png");
  const res = await handler(new Request(URL, { method: "POST", body }));
  const json = await res.json();
  assertEquals(res.status, 500);
  assertEquals(json.error, "Server not configured");
});

Deno.test("returns 400 when image_file is missing", async () => {
  Deno.env.set("ANTHROPIC_API_KEY", "test-key");
  try {
    const res = await handler(
      new Request(URL, { method: "POST", body: new FormData() }),
    );
    const json = await res.json();
    assertEquals(res.status, 400);
    assertEquals(json.error, "Missing image_file field");
  } finally {
    Deno.env.delete("ANTHROPIC_API_KEY");
  }
});
