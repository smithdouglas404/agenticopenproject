/**
 * FalkorDB graph client.
 *
 * NEW BUILD (gap #1 in the reuse map). DOSv2 used Neo4j (`server/graph/GraphService.ts`)
 * and a "Palantir" abstraction; the target world-model is FalkorDB. FalkorDB speaks
 * openCypher, so the *query shapes* from DOSv2's `schema.cypher` / GraphService port
 * over — only the driver/connection below is new.
 */
import { FalkorDB } from 'falkordb';
import { config } from '../config.js';

/**
 * FalkorDB query params reject `undefined`; drop those keys before sending.
 * Returns `Record<string, any>` because the lib's `QueryParams` type is not exported.
 */
function clean(props: Record<string, unknown>): Record<string, any> {
  const out: Record<string, any> = {};
  for (const [key, value] of Object.entries(props)) {
    if (value !== undefined) out[key] = value;
  }
  return out;
}

export interface GraphNode {
  /** Stable id, e.g. "op-wp-1234" or "op-project-7". */
  id: string;
  /** Node label, e.g. "WorkPackage", "Project", "Risk", "Insight". */
  label: string;
  properties: Record<string, unknown>;
}

export interface GraphEdge {
  fromId: string;
  toId: string;
  type: string;
  properties?: Record<string, unknown>;
}

export class FalkorGraph {
  private db: Awaited<ReturnType<typeof FalkorDB.connect>> | null = null;

  private async graph() {
    if (!this.db) {
      this.db = await FalkorDB.connect({
        socket: { host: config.falkor.host, port: config.falkor.port },
        password: config.falkor.password,
      });
      // FalkorDB emits 'error' as an EventEmitter; without a handler an
      // unhandled 'error' crashes the whole process on a transient DB blip.
      this.db.on('error', (err: unknown) => {
        console.warn(`[falkor] connection error: ${(err as Error)?.message ?? err}`);
        this.db = null; // force reconnect on next query
      });
    }
    return this.db.selectGraph(config.falkor.graph);
  }

  /** Idempotent upsert of a node keyed by id; merges properties. */
  async upsertNode(node: GraphNode): Promise<void> {
    const g = await this.graph();
    await g.query(
      `MERGE (n:${sanitizeLabel(node.label)} { id: $id })
       SET n += $props`,
      { params: clean({ id: node.id, props: clean({ ...node.properties, id: node.id }) }) },
    );
  }

  /** Idempotent upsert of an edge between two existing-or-created nodes. */
  async upsertEdge(edge: GraphEdge): Promise<void> {
    const g = await this.graph();
    await g.query(
      `MERGE (a { id: $fromId })
       MERGE (b { id: $toId })
       MERGE (a)-[r:${sanitizeLabel(edge.type)}]->(b)
       SET r += $props`,
      { params: clean({ fromId: edge.fromId, toId: edge.toId, props: clean(edge.properties ?? {}) }) },
    );
  }

  /** Read helper for the agent to pull a project subgraph. */
  async query<T = Record<string, unknown>>(
    cypher: string,
    params: Record<string, unknown> = {},
  ): Promise<T[]> {
    const g = await this.graph();
    const result = await g.query(cypher, { params: clean(params) });
    return (result.data ?? []) as T[];
  }

  async close(): Promise<void> {
    await this.db?.close();
    this.db = null;
  }
}

/** Labels/relationship types are interpolated into Cypher, so keep them alphanumeric. */
function sanitizeLabel(label: string): string {
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(label)) {
    throw new Error(`Unsafe graph label/type: ${label}`);
  }
  return label;
}

let singleton: FalkorGraph | null = null;

export function getGraph(): FalkorGraph {
  if (!singleton) singleton = new FalkorGraph();
  return singleton;
}
