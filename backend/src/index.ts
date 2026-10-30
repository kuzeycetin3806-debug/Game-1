import Anthropic from "@anthropic-ai/sdk";
import { handle, type Env } from "./handler";

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    // The key lives only here, as a Worker secret (wrangler secret put ANTHROPIC_API_KEY).
    const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });
    return handle(req, env, { client, now: () => new Date() });
  },
} satisfies ExportedHandler<Env>;
