/**
 * Pluggable agent-memory layer.
 *
 * Memory is an interface with swappable providers. Default is `falkor` — temporal
 * episodes stored as nodes in the FalkorDB we already run (no extra service to
 * babysit). `mem0` (managed API) remains an option; `none` disables it.
 *
 * Memory is augmentation, never the critical path: every provider degrades to a
 * no-op on error so the pipeline keeps running.
 */
export interface MemoryEpisode {
  /** What happened, e.g. 'Story "Login" (#42) moved to At Risk'. */
  content: string;
  /** Origin system, e.g. 'openproject', 'jira'. */
  source: string;
  /** When the event occurred (defaults to now). */
  occurredAt?: Date;
  /** Graph node the episode is about, e.g. 'op-wp-42' (enables per-entity recall). */
  subjectNodeId?: string;
  /** Arbitrary structured payload. */
  metadata?: Record<string, unknown>;
}

export interface MemoryHit {
  content: string;
  occurredAt?: string;
  source?: string;
  score?: number;
}

export interface MemoryStatus {
  /** Provider name: falkor | mem0 | none. */
  provider: string;
  /** Whether memory is configured to be active at all. */
  enabled: boolean;
  /** Whether it is reachable/healthy right now. */
  ok: boolean;
  /** Human-readable detail for the console health pill. */
  detail: string;
}

export interface MemoryProvider {
  readonly name: string;
  recordEpisode(episode: MemoryEpisode): Promise<void>;
  search(query: string, opts?: { subjectNodeId?: string; limit?: number }): Promise<MemoryHit[]>;
  status(): Promise<MemoryStatus>;
  close(): Promise<void>;
}
