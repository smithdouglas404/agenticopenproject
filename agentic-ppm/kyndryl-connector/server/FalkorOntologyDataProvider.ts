/**
 * FalkorOntologyDataProvider — the ontology backend for Kyndral-365 DOSv2.
 *
 * FalkorDB IS the knowledge graph and ontology layer. The Kyndral UI reads
 * ontology objects (Project, Feature, Story, Task, Risk, …) through the
 * `OntologyDataProvider` interface; this class implements that interface
 * against FalkorDB (openCypher), so the route layer and the UI are unchanged.
 *
 * Provider API:
 *   getObjects(objectType, filter?, limit?)
 *   getObject(objectType, id)
 *   upsertObject(objectType, obj)            (MERGE by id, SET +=)
 *   deleteObject(objectType, id)
 *   linkObjects(fromT, fromId, rel, toT, toId)   (MERGE relationship)
 *   getLinkedObjects(objectType, id, rel, dir)
 *   searchObjects(objectType, text)          (CONTAINS over name/description)
 *   query(cypher, params)                    (escape hatch: raw openCypher)
 *   aggregate(objectType, groupBy, agg)      (count / sum / avg by property)
 *   health()
 *
 * Connection pattern is identical to the proven client in
 * agentic-ppm/agent-runtime/src/graph/falkor.ts:
 *   FalkorDB.connect({ socket: { host, port }, password }) → db.selectGraph(name)
 *   → g.query(cypher, { params }).
 *
 * SECURITY: labels and relationship types cannot be parameterized in Cypher,
 * so they are interpolated — every label/rel-type passes through
 * sanitizeLabel() (/^[A-Za-z_][A-Za-z0-9_]*$/) and throws otherwise.
 * FalkorDB rejects `undefined` query params, so clean() strips them.
 *
 * DROP-IN: place in Kyndral's `server/`, point the ontology routes at
 * getOntologyProvider(). The legacy `/api/palantir/ontology/*` URL stem can
 * stay for compatibility, or migrate to `/api/ontology/*` (see
 * docs/ONTOLOGY_LAYER.md for the rename plan).
 * Env: FALKORDB_HOST, FALKORDB_PORT, FALKORDB_GRAPH, FALKORDB_PASSWORD.
 */
import { FalkorDB } from "falkordb";

export interface FalkorOntologyConfig {
  host: string;
  port: number;
  graph: string;
  password?: string;
}

/** An ontology object: a stable string id plus arbitrary scalar properties. */
export interface OntologyObject {
  id: string;
  [key: string]: unknown;
}

export type LinkDirection = "out" | "in" | "both";

export type AggregateOp = "count" | "sum" | "avg";

/**
 * FalkorDB query params reject `undefined`; drop those keys before sending.
 * (Same helper as agent-runtime/src/graph/falkor.ts.)
 */
function clean(props: Record<string, unknown>): Record<string, any> {
  const out: Record<string, any> = {};
  for (const [key, value] of Object.entries(props)) {
    if (value !== undefined) out[key] = value;
  }
  return out;
}

/** Labels/relationship types/property keys are interpolated into Cypher — keep them alphanumeric. */
function sanitizeLabel(label: string): string {
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(label)) {
    throw new Error(`Unsafe graph label/relationship/property name: ${label}`);
  }
  return label;
}

/** Flatten a Falkor node result entry ({ properties } or plain map) into an OntologyObject. */
function toObject(value: unknown): OntologyObject {
  const v = value as { properties?: Record<string, unknown> } | Record<string, unknown> | null;
  if (v && typeof v === "object" && "properties" in v && typeof (v as any).properties === "object") {
    return { id: "", ...(v as any).properties } as OntologyObject;
  }
  return { id: "", ...(v as Record<string, unknown> | null ?? {}) } as OntologyObject;
}

export class FalkorOntologyDataProvider {
  private readonly config: FalkorOntologyConfig;
  private db: Awaited<ReturnType<typeof FalkorDB.connect>> | null = null;

  constructor(config?: Partial<FalkorOntologyConfig>) {
    this.config = {
      host: config?.host ?? process.env.FALKORDB_HOST ?? "localhost",
      port: config?.port ?? Number(process.env.FALKORDB_PORT ?? 6379),
      graph: config?.graph ?? process.env.FALKORDB_GRAPH ?? "kyndral_ontology",
      password: config?.password ?? process.env.FALKORDB_PASSWORD,
    };
  }

  private async graph() {
    if (!this.db) {
      this.db = await FalkorDB.connect({
        socket: { host: this.config.host, port: this.config.port },
        password: this.config.password,
      });
      // FalkorDB emits 'error' as an EventEmitter; without a handler an
      // unhandled 'error' crashes the whole process on a transient DB blip.
      this.db.on("error", (err: unknown) => {
        console.warn(`[falkor-ontology] connection error: ${(err as Error)?.message ?? err}`);
        this.db = null; // force reconnect on next query
      });
    }
    return this.db.selectGraph(this.config.graph);
  }

  private async run<T = Record<string, unknown>>(
    cypher: string,
    params: Record<string, unknown> = {},
  ): Promise<T[]> {
    const g = await this.graph();
    const result = await g.query(cypher, { params: clean(params) });
    return ((result as { data?: unknown[] }).data ?? []) as T[];
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  /**
   * List objects of a type (node label), optionally filtered on exact
 * property equality.
   */
  async getObjects(
    objectType: string,
    filter?: Record<string, unknown>,
    limit = 500,
  ): Promise<OntologyObject[]> {
    const label = sanitizeLabel(objectType);
    const where: string[] = [];
    const params: Record<string, unknown> = { limit: Math.floor(limit) };
    for (const [key, value] of Object.entries(clean(filter ?? {}))) {
      const prop = sanitizeLabel(key);
      where.push(`n.${prop} = $f_${prop}`);
      params[`f_${prop}`] = value;
    }
    const rows = await this.run<{ n: unknown }>(
      `MATCH (n:${label})${where.length ? ` WHERE ${where.join(" AND ")}` : ""}
       RETURN n LIMIT toInteger($limit)`,
      params,
    );
    return rows.map((r) => toObject(r.n));
  }

  /** Fetch one object by id. */
  async getObject(objectType: string, id: string): Promise<OntologyObject | null> {
    const label = sanitizeLabel(objectType);
    const rows = await this.run<{ n: unknown }>(
      `MATCH (n:${label} { id: $id }) RETURN n LIMIT 1`,
      { id },
    );
    return rows.length ? toObject(rows[0].n) : null;
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  /**
   * Idempotent upsert keyed by id: MERGE the node, SET += properties.
 * Idempotent upsert (MERGE by id, SET += props).
   */
  async upsertObject(objectType: string, obj: OntologyObject): Promise<OntologyObject> {
    const label = sanitizeLabel(objectType);
    if (!obj?.id) throw new Error(`upsertObject(${objectType}): object requires an id`);
    await this.run(
      `MERGE (n:${label} { id: $id })
       SET n += $props`,
      { id: String(obj.id), props: clean({ ...obj, id: String(obj.id) }) },
    );
    return { ...obj, id: String(obj.id) };
  }

  /** Delete an object (and its relationships). */
  async deleteObject(objectType: string, id: string): Promise<boolean> {
    const label = sanitizeLabel(objectType);
    const rows = await this.run<{ deleted: number }>(
      `MATCH (n:${label} { id: $id })
       WITH n, count(n) AS deleted
       DETACH DELETE n
       RETURN deleted`,
      { id },
    );
    return rows.length > 0 && Number(rows[0].deleted) > 0;
  }

  // ── Links ────────────────────────────────────────────────────────────────

  /**
   * Idempotent directed link between two objects (MERGE both endpoints so
   * link order never matters).
   */
  async linkObjects(
    fromType: string,
    fromId: string,
    relType: string,
    toType: string,
    toId: string,
    props?: Record<string, unknown>,
  ): Promise<void> {
    const fromLabel = sanitizeLabel(fromType);
    const toLabel = sanitizeLabel(toType);
    const rel = sanitizeLabel(relType);
    await this.run(
      `MERGE (a:${fromLabel} { id: $fromId })
       MERGE (b:${toLabel} { id: $toId })
       MERGE (a)-[r:${rel}]->(b)
       SET r += $props`,
      { fromId, toId, props: clean(props ?? {}) },
    );
  }

  /**
   * Traverse one hop along a relationship type. direction:
   *   'out'  → (object)-[rel]->(linked)
   *   'in'   → (object)<-[rel]-(linked)
   *   'both' → either direction

   */
  async getLinkedObjects(
    objectType: string,
    id: string,
    relType: string,
    direction: LinkDirection = "out",
    limit = 500,
  ): Promise<OntologyObject[]> {
    const label = sanitizeLabel(objectType);
    const rel = sanitizeLabel(relType);
    const pattern =
      direction === "out"
        ? `(n:${label} { id: $id })-[:${rel}]->(m)`
        : direction === "in"
          ? `(n:${label} { id: $id })<-[:${rel}]-(m)`
          : `(n:${label} { id: $id })-[:${rel}]-(m)`;
    const rows = await this.run<{ m: unknown }>(
      `MATCH ${pattern} RETURN DISTINCT m LIMIT toInteger($limit)`,
      { id, limit: Math.floor(limit) },
    );
    return rows.map((r) => toObject(r.m));
  }

  // ── Search / analytics ───────────────────────────────────────────────────

  /**
   * Simple case-insensitive substring search over name + description.
 * (Upgrade path: FalkorDB full-text / vector index for GraphRAG —
   * see docs/ONTOLOGY_LAYER.md.)
   */
  async searchObjects(objectType: string, text: string, limit = 50): Promise<OntologyObject[]> {
    const label = sanitizeLabel(objectType);
    const rows = await this.run<{ n: unknown }>(
      `MATCH (n:${label})
       WHERE toLower(coalesce(n.name, '')) CONTAINS toLower($text)
          OR toLower(coalesce(n.description, '')) CONTAINS toLower($text)
       RETURN n LIMIT toInteger($limit)`,
      { text, limit: Math.floor(limit) },
    );
    return rows.map((r) => toObject(r.n));
  }

  /**
 * Escape hatch: run raw openCypher with params. Bypasses the typed
   * SQL/dataset queries. Params are cleaned of undefined values.
   */
  async query<T = Record<string, unknown>>(
    cypher: string,
    params: Record<string, unknown> = {},
  ): Promise<T[]> {
    return this.run<T>(cypher, params);
  }

  /**
   * Group-by aggregation over one object type.
   *   aggregate('Task', 'status', { op: 'count' })
   *   aggregate('Project', 'status', { op: 'sum', property: 'budget' })
 * Returns [{ group, value }] — count / sum / avg group-by aggregations.
   */
  async aggregate(
    objectType: string,
    groupBy: string,
    agg: { op: AggregateOp; property?: string },
  ): Promise<Array<{ group: unknown; value: number }>> {
    const label = sanitizeLabel(objectType);
    const groupProp = sanitizeLabel(groupBy);
    let expr: string;
    if (agg.op === "count") {
      expr = "count(n)";
    } else {
      if (!agg.property) throw new Error(`aggregate(${agg.op}) requires a property`);
      const aggProp = sanitizeLabel(agg.property);
      expr = `${agg.op}(toFloat(coalesce(n.${aggProp}, 0)))`;
    }
    const rows = await this.run<{ group: unknown; value: number }>(
      `MATCH (n:${label})
       RETURN n.${groupProp} AS group, ${expr} AS value
       ORDER BY value DESC`,
    );
    return rows.map((r) => ({ group: r.group, value: Number(r.value) }));
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /** Connectivity check for /health endpoints and the integration test screen. */
  async health(): Promise<{ ok: boolean; message: string }> {
    try {
      await this.run("RETURN 1 AS ok");
      return {
        ok: true,
        message: `FalkorDB ok (${this.config.host}:${this.config.port}, graph "${this.config.graph}")`,
      };
    } catch (e: any) {
      return { ok: false, message: `FalkorDB unreachable: ${e.message}` };
    }
  }

  async close(): Promise<void> {
    await this.db?.close();
    this.db = null;
  }
}

let singleton: FalkorOntologyDataProvider | null = null;

/** Process-wide provider, configured from FALKORDB_* env vars on first use. */
export function getOntologyProvider(): FalkorOntologyDataProvider {
  if (!singleton) singleton = new FalkorOntologyDataProvider();
  return singleton;
}
