// Runs the real Worker handler on a local port with a FAKE model, for
// end-to-end checks against the game without an API key or network.
//   npx tsx scripts/local-fake.ts 8787
import { createServer } from "node:http";
import { handle, type Env } from "../src/handler";

class MemoryKV {
  data = new Map<string, string>();
  async get(k: string) { return this.data.get(k) ?? null; }
  async put(k: string, v: string) { this.data.set(k, v); }
}

const fakeClient = {
  beta: {
    messages: {
      async create(params: any) {
        const req = JSON.parse(params.messages[0].content);
        const text = req.stories
          ? JSON.stringify({
              stories: req.stories.map((s: any) => ({
                key: s.key,
                title: "Yerel muhabirimiz bildiriyor: " + s.template_title.slice(0, 40),
                body: "Bu haber yerel test sunucusunda yazıldı. " + s.template_body.slice(0, 300),
              })),
            })
          : JSON.stringify({
              subject: "Sevgili Başkanım, bir ricam var",
              greeting: req.citizen.age >= 50 ? "Sayın Başkanım," : "Merhaba Başkanım,",
              body: `Ben ${req.citizen.first}, ${req.citizen.district} Mahallesi'nden yazıyorum. Bu mektup yerel test sunucusundan geliyor ve şablon metnin yerini aldı.`,
              signoff: "Sevgilerimle,",
            });
        return { content: [{ type: "text", text }], stop_reason: "end_turn" };
      },
    },
  },
};

const env: Env = { ANTHROPIC_API_KEY: "unused", MODEL: "fake", DAILY_LIMIT: "1000", RATE: new MemoryKV() as any, CACHE: new MemoryKV() as any };
const port = Number(process.argv[2] ?? 8787);
createServer(async (req, res) => {
  const chunks: Buffer[] = [];
  for await (const c of req) chunks.push(c as Buffer);
  const r = await handle(
    new Request(`http://localhost:${port}${req.url}`, { method: req.method, headers: req.headers as any, body: req.method === "POST" ? Buffer.concat(chunks) : undefined }),
    env,
    { client: fakeClient as any, now: () => new Date() },
  );
  res.writeHead(r.status, Object.fromEntries(r.headers));
  res.end(await r.text());
  console.log(req.method, req.url, r.status);
}).listen(port, () => console.log(`fake backend on :${port}`));
