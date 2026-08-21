import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey",
};

// Buckets holding user content. The clothing bucket id really does contain a
// space and a capital letter — see ClothingStorage.bucket in the app. It is
// URL-encoded at the call site, never "cleaned".
const BUCKETS = ["Clothing images", "user-models", "avatars"];

// The caller must send this exactly. Deleting an account is irreversible and
// the endpoint is one POST away from any authenticated session, so an explicit
// confirmation token means a stray or replayed request cannot erase someone.
const CONFIRM_TOKEN = "DELETE";

interface Env {
  supabaseUrl: string;
  serviceKey: string;
}

export async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceKey) {
      console.error("[delete-account] not configured");
      return json({ error: "Server not configured" }, 500);
    }
    const env: Env = { supabaseUrl, serviceKey };

    const jwt = bearer(req.headers.get("Authorization"));
    if (!jwt) return json({ error: "Not signed in" }, 401);

    let confirm: unknown;
    try {
      confirm = (await req.json())?.confirm;
    } catch {
      return json({ error: "Invalid payload" }, 400);
    }
    if (confirm !== CONFIRM_TOKEN) {
      return json({ error: "Missing confirmation" }, 400);
    }

    const userId = await resolveUserId(jwt, env);
    if (!userId) return json({ error: "Not signed in" }, 401);

    // Photos first. If this fails we stop: an orphaned bucket full of someone's
    // body photos with no account left to trace them to is the worst outcome
    // here, so it is better to leave the account intact and let them retry.
    const storageOk = await purgeStorage(userId, env);
    if (!storageOk) {
      return json({ error: "Could not delete your images. Please try again." }, 500);
    }

    const rowsOk = await rpc("delete_account_data", { p_user_id: userId }, env);
    if (!rowsOk) {
      return json({ error: "Could not delete your data. Please try again." }, 500);
    }

    // Last, because it is the only step that cannot be retried once done: with
    // the auth user gone the caller can no longer prove who they were.
    const userOk = await deleteAuthUser(userId, env);
    if (!userOk) {
      return json({ error: "Could not close your account. Please try again." }, 500);
    }

    console.info("[delete-account] account deleted");
    return json({ status: "deleted" }, 200);
  } catch (err) {
    console.error("[delete-account]", err);
    return json({ error: String(err) }, 500);
  }
}

if (import.meta.main) serve(handler);

// ── storage ─────────────────────────────────────────────────────────────────

/// Deletes everything under `<userId>/` in every user-content bucket.
/// Returns false if any bucket could not be fully purged.
async function purgeStorage(userId: string, env: Env): Promise<boolean> {
  for (const bucket of BUCKETS) {
    try {
      const paths = await listAll(bucket, `${userId}/`, env);
      if (paths.length === 0) continue;

      // The API takes a list of exact object paths; chunked so a wardrobe with
      // hundreds of items does not produce one oversized request.
      for (let i = 0; i < paths.length; i += 100) {
        const chunk = paths.slice(i, i + 100);
        const res = await fetch(
          `${env.supabaseUrl}/storage/v1/object/${encodeURIComponent(bucket)}`,
          {
            method: "DELETE",
            headers: authHeaders(env),
            body: JSON.stringify({ prefixes: chunk }),
          },
        );
        if (!res.ok) {
          console.error("[delete-account] storage delete failed", bucket, res.status, await res.text());
          return false;
        }
        await res.body?.cancel();
      }
    } catch (err) {
      console.error("[delete-account] storage purge failed", bucket, err);
      return false;
    }
  }
  return true;
}

/// Recursively lists object paths under [prefix].
///
/// The list endpoint is one level deep and pages, and clothing images are
/// stored two levels down (`<user>/<category>/<file>`), so both recursion and
/// pagination are required to avoid silently leaving images behind.
async function listAll(bucket: string, prefix: string, env: Env): Promise<string[]> {
  const found: string[] = [];
  const pageSize = 100;
  let offset = 0;

  for (;;) {
    const res = await fetch(
      `${env.supabaseUrl}/storage/v1/object/list/${encodeURIComponent(bucket)}`,
      {
        method: "POST",
        headers: authHeaders(env),
        body: JSON.stringify({ prefix, limit: pageSize, offset }),
      },
    );
    if (!res.ok) {
      throw new Error(`list ${bucket} failed: ${res.status} ${await res.text()}`);
    }
    const entries = await res.json() as Array<{ name: string; id: string | null }>;
    if (entries.length === 0) break;

    for (const entry of entries) {
      const path = `${prefix}${entry.name}`;
      // A null id marks a folder rather than an object.
      if (entry.id === null) {
        found.push(...await listAll(bucket, `${path}/`, env));
      } else {
        found.push(path);
      }
    }

    if (entries.length < pageSize) break;
    offset += pageSize;
  }

  return found;
}

// ── supabase ────────────────────────────────────────────────────────────────

function authHeaders(env: Env): HeadersInit {
  return {
    "apikey": env.serviceKey,
    "Authorization": `Bearer ${env.serviceKey}`,
    "Content-Type": "application/json",
  };
}

async function resolveUserId(jwt: string, env: Env): Promise<string | null> {
  try {
    const res = await fetch(`${env.supabaseUrl}/auth/v1/user`, {
      headers: { "apikey": env.serviceKey, "Authorization": `Bearer ${jwt}` },
    });
    if (!res.ok) return null;
    const user = await res.json();
    return typeof user?.id === "string" ? user.id : null;
  } catch (err) {
    console.error("[delete-account] auth lookup failed", err);
    return null;
  }
}

async function rpc(
  fn: string,
  args: Record<string, unknown>,
  env: Env,
): Promise<boolean> {
  try {
    const res = await fetch(`${env.supabaseUrl}/rest/v1/rpc/${fn}`, {
      method: "POST",
      headers: authHeaders(env),
      body: JSON.stringify(args),
    });
    if (!res.ok) {
      console.error(`[delete-account] ${fn} failed`, res.status, await res.text());
      return false;
    }
    await res.body?.cancel();
    return true;
  } catch (err) {
    console.error(`[delete-account] ${fn} failed`, err);
    return false;
  }
}

async function deleteAuthUser(userId: string, env: Env): Promise<boolean> {
  try {
    const res = await fetch(`${env.supabaseUrl}/auth/v1/admin/users/${userId}`, {
      method: "DELETE",
      headers: authHeaders(env),
    });
    if (!res.ok) {
      console.error("[delete-account] auth delete failed", res.status, await res.text());
      return false;
    }
    await res.body?.cancel();
    return true;
  } catch (err) {
    console.error("[delete-account] auth delete failed", err);
    return false;
  }
}

// ── misc ────────────────────────────────────────────────────────────────────

function bearer(header: string | null): string | null {
  if (!header) return null;
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match ? match[1] : null;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
