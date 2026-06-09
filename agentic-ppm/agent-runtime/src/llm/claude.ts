/**
 * Claude API client. REPLACES DOSv2's OpenRouter hot path
 * (`server/lib/OpenRouterClient.js` `callLLM` + `SmartModelRouter`).
 *
 * Locked decision: Claude API direct via @anthropic-ai/sdk. The `callLLM`
 * signature is kept deliberately compatible with DOSv2 so lifted call sites
 * (e.g. executiveInsights) need only swap the import.
 */
import Anthropic from '@anthropic-ai/sdk';
import { config } from '../config.js';

let client: Anthropic | null = null;

function getClient(): Anthropic {
  if (!client) {
    client = new Anthropic({ apiKey: config.claude.apiKey });
  }
  return client;
}

export interface LLMOptions {
  maxTokens?: number;
  temperature?: number;
  model?: string;
}

/**
 * Single-shot completion. Returns the concatenated text content.
 * Drop-in replacement for DOSv2 `callLLM(system, user, opts)`.
 */
export async function callLLM(
  systemPrompt: string,
  userPrompt: string,
  opts: LLMOptions = {},
): Promise<string> {
  const response = await getClient().messages.create({
    model: opts.model ?? config.claude.model,
    max_tokens: opts.maxTokens ?? 2000,
    temperature: opts.temperature ?? 0.2,
    system: systemPrompt,
    messages: [{ role: 'user', content: userPrompt }],
  });

  return response.content
    .filter((block): block is Anthropic.TextBlock => block.type === 'text')
    .map((block) => block.text)
    .join('');
}

/**
 * Completion that expects a JSON object back. Strips ```json fences and parses.
 * Mirrors the cleanup DOSv2 did inline in executiveInsights.
 */
export async function callLLMJson<T = unknown>(
  systemPrompt: string,
  userPrompt: string,
  opts: LLMOptions = {},
): Promise<T> {
  const text = await callLLM(systemPrompt, userPrompt, opts);
  const cleaned = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
  return JSON.parse(cleaned) as T;
}
