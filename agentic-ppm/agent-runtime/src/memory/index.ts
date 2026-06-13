/**
 * Memory facade — selects the provider from config.memory.provider and exposes a
 * stable API (recordEpisode / searchMemory / memoryStatus / closeMemory) to the
 * rest of the app. Swapping providers is one env var; no caller changes.
 */
import { config } from '../config.js';
import type { MemoryEpisode, MemoryHit, MemoryProvider, MemoryStatus } from './types.js';
import { FalkorMemoryProvider } from './falkor.js';
import { Mem0MemoryProvider } from './mem0.js';
import {
  recordEpisode as graphitiRecord,
  pingGraphiti,
  closeGraphiti,
} from '../graph/graphiti.js';

/** Graphiti kept as one optional provider (no longer the default). */
class GraphitiMemoryProvider implements MemoryProvider {
  readonly name = 'graphiti';
  async recordEpisode(ep: MemoryEpisode): Promise<void> {
    await graphitiRecord({ content: ep.content, source: ep.source, occurredAt: ep.occurredAt, metadata: ep.metadata });
  }
  async search(): Promise<MemoryHit[]> {
    return []; // recall via the Graphiti MCP search tools is a separate path; not used here
  }
  async status(): Promise<MemoryStatus> {
    const p = await pingGraphiti();
    return {
      provider: this.name,
      enabled: p.enabled,
      ok: p.enabled ? p.ok : true,
      detail: !p.enabled ? 'disabled (GRAPHITI_MCP_URL unset)' : p.ok ? `connected (${p.tools?.length ?? 0} tools)` : (p.error ?? 'connect failed'),
    };
  }
  async close(): Promise<void> {
    await closeGraphiti();
  }
}

class NullMemoryProvider implements MemoryProvider {
  readonly name = 'none';
  async recordEpisode(): Promise<void> {}
  async search(): Promise<MemoryHit[]> {
    return [];
  }
  async status(): Promise<MemoryStatus> {
    return { provider: this.name, enabled: false, ok: true, detail: 'memory disabled (MEMORY_PROVIDER=none)' };
  }
  async close(): Promise<void> {}
}

let provider: MemoryProvider | null = null;
function get(): MemoryProvider {
  if (provider) return provider;
  switch (config.memory.provider) {
    case 'mem0':
      provider = new Mem0MemoryProvider();
      break;
    case 'graphiti':
      provider = new GraphitiMemoryProvider();
      break;
    case 'none':
      provider = new NullMemoryProvider();
      break;
    case 'falkor':
    default:
      provider = new FalkorMemoryProvider();
  }
  return provider;
}

export type { MemoryEpisode, MemoryHit, MemoryStatus } from './types.js';

export function recordEpisode(episode: MemoryEpisode): Promise<void> {
  return get().recordEpisode(episode);
}
export function searchMemory(query: string, opts?: { subjectNodeId?: string; limit?: number }): Promise<MemoryHit[]> {
  return get().search(query, opts);
}
export function memoryStatus(): Promise<MemoryStatus> {
  return get().status();
}
export function closeMemory(): Promise<void> {
  return get().close();
}
