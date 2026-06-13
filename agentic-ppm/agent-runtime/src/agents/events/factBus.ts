/**
 * Fact bus — the in-process channel agents use to tell each other things.
 *
 * WHAT: When an agent establishes a fact (e.g. "budget_variance = 120 on op-wp-7"),
 * it broadcasts it here. The bus (1) persists the fact to the memory layer best-
 * effort and (2) dispatches it ONLY to the agents that subscribe to that attribute
 * over the connection graph — subscribes_to / escalates_to / depends_on edges, or a
 * '*' (all-attributes) edge. No global fan-out.
 * WHY: This is the relevance-gated nervous system of the a2a engine. subscribersFor
 * is the gate; broadcastFact is the wire. Neither ever throws into the caller —
 * memory and dispatch are augmentation, never the critical path.
 */
import type { AgentFact } from '../domains/types.js';
import { AGENT_CONNECTIONS } from '../domains/index.js';
import { recordEpisode } from '../../memory/index.js';
import { normalizeAttr } from './relevance.js';

/** Connection types over which a fact about an attribute flows to a consumer. */
const CONSUMER_TYPES = new Set(['subscribes_to', 'escalates_to', 'depends_on']);

/** True when an edge's attribute list covers `attribute` ('*' = all, tolerant match). */
function edgeCovers(attributes: string[], attribute: string): boolean {
  if (attributes.includes('*')) return true;
  if (attributes.includes(attribute)) return true;
  const norm = normalizeAttr(attribute);
  return attributes.some((a) => normalizeAttr(a) === norm);
}

/**
 * The relevance gate for facts: agent ids that subscribe to `attribute`. Walks
 * AGENT_CONNECTIONS for consumer-type edges (and the bidirectional reverse) whose
 * attribute list covers the attribute. Deduped.
 */
export function subscribersFor(attribute: string): string[] {
  const subs = new Set<string>();
  for (const conn of AGENT_CONNECTIONS) {
    if (!CONSUMER_TYPES.has(conn.connectionType)) continue;
    if (!edgeCovers(conn.attributes, attribute)) continue;
    // fromAgent consumes the attribute from toAgent (it subscribes/depends/escalates).
    subs.add(conn.fromAgent);
    if (conn.bidirectional) subs.add(conn.toAgent);
  }
  return [...subs];
}

/**
 * Broadcast a fact: persist it (best-effort) and return the subscriber agent ids
 * the caller should notify next. Never throws.
 */
export async function broadcastFact(fact: AgentFact): Promise<void> {
  try {
    await recordEpisode({
      content: `${fact.byAgent} established ${fact.attribute}=${String(fact.value)} on ${fact.entity}`,
      source: 'a2a-fact-bus',
      occurredAt: fact.at ? new Date(fact.at) : undefined,
      subjectNodeId: fact.entity,
      metadata: {
        attribute: fact.attribute,
        value: fact.value as unknown,
        confidence: fact.confidence,
        byAgent: fact.byAgent,
        subscribers: subscribersFor(fact.attribute),
      },
    });
  } catch {
    // Memory is augmentation — a persist failure never breaks the cascade.
  }
}
