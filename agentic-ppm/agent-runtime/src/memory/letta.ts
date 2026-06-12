/**
 * Letta memory provider — episodic memory backed by a shared Letta agent's
 * archival memory (passages). Enables MEMORY_PROVIDER=letta.
 */
import { getLetta, ensureMemoryAgent, lettaConfigured } from '../letta/client.js';
import { config } from '../config.js';
import type { MemoryEpisode, MemoryHit, MemoryProvider, MemoryStatus } from './types.js';

export class LettaMemoryProvider implements MemoryProvider {
  readonly name = 'letta';

  async recordEpisode(episode: MemoryEpisode): Promise<void> {
    if (!lettaConfigured()) return;
    const agentId = await ensureMemoryAgent();
    if (!agentId) return;
    const occurredAt = (episode.occurredAt ?? new Date()).toISOString();
    const text =
      `[${occurredAt}] (${episode.source}) ${episode.content}` +
      (episode.metadata ? `\n${JSON.stringify(episode.metadata)}` : '');
    const tags = [config.letta.tag, episode.source];
    if (episode.subjectNodeId) tags.push(episode.subjectNodeId);
    try {
      await getLetta().agents.passages.create(agentId, { text, tags });
    } catch (err: any) {
      console.warn(`[memory:letta] recordEpisode failed: ${err.message}`);
    }
  }

  async search(query: string, opts?: { subjectNodeId?: string; limit?: number }): Promise<MemoryHit[]> {
    if (!lettaConfigured()) return [];
    const agentId = await ensureMemoryAgent();
    if (!agentId) return [];
    try {
      const res = await getLetta().agents.passages.search(agentId, {
        query,
        tags: opts?.subjectNodeId ? [opts.subjectNodeId] : undefined,
      } as any);
      const items = (Array.isArray(res) ? res : (res as any)?.results ?? []) as { text?: string; score?: number }[];
      return items.slice(0, opts?.limit ?? 20).map((p) => ({ content: p.text ?? '', score: p.score }));
    } catch (err: any) {
      console.warn(`[memory:letta] search failed: ${err.message}`);
      return [];
    }
  }

  async status(): Promise<MemoryStatus> {
    if (!lettaConfigured()) {
      return { provider: this.name, enabled: false, ok: false, detail: 'LETTA_API_KEY / LETTA_BASE_URL not set' };
    }
    return { provider: this.name, enabled: true, ok: true, detail: `Letta (${config.letta.baseUrl}, model ${config.letta.model})` };
  }

  async close(): Promise<void> {
    /* stateless HTTP */
  }
}
