// HTTP layer: validation, per-device rate limit, response cache, error mapping.
import { z } from "zod";
import { generate, GenerationError, type MessagesClient } from "./llm";
import { LETTER_SYSTEM, NEWSPAPER_SYSTEM } from "./prompts";
import {
  LETTER_JSON_SCHEMA,
  LetterOutput,
  LetterRequest,
  NEWSPAPER_JSON_SCHEMA,
  NewspaperOutput,
  NewspaperRequest,
} from "./schemas";

export interface Env {
  ANTHROPIC_API_KEY: string;
  MODEL?: string;
  DAILY_LIMIT?: string;
  CACHE_TTL?: string;
  RATE: KVNamespace;
  CACHE: KVNamespace;
}

export interface Deps {
  client: MessagesClient;
  now: () => Date;
}

const DEFAULT_MODEL = "claude-opus-5-5";
const DEVICE_ID = /^[0-9a-f]{32}$/;
const MAX_BODY_BYTES = 16_384;

export async function handle(req: Request, env: Env, deps: Deps): Promise<Response> {
  const url = new URL(req.url);
  if (req.method === "GET" && url.pathname === "/v1/health") return json({ ok: true });
  if (req.method !== "POST") return error(405, "method_not_allowed");
  const route = ROUTES[url.pathname];
  if (!route) return error(404, "not_found");

  const device = req.headers.get("x-device-id") ?? "";
  if (!DEVICE_ID.test(device)) return error(401, "device_id_required");

  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) return error(413, "too_large");
  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    return error(400, "invalid_json");
  }
  const parsed = route.request.safeParse(body);
  if (!parsed.success) return error(400, "invalid_request", parsed.error.issues.slice(0, 5).map((i) => i.path.join(".") + ": " + i.message));

  const model = env.MODEL || DEFAULT_MODEL;
  const cacheKey = await sha256(`${url.pathname}\n${model}\n${stableStringify(parsed.data)}`);
  const cached = await env.CACHE.get(cacheKey);
  if (cached) return new Response(cached, { headers: { "content-type": "application/json", "x-cache": "hit" } });

  // Cache hits are free; only generations count against the device's daily budget.
  const limit = Number(env.DAILY_LIMIT ?? "60");
  const day = deps.now().toISOString().slice(0, 10);
  const rateKey = `rl:${device}:${day}`;
  const used = Number((await env.RATE.get(rateKey)) ?? "0");
  if (used >= limit) return error(429, "daily_limit");
  await env.RATE.put(rateKey, String(used + 1), { expirationTtl: 2 * 86400 });

  try {
    const out = await route.generate(deps.client, model, parsed.data);
    const text = JSON.stringify(out);
    await env.CACHE.put(cacheKey, text, { expirationTtl: Number(env.CACHE_TTL ?? "2592000") });
    return new Response(text, { headers: { "content-type": "application/json", "x-cache": "miss" } });
  } catch (err) {
    if (err instanceof GenerationError) {
      // The game falls back to its own templates on any non-200.
      const status = err.code === "rate_limited" ? 503 : err.code === "timeout" ? 504 : 502;
      console.warn(`generation failed: ${err.code}: ${err.message}`);
      return error(status, err.code);
    }
    console.error("unexpected error", err);
    return error(500, "internal");
  }
}

interface Route<Req, Out> {
  request: z.ZodType<Req>;
  generate: (client: MessagesClient, model: string, req: Req) => Promise<Out>;
}

const newspaperRoute: Route<NewspaperRequest, NewspaperOutput> = {
  request: NewspaperRequest,
  async generate(client, model, req) {
    const out = await generate({
      client,
      model,
      system: NEWSPAPER_SYSTEM,
      data: req,
      jsonSchema: NEWSPAPER_JSON_SCHEMA,
      output: NewspaperOutput,
      maxTokens: 3000,
    });
    // Keep only stories we asked for, in our order; the game fills any gap from templates.
    const byKey = new Map(out.stories.map((s) => [s.key, s]));
    return { stories: req.stories.flatMap((s) => (byKey.has(s.key) ? [byKey.get(s.key)!] : [])) };
  },
};

const letterRoute: Route<LetterRequest, LetterOutput> = {
  request: LetterRequest,
  generate: (client, model, req) =>
    generate({
      client,
      model,
      system: LETTER_SYSTEM,
      data: req,
      jsonSchema: LETTER_JSON_SCHEMA,
      output: LetterOutput,
      maxTokens: 2000,
    }),
};

const ROUTES: Record<string, Route<any, any>> = {
  "/v1/newspaper": newspaperRoute,
  "/v1/letter": letterRoute,
};

function json(v: unknown, status = 200): Response {
  return new Response(JSON.stringify(v), { status, headers: { "content-type": "application/json" } });
}

function error(status: number, code: string, details?: string[]): Response {
  return json({ error: code, ...(details ? { details } : {}) }, status);
}

/** JSON with sorted keys, so equal requests share a cache entry. */
export function stableStringify(v: unknown): string {
  if (Array.isArray(v)) return `[${v.map(stableStringify).join(",")}]`;
  if (v && typeof v === "object") {
    const o = v as Record<string, unknown>;
    return `{${Object.keys(o)
      .sort()
      .map((k) => `${JSON.stringify(k)}:${stableStringify(o[k])}`)
      .join(",")}}`;
  }
  return JSON.stringify(v);
}

async function sha256(s: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
