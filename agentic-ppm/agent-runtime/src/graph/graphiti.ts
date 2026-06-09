/**
 * Graphiti temporal-memory seam.
 *
 * STUB (gap #1 in the reuse map). Graphiti is a bi-temporal knowledge-graph /
 * memory layer that ingests "episodes" (events) and extracts entities/relations
 * over time. In the target topology it sits alongside FalkorDB to give agents
 * temporal recall ("what changed, when") that DOSv2 approximated with Mem0/Letta.
 *
 * For the Quick slice we record episodes as a no-op-with-logging so the pipeline
 * is wired end-to-end; the real Graphiti client (HTTP or python-service bridge)
 * lands when the memory layer is stood up. See agentic-ppm/docs/05 and 09 (gap #1).
 */
import { config } from '../config.js';

export interface GraphitiEpisode {
  /** Free-text description of what happened, e.g. "WP 1234 moved to At Risk". */
  content: string;
  /** Source system, e.g. "openproject". */
  source: string;
  /** When the event occurred (defaults to now). */
  occurredAt?: Date;
  /** Arbitrary structured payload for later entity extraction. */
  metadata?: Record<string, unknown>;
}

export async function recordEpisode(episode: GraphitiEpisode): Promise<void> {
  // TODO(graphiti): POST to GRAPHITI_URL once the service is provisioned.
  if (config.logLevel === 'debug') {
    // eslint-disable-next-line no-console
    console.log(
      `[graphiti:stub] episode from ${episode.source} @ ${(episode.occurredAt ?? new Date()).toISOString()}: ${episode.content}`,
    );
  }
}
