/**
 * Letta integration — hosts the 9 roster agents as stateful Letta agents,
 * powered by Claude (config.letta.model). Built on the official @letta-ai SDK so
 * the API surface is real, not hand-rolled (lesson learned from Graphiti).
 *
 * Two things live here:
 *  - provisionRosterAgents(): idempotently create one Letta agent per roster
 *    entry, with the agent's purpose as its persona memory block.
 *  - ensureMemoryAgent(): a single shared agent whose archival memory backs the
 *    LettaMemoryProvider (episodic memory across the system).
 *
 * Everything degrades gracefully: if Letta isn't configured/reachable, callers
 * get sensible no-ops rather than crashes.
 */
import { Letta } from '@letta-ai/letta-client';
import { config } from '../config.js';
import { AGENT_ROSTER } from '../agents/roster.js';

let client: Letta | null = null;
export function getLetta(): Letta {
  if (!client) {
    client = new Letta({ apiKey: config.letta.apiKey ?? undefined, baseURL: config.letta.baseUrl });
  }
  return client;
}

export function lettaConfigured(): boolean {
  return config.letta.configured;
}

/** Find an agent we own by name (tagged with our tag). */
async function findAgentByName(name: string): Promise<string | null> {
  try {
    const page = await getLetta().agents.list({ name, tags: [config.letta.tag] });
    for await (const a of page) {
      if (a.name === name) return a.id;
    }
  } catch {
    /* fall through */
  }
  return null;
}

async function createAgent(opts: {
  name: string;
  persona: string;
  human?: string;
}): Promise<string | null> {
  try {
    const agent = await getLetta().agents.create({
      name: opts.name,
      model: config.letta.model,
      embedding: config.letta.embedding,
      tags: [config.letta.tag],
      memory_blocks: [
        { label: 'persona', value: opts.persona },
        { label: 'human', value: opts.human ?? 'A project portfolio manager using OpenProject.' },
      ],
    });
    return agent.id;
  } catch (err: any) {
    console.warn(`[letta] create agent "${opts.name}" failed: ${err.message}`);
    return null;
  }
}

function personaFor(a: { name: string; domain: string; purpose: string }): string {
  return (
    `You are the ${a.name} for an enterprise project portfolio in OpenProject.\n` +
    `Domain: ${a.domain}. Purpose: ${a.purpose}\n` +
    `You watch the portfolio graph, remember what changes over time, and raise ` +
    `concise, evidence-based findings and recommendations for human review.`
  );
}

/** Idempotently provision a Letta agent for each roster entry. Returns id map. */
export async function provisionRosterAgents(
  log: (m: string) => void = () => {},
): Promise<Record<string, string>> {
  const ids: Record<string, string> = {};
  for (const a of AGENT_ROSTER) {
    const name = `agentic-ppm-${a.id}`;
    let id = await findAgentByName(name);
    if (id) {
      log(`exists: ${a.name} (${id})`);
    } else {
      id = await createAgent({ name, persona: personaFor(a) });
      log(id ? `created: ${a.name} (${id})` : `FAILED: ${a.name}`);
    }
    if (id) ids[a.id] = id;
  }
  return ids;
}

const rosterAgentIds = new Map<string, string>();
/** Resolve a roster agent's Letta id (auto-provisioning it once if missing). */
export async function getRosterAgentId(rosterId: string): Promise<string | null> {
  if (!lettaConfigured()) return null;
  if (rosterAgentIds.has(rosterId)) return rosterAgentIds.get(rosterId)!;
  const a = AGENT_ROSTER.find((x) => x.id === rosterId);
  if (!a) return null;
  const name = `agentic-ppm-${a.id}`;
  const id = (await findAgentByName(name)) ?? (await createAgent({ name, persona: personaFor(a) }));
  if (id) rosterAgentIds.set(rosterId, id);
  return id;
}

let memoryAgentId: string | null = null;
/** A shared agent whose archival memory is the episodic store for the memory provider. */
export async function ensureMemoryAgent(): Promise<string | null> {
  if (memoryAgentId) return memoryAgentId;
  const name = 'agentic-ppm-memory';
  memoryAgentId =
    (await findAgentByName(name)) ??
    (await createAgent({
      name,
      persona: 'You are the shared temporal memory of the Agentic PPM system. You store and recall episodes about the portfolio.',
    }));
  return memoryAgentId;
}

/** Send a message to a roster agent and return its reply text. */
export async function sendToAgent(agentId: string, content: string): Promise<string> {
  try {
    const res = await getLetta().agents.messages.create(agentId, {
      messages: [{ role: 'user', content }],
    });
    const parts = (res.messages ?? [])
      .map((m: any) => (m.messageType === 'assistant_message' || m.message_type === 'assistant_message' ? m.content : ''))
      .filter(Boolean);
    return parts.join('\n');
  } catch (err: any) {
    console.warn(`[letta] sendToAgent failed: ${err.message}`);
    return '';
  }
}
