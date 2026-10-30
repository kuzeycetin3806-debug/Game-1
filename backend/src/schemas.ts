// Request/response contracts. The game sends structured facts only; free text
// from players never reaches the model (replies are preset options).
import { z } from "zod";

const Lang = z.enum(["tr", "en"]);
const ShortText = z.string().max(200);
const Name = z.string().min(1).max(40);
const Key = z.string().regex(/^[a-z0-9_.:]{1,60}$/);

const Stats = z
  .object({
    population: z.number().int().min(0).max(10_000_000),
    happiness: z.number().int().min(0).max(1000),
    traffic: z.number().int().min(0).max(1000),
    money: z.number().int().min(-1_000_000_000).max(1_000_000_000),
  })
  .strict();

const City = z
  .object({
    name: Name,
    date: z.string().max(60),
    season: z.enum(["spring", "summer", "autumn", "winter"]),
    weather: z.enum(["clear", "cloudy", "rain", "storm", "fog", "snow"]),
    stats: Stats,
  })
  .strict();

const Facts = z.record(z.string().regex(/^[a-z_]{1,30}$/), z.union([ShortText, z.number()])).refine(
  (r) => Object.keys(r).length <= 8,
  "too many facts",
);

export const NewspaperRequest = z
  .object({
    lang: Lang,
    edition: z.number().int().min(1).max(1_000_000),
    city: City,
    stories: z
      .array(
        z
          .object({
            key: Key,
            count: z.number().int().min(1).max(50),
            facts: Facts,
            // The template text the game would show; the model rewrites it, keeping the facts.
            template_title: ShortText,
            template_body: z.string().max(600),
          })
          .strict(),
      )
      .min(1)
      .max(6),
  })
  .strict();
export type NewspaperRequest = z.infer<typeof NewspaperRequest>;

export const LetterRequest = z
  .object({
    lang: Lang,
    letter_id: z.number().int().min(1),
    city: City,
    citizen: z
      .object({
        first: Name,
        last: Name,
        age: z.number().int().min(16).max(110),
        occupation: Name,
        district: z.string().max(40),
        traits: z.record(z.enum(["civic", "eco", "thrift", "social", "patience"]), z.number().int().min(0).max(100)),
        interests: z.array(z.string().regex(/^[a-z_]{1,20}$/)).max(6),
        mood: z.number().int().min(-100).max(100),
      })
      .strict(),
    topic: Key,
    tone: z.enum(["complaint", "request", "thanks", "invitation"]),
    memory: z.string().max(200).optional(),
    template_subject: ShortText,
    template_body: z.string().max(600),
    // Labels of the preset replies; the letter should make them sensible answers.
    options: z.array(ShortText).min(1).max(4),
  })
  .strict();
export type LetterRequest = z.infer<typeof LetterRequest>;

// --- Model outputs (validated again after the JSON schema constraint) ---

export const NewspaperOutput = z
  .object({
    stories: z.array(z.object({ key: Key, title: z.string().min(3).max(90), body: z.string().min(10).max(520) }).strict()),
  })
  .strict();
export type NewspaperOutput = z.infer<typeof NewspaperOutput>;

export const LetterOutput = z
  .object({
    subject: z.string().min(3).max(70),
    greeting: z.string().min(2).max(40),
    body: z.string().min(20).max(700),
    signoff: z.string().min(2).max(40),
  })
  .strict();
export type LetterOutput = z.infer<typeof LetterOutput>;

// JSON schemas for output_config.format (lengths are re-checked with zod above).
export const NEWSPAPER_JSON_SCHEMA = {
  type: "object",
  properties: {
    stories: {
      type: "array",
      items: {
        type: "object",
        properties: { key: { type: "string" }, title: { type: "string" }, body: { type: "string" } },
        required: ["key", "title", "body"],
        additionalProperties: false,
      },
    },
  },
  required: ["stories"],
  additionalProperties: false,
} as const;

export const LETTER_JSON_SCHEMA = {
  type: "object",
  properties: {
    subject: { type: "string" },
    greeting: { type: "string" },
    body: { type: "string" },
    signoff: { type: "string" },
  },
  required: ["subject", "greeting", "body", "signoff"],
  additionalProperties: false,
} as const;
