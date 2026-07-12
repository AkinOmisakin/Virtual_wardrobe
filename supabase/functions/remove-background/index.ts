import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { Buffer } from "node:buffer";
import jpeg from "npm:jpeg-js@0.4.4";
import { PNG } from "npm:pngjs@7.0.0";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey",
};

// BiRefNet: MIT-licensed, HF-hosted segmentation model — no fal.ai billing.
// Request: binary image POST. Response: image segmentation JSON with base64 masks.
const HF_URL = "https://router.huggingface.co/hf-inference/models/ZhengPeng7/BiRefNet";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  try {
    const form = await req.formData();
    const file = form.get("image_file") as File | null;
    if (!file) {
      return new Response(
        JSON.stringify({ error: "Missing image_file field" }),
        { status: 400, headers: { ...CORS, "Content-Type": "application/json" } },
      );
    }

    const hfToken = Deno.env.get("HF_TOKEN") ?? "";
    const imageBytes = new Uint8Array(await file.arrayBuffer());

    const inputIsPng = imageBytes[0] === 0x89 && imageBytes[1] === 0x50 &&
      imageBytes[2] === 0x4E && imageBytes[3] === 0x47;
    const mimeType = inputIsPng ? "image/png" : "image/jpeg";

    console.log(`[remove-background] Input: ${mimeType}, ${imageBytes.length} bytes`);

    const hfRes = await fetch(HF_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${hfToken}`,
        "Content-Type": mimeType,
        "Accept": "image/png",
      },
      body: imageBytes,
    });

    if (hfRes.ok) {
      const ct = hfRes.headers.get("content-type") ?? "";
      const hfBytes = new Uint8Array(await hfRes.arrayBuffer());
      console.log(`[remove-background] HF OK — ct=${ct}, bytes=${hfBytes.length}, magic=[${hfBytes[0]},${hfBytes[1]},${hfBytes[2]},${hfBytes[3]}]`);

      // PNG returned directly (transparent, ready to crop).
      const isPng = hfBytes[0] === 0x89 && hfBytes[1] === 0x50 &&
                    hfBytes[2] === 0x4E && hfBytes[3] === 0x47;
      if (isPng) {
        const cropped = cropTransparent(hfBytes);
        return new Response(cropped, { headers: { ...CORS, "Content-Type": "image/png" } });
      }

      // JSON segmentation mask — composite foreground onto transparent canvas.
      const isJson = hfBytes[0] === 0x7B || hfBytes[0] === 0x5B;
      if (isJson) {
        type Segment = { score: number; label: string; mask: string };
        const segments = JSON.parse(new TextDecoder().decode(hfBytes)) as Segment[];
        const subject =
          segments.find((s) => !s.label.toLowerCase().includes("background")) ??
          segments[0];
        console.log(`[remove-background] ${segments.length} segment(s), using "${subject?.label}"`);

        if (subject?.mask) {
          const maskBytes = Uint8Array.from(atob(subject.mask), (c) => c.charCodeAt(0));
          const composited = await compositeWithMask(imageBytes, maskBytes, mimeType);
          if (composited) {
            const cropped = cropTransparent(composited);
            return new Response(cropped, { headers: { ...CORS, "Content-Type": "image/png" } });
          }
        }
      }

      console.warn(`[remove-background] Unrecognised HF body (ct=${ct})`);
    } else {
      console.error("[remove-background] HF error", hfRes.status, await hfRes.text());
    }

    return new Response(imageBytes, {
      headers: { ...CORS, "Content-Type": mimeType },
    });
  } catch (err) {
    console.error("[remove-background]", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...CORS, "Content-Type": "application/json" } },
    );
  }
});

// Applies a grayscale mask PNG as the alpha channel of the original image.
// Mask convention: white (255) = keep, black (0) = transparent.
async function compositeWithMask(
  imgBytes: Uint8Array,
  maskBytes: Uint8Array,
  mimeType: string,
): Promise<Uint8Array | null> {
  try {
    let width: number, height: number, rgbaData: Uint8Array;

    if (mimeType === "image/jpeg" || mimeType === "image/jpg") {
      const decoded = jpeg.decode(Buffer.from(imgBytes), { useTArray: true });
      width = decoded.width;
      height = decoded.height;
      rgbaData = decoded.data;
    } else {
      const src = PNG.sync.read(Buffer.from(imgBytes));
      width = src.width;
      height = src.height;
      rgbaData = src.data;
    }

    const maskPng = PNG.sync.read(Buffer.from(maskBytes));
    const out = new PNG({ width, height });
    out.data = Buffer.alloc(width * height * 4, 0);

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const idx = (y * width + x) * 4;
        const mx = Math.round(x * (maskPng.width - 1) / Math.max(width - 1, 1));
        const my = Math.round(y * (maskPng.height - 1) / Math.max(height - 1, 1));
        const mi = (my * maskPng.width + mx) * 4;
        out.data[idx]     = rgbaData[idx];
        out.data[idx + 1] = rgbaData[idx + 1];
        out.data[idx + 2] = rgbaData[idx + 2];
        out.data[idx + 3] = maskPng.data[mi];
      }
    }

    const buf = PNG.sync.write(out);
    return new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength);
  } catch (err) {
    console.error("[compositeWithMask]", err);
    return null;
  }
}

// Crops the transparent PNG to the bounding box of non-transparent pixels.
// Returns the original bytes unchanged if decoding fails or image is opaque.
function cropTransparent(bytes: Uint8Array): Uint8Array {
  try {
    const png = PNG.sync.read(Buffer.from(bytes));
    const { width, height, data } = png;

    let minX = width, minY = height, maxX = 0, maxY = 0;
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        if (data[(y * width + x) * 4 + 3] > 10) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX < minX || maxY < minY) return bytes; // fully transparent

    // 8-pixel padding so the item doesn't clip at the edges
    const pad = 8;
    minX = Math.max(0, minX - pad);
    minY = Math.max(0, minY - pad);
    maxX = Math.min(width - 1, maxX + pad);
    maxY = Math.min(height - 1, maxY + pad);

    const w = maxX - minX + 1;
    const h = maxY - minY + 1;
    const out = new PNG({ width: w, height: h });
    out.data = Buffer.alloc(w * h * 4, 0);

    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const src = ((y + minY) * width + (x + minX)) * 4;
        const dst = (y * w + x) * 4;
        out.data[dst]     = data[src];
        out.data[dst + 1] = data[src + 1];
        out.data[dst + 2] = data[src + 2];
        out.data[dst + 3] = data[src + 3];
      }
    }

    const buf = PNG.sync.write(out);
    console.log(`[cropTransparent] ${width}x${height} → ${w}x${h}`);
    return new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength);
  } catch (e) {
    console.error("[cropTransparent] failed, returning uncropped:", e);
    return bytes;
  }
}
