/**
 * FalkorDB-native memory provider (the default).
 *
 * Temporal memory without a separate service: each episode is an (:Episode) node
 * in the same FalkorDB the agent already uses, linked to the work item it concerns
 * via [:ABOUT]. Recall is plain Cypher — episodes about a node, newest first, or a
 * text match. Nothing to deploy, nothing to be "on or off".
 */
import { getGraph } from '../graph/falkor.js';
import type { MemoryEpisode, MemoryHit, MemoryProvider, MemoryStatus } from './types.js';

let counter = 0;
function episodeId(): string {
  return `ep-${Date.now()}-${(counter++).toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

export class FalkorMemoryProvider implements MemoryProvider {
  readonly name = 'falkor';

  async recordEpisode(episode: MemoryEpisode): Promise<void> {
    const graph = getGraph();
    const id = episodeId();
    const occurredAt = (episode.occurredAt ?? new Date()).toISOString();
    try {
      await graph.query(
        `CREATE (e:Episode {
           id: $id, content: $content, source: $source, occurredAt: $occurredAt,
           metadata: $metadata
         })`,
        {
          id,
          content: episode.content,
          source: episode.source,
          occurredAt,
          metadata: episode.metadata ? JSON.stringify(episode.metadata) : '',
        },
      );
      if (episode.subjectNodeId) {
        await graph.query(
          `MATCH (e:Episode { id: $id }), (n { id: $nodeId }) MERGE (e)-[:ABOUT]->(n)`,
          { id, nodeId: episode.subjectNodeId },
        );
      }
    } catch (err: any) {
      console.warn(`[memory:falkor] recordEpisode failed: ${err.message}`);
    }
  }

  async search(query: string, opts?: { subjectNodeId?: string; limit?: number }): Promise<MemoryHit[]> {
    const graph = getGraph();
    const limit = Math.min(opts?.limit ?? 20, 100);
    try {
      const rows = opts?.subjectNodeId
        ? await graph.query<{ content: string; occurredAt: string; source: string }>(
            `MATCH (e:Episode)-[:ABOUT]->(n { id: $nodeId })
             RETURN e.content AS content, e.occurredAt AS occurredAt, e.source AS source
             ORDER BY e.occurredAt DESC LIMIT ${limit}`,
            { nodeId: opts.subjectNodeId },
          )
        : await graph.query<{ content: string; occurredAt: string; source: string }>(
            `MATCH (e:Episode) WHERE e.content CONTAINS $q
             RETURN e.content AS content, e.occurredAt AS occurredAt, e.source AS source
             ORDER BY e.occurredAt DESC LIMIT ${limit}`,
            { q: query },
          );
      return rows.map((r) => ({ content: r.content, occurredAt: r.occurredAt, source: r.source }));
    } catch (err: any) {
      console.warn(`[memory:falkor] search failed: ${err.message}`);
      return [];
    }
  }

  async status(): Promise<MemoryStatus> {
    try {
      const rows = await getGraph().query<{ c: number }>('MATCH (e:Episode) RETURN count(e) AS c');
      const c = rows[0]?.c ?? 0;
      return { provider: this.name, enabled: true, ok: true, detail: `native FalkorDB episodes (${c} recorded)` };
    } catch (err: any) {
      return { provider: this.name, enabled: true, ok: false, detail: err.message };
    }
  }

  async close(): Promise<void> {
    /* shares the FalkorDB singleton; nothing to close here */
  }
}
