/**
 * Mem0 memory provider (managed API).
 *
 * Uses the hosted Mem0 platform (https://mem0.ai) so there's no service to run.
 * Set MEM0_API_KEY to enable. Talks the simple REST API directly (add / search),
 * no SDK dependency.
 */
import { config } from '../config.js';
import type { MemoryEpisode, MemoryHit, MemoryProvider, MemoryStatus } from './types.js';

export class Mem0MemoryProvider implements MemoryProvider {
  readonly name = 'mem0';
  private readonly base = config.memory.mem0BaseUrl.replace(/\/$/, '');

  private headers(): Record<string, string> {
    return {
      Authorization: `Token ${config.memory.mem0ApiKey}`,
      'Content-Type': 'application/json',
    };
  }

  async recordEpisode(episode: MemoryEpisode): Promise<void> {
    if (!config.memory.mem0ApiKey) return;
    try {
      const res = await fetch(`${this.base}/v1/memories/`, {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({
          messages: [{ role: 'user', content: episode.content }],
          agent_id: config.memory.mem0AgentId,
          metadata: {
            source: episode.source,
            subjectNodeId: episode.subjectNodeId,
            occurredAt: (episode.occurredAt ?? new Date()).toISOString(),
            ...episode.metadata,
          },
        }),
      });
      if (!res.ok) console.warn(`[memory:mem0] add ${res.status}: ${await res.text()}`);
    } catch (err: any) {
      console.warn(`[memory:mem0] recordEpisode failed: ${err.message}`);
    }
  }

  async search(query: string, opts?: { limit?: number }): Promise<MemoryHit[]> {
    if (!config.memory.mem0ApiKey) return [];
    try {
      const res = await fetch(`${this.base}/v1/memories/search/`, {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({ query, agent_id: config.memory.mem0AgentId, limit: opts?.limit ?? 20 }),
      });
      if (!res.ok) return [];
      const data = (await res.json()) as { results?: { memory?: string; score?: number; created_at?: string }[] };
      return (data.results ?? []).map((r) => ({ content: r.memory ?? '', score: r.score, occurredAt: r.created_at }));
    } catch (err: any) {
      console.warn(`[memory:mem0] search failed: ${err.message}`);
      return [];
    }
  }

  async status(): Promise<MemoryStatus> {
    if (!config.memory.mem0ApiKey) {
      return { provider: this.name, enabled: false, ok: false, detail: 'MEM0_API_KEY not set' };
    }
    return { provider: this.name, enabled: true, ok: true, detail: `Mem0 managed API (${this.base})` };
  }

  async close(): Promise<void> {
    /* stateless HTTP */
  }
}
