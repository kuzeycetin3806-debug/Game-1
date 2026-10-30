// The one place that talks to the Anthropic API.
import Anthropic from "@anthropic-ai/sdk";
import type { z } from "zod";

export class GenerationError extends Error {
  constructor(
    public readonly code: "refused" | "truncated" | "invalid_output" | "upstream" | "rate_limited" | "timeout",
    message: string,
  ) {
    super(message);
  }
}

/** Minimal surface of the SDK client we use; lets tests pass a fake. */
export interface MessagesClient {
  beta: { messages: { create: Anthropic["beta"]["messages"]["create"] } };
}

export interface GenerateOptions<T> {
  client: MessagesClient;
  model: string;
  system: string;
  data: unknown;
  jsonSchema: Record<string, unknown>;
  output: z.ZodType<T>;
  maxTokens?: number;
  timeoutMs?: number;
}

const BANNED = /https?:\/\/|www\.|[{}<>#*`]/;

export async function generate<T>(o: GenerateOptions<T>): Promise<T> {
  let response: Anthropic.Beta.BetaMessage;
  try {
    response = await o.client.beta.messages.create(
      {
        model: o.model,
        max_tokens: o.maxTokens ?? 2000,
        // Server-side refusal fallback: a declined request is retried on a suitable model.
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        // Short creative text: low effort keeps it fast and cheap without hurting quality.
        output_config: { effort: "low", format: { type: "json_schema", schema: o.jsonSchema } },
        system: [{ type: "text", text: o.system, cache_control: { type: "ephemeral" } }],
        messages: [{ role: "user", content: JSON.stringify(o.data) }],
      },
      { timeout: o.timeoutMs ?? 25_000, maxRetries: 1 },
    );
  } catch (err) {
    if (err instanceof Anthropic.RateLimitError) throw new GenerationError("rate_limited", err.message);
    if (err instanceof Anthropic.APIConnectionTimeoutError) throw new GenerationError("timeout", err.message);
    if (err instanceof Anthropic.APIError) throw new GenerationError("upstream", `${err.status ?? "?"} ${err.message}`);
    throw err;
  }
  if (response.stop_reason === "refusal") throw new GenerationError("refused", "model declined");
  if (response.stop_reason === "max_tokens") throw new GenerationError("truncated", "output hit max_tokens");
  const text = response.content
    .filter((b): b is Anthropic.Beta.BetaTextBlock => b.type === "text")
    .map((b) => b.text)
    .join("");
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new GenerationError("invalid_output", "not JSON");
  }
  const result = o.output.safeParse(parsed);
  if (!result.success) throw new GenerationError("invalid_output", result.error.issues.map((i) => i.message).join("; "));
  if (containsBanned(result.data)) throw new GenerationError("invalid_output", "banned characters");
  return result.data;
}

function containsBanned(v: unknown): boolean {
  if (typeof v === "string") return BANNED.test(v);
  if (Array.isArray(v)) return v.some(containsBanned);
  if (v && typeof v === "object") return Object.values(v).some(containsBanned);
  return false;
}
