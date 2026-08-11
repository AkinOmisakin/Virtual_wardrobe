import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { encodeBase64 } from "https://deno.land/std@0.208.0/encoding/base64.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey",
};

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const MODEL = "claude-haiku-4-5-20251001";

const PROMPT = `You are a fashion tagging assistant.
Analyse this clothing item image and respond ONLY with a valid JSON object — no markdown, no explanation, just raw JSON.

Return exactly this structure:
{
  "type": "<one of: top | trouser | outwear | dress | shoe | accessory | headwear>",
  "colours": ["<primary colour>", "<secondary colour if present>"],
  "tags": ["<tag1>", "<tag2>", "<tag3>"],
  "style": "<one short style label e.g. casual | formal | streetwear | athleisure | minimalist | vintage | preppy>",
  "description": "<one sentence describing the item>"
}

Rules:
- colours: use simple English colour names (e.g. "navy blue", "off-white")
- tags: 2-5 short lowercase words (material, occasion, season, fit, etc.)
- style: single word or short phrase
- description: max 15 words, factual`;

export async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  try {
    const key = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
    if (!key) {
      console.error("[tag-clothing] ANTHROPIC_API_KEY not configured");
      return json({ error: "Server not configured" }, 500);
    }

    const form = await req.formData();
    const file = form.get("image_file") as File | null;
    if (!file) return json({ error: "Missing image_file field" }, 400);

    const bytes = new Uint8Array(await file.arrayBuffer());

    // Detect mime from magic bytes — the caller's .png-named file may actually
    // hold JPEG bytes when background removal fell back to the original image.
    const isPng = bytes[0] === 0x89 && bytes[1] === 0x50 &&
                  bytes[2] === 0x4E && bytes[3] === 0x47;
    const mediaType = isPng ? "image/png" : "image/jpeg";

    console.log(`[tag-clothing] Input: ${mediaType}, ${bytes.length} bytes`);

    const anthropicRes = await fetch(ANTHROPIC_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 256,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: { type: "base64", media_type: mediaType, data: encodeBase64(bytes) },
              },
              { type: "text", text: PROMPT },
            ],
          },
        ],
      }),
    });

    if (!anthropicRes.ok) {
      const body = await anthropicRes.text();
      console.error(`[tag-clothing] Claude error ${anthropicRes.status}: ${body}`);
      return json({ error: "Tagging failed" }, 502);
    }

    const decoded = await anthropicRes.json();
    const rawText: string = decoded?.content?.[0]?.text ?? "";

    // Strip any accidental markdown fences before parsing.
    const jsonText = rawText
      .replace(/```json\s*/g, "")
      .replace(/```\s*/g, "")
      .trim();

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(jsonText);
    } catch {
      console.error("[tag-clothing] Could not parse Claude output:", jsonText);
      return json({ error: "Malformed tagging response" }, 502);
    }

    console.log("[tag-clothing] tags:", parsed);
    return json(parsed, 200);
  } catch (err) {
    console.error("[tag-clothing]", err);
    return json({ error: String(err) }, 500);
  }
}

// Only start the server when run directly (not when imported by a test).
if (import.meta.main) serve(handler);

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
