/**
 * OpenProject -> graph projector.
 *
 * Mirrors the canonical sync pattern from the source platform.
 * The WP-type -> ontology mapping and ISO-duration parsing are kept verbatim in
 * spirit; the ontology sink is FalkorDB node/edge
 * upserts plus a Graphiti episode. Object-type names are reused as graph labels.
 */
import { getOpenProjectClient } from '../openproject/client.js';
import type {
  OpenProjectProject,
  OpenProjectVersion,
  OpenProjectWorkPackage,
} from '../openproject/types.js';
import { getGraph } from '../graph/falkor.js';
import { recordEpisode } from '../memory/index.js';
import { config } from '../config.js';
import { mapType, canonicalId, type SourceSystem } from '../ontology/mapping.js';
import type { SpineProperties } from '../ontology/spine.js';
import { getMapping } from '../mapping/store.js';
import type { SourceMappingSet, AttributeMapping } from '../mapping/types.js';

const KNOWN_SOURCES: SourceSystem[] = ['openproject', 'jira', 'msproject', 'planview'];

/** Parse ISO 8601 duration (PT2H30M, P1DT4H, PT0.5H) to hours. (lifted from DOSv2, extended) */
function parseISODuration(duration?: string): number | undefined {
  if (!duration) return undefined;
  const match = duration.match(/P(?:(\d+(?:\.\d+)?)D)?(?:T(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?)?/);
  if (!match) return undefined;
  const days = parseFloat(match[1] || '0');
  const hours = parseFloat(match[2] || '0');
  const minutes = parseFloat(match[3] || '0');
  return days * 24 + hours + minutes / 60;
}

/**
 * Coerce an arbitrary OpenProject attribute value to a FalkorDB-safe scalar
 * (or array of scalars). Returns undefined for empty/unwritable values so the
 * caller can skip them — FalkorDB rejects undefined and nested objects.
 */
function toGraphScalar(value: unknown): string | number | boolean | string[] | undefined {
  if (value === undefined || value === null) return undefined;
  const t = typeof value;
  if (t === 'string') return value as string;
  if (t === 'number' || t === 'boolean') return value as number | boolean;
  if (Array.isArray(value)) {
    const items = value
      .map((v) => toGraphScalar(v))
      .filter((v): v is string | number | boolean => v !== undefined)
      .map((v) => String(v));
    return items.length > 0 ? items : undefined;
  }
  if (t === 'object') {
    const obj = value as Record<string, unknown>;
    // Formattable text ({ raw, html }).
    if (typeof obj.raw === 'string') return obj.raw;
    // Linked resource ({ href, title }) or embedded ({ name }).
    if (typeof obj.title === 'string') return obj.title;
    if (typeof obj.name === 'string') return obj.name as string;
    if (typeof obj.href === 'string') return obj.href as string;
    return undefined;
  }
  return undefined;
}

// ---------------------------------------------------------------------------
// Mapped-attribute transform bridge
// ---------------------------------------------------------------------------
// After raw custom fields land as cf_* props, apply the active MappingSet's
// transform and ALSO write the canonical value under the mapping's ontology
// property id (e.g. pm:percentComplete, k360:objective) — so a mapped attribute
// is queryable by its ontology id and usable as a rule metric, not just as a
// raw cf_* prop. Idempotent.

/** Active mapping per source, cached briefly (mappings change rarely; the WP
 *  sync runs hot). */
let mappingCache: { source: string; set: SourceMappingSet | null; at: number } | null = null;
async function activeMapping(source: string): Promise<SourceMappingSet | null> {
  const TTL_MS = 60_000;
  if (mappingCache && mappingCache.source === source && Date.now() - mappingCache.at < TTL_MS) {
    return mappingCache.set;
  }
  const set = await getMapping(source).catch(() => null);
  mappingCache = { source, set, at: Date.now() };
  return set;
}

/** Forward transform: ISO-8601 duration → hours (mirrors the reverse in
 *  mapping/routes.ts which emits PT{h}H). status_map/priority_map pass through
 *  (the source's canonical enum name is kept, as on the reverse path). */
function isoDurationToHours(value: unknown): number | undefined {
  if (typeof value === 'number') return value;
  if (typeof value !== 'string') return undefined;
  const t = value.match(/PT(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?/);
  if (t && (t[1] || t[2])) return Number(t[1] ?? 0) + Number(t[2] ?? 0) / 60;
  const d = value.match(/P(\d+(?:\.\d+)?)D/);
  if (d) return Number(d[1]) * 24;
  const n = Number(value);
  return Number.isFinite(n) ? n : undefined;
}

function applyForwardTransform(transform: AttributeMapping['transform'], value: unknown): unknown {
  if (transform === 'iso_duration_hours') return isoDurationToHours(value);
  return value; // status_map / priority_map / none → pass through
}

/**
 * Write canonical ontology-property values for every synced mapping, resolving
 * the source value from the raw payload, the cf_* alias, or the normalized
 * props. Mutates `properties` in place (never writes undefined). Best-effort:
 * a missing/unreadable mapping just skips the bridge.
 */
async function applyMappingBridge(
  source: string,
  raw: Record<string, unknown>,
  normalized: Record<string, unknown>,
  properties: Record<string, unknown>,
): Promise<void> {
  const set = await activeMapping(source);
  if (!set) return;
  for (const m of set.mappings ?? []) {
    if (!m.synced || !m.ontologyProperty) continue;
    const cfKey = `cf_${m.sourceKey.replace(/^customField_?/, '')}`;
    const srcVal = raw[m.sourceKey] ?? properties[cfKey] ?? normalized[m.sourceKey];
    if (srcVal === undefined || srcVal === null) continue;
    const scalar = toGraphScalar(applyForwardTransform(m.transform, srcVal));
    if (scalar !== undefined) properties[m.ontologyProperty] = scalar;
  }
}

function projectNodeId(opId: number | string): string {
  return `op-project-${opId}`;
}
function wpNodeId(opId: number | string): string {
  return `op-wp-${opId}`;
}
function versionNodeId(opId: number | string): string {
  return `op-version-${opId}`;
}

/** Last path segment of an APIv3 href (/api/v3/work_packages/42 -> "42"). */
function idFromHref(href?: string): string | undefined {
  const id = href?.split('/').pop();
  return id && /^\d+$/.test(id) ? id : undefined;
}

/**
 * OpenProject relation type -> canonical spine edge. `reversed` flips the
 * from/to so the graph only ever holds the active voice (BLOCKS/FOLLOWS/
 * DUPLICATES); the original native type is preserved on the edge as `opType`.
 */
const RELATION_EDGE_MAP: Record<string, { edgeType: string; reversed: boolean }> = {
  blocks: { edgeType: 'BLOCKS', reversed: false },
  blocked: { edgeType: 'BLOCKS', reversed: true },
  follows: { edgeType: 'FOLLOWS', reversed: false },
  precedes: { edgeType: 'FOLLOWS', reversed: true },
  duplicates: { edgeType: 'DUPLICATES', reversed: false },
  duplicated: { edgeType: 'DUPLICATES', reversed: true },
};
const DEFAULT_RELATION_EDGE = { edgeType: 'RELATES_TO', reversed: false };

export class Projector {
  private readonly graph = getGraph();
  private readonly op = getOpenProjectClient();

  /** Project an OpenProject project into the graph. */
  async syncProject(project: OpenProjectProject): Promise<void> {
    const isTopLevel = !project._links?.parent?.href;
    await this.graph.upsertNode({
      id: projectNodeId(project.id),
      label: 'Project',
      properties: {
        name: project.name,
        identifier: project.identifier,
        description: project.description?.raw ?? '',
        status: project.active === false ? 'inactive' : 'active',
        portfolioRoot: isTopLevel,
        spineClass: 'Project',
        dialectClass: 'pm:Project',
        source: 'openproject',
        ingestedVia: 'openproject',
        syncedAt: new Date().toISOString(),
      },
    });
  }

  /** Project a single work package into the graph (called by the webhook handler). */
  async syncSingleWorkPackage(wpId: number): Promise<{ label: string; nodeId: string } | null> {
    const wp = await this.op.getWorkPackage(wpId);
    return this.syncWorkPackage(wp);
  }

  async syncWorkPackage(
    wp: OpenProjectWorkPackage,
  ): Promise<{ label: string; nodeId: string } | null> {
    // Skip changes our own agent made, to avoid feedback loops.
    const syncSource = (wp['customField_sync_source'] as string) ?? 'openproject';
    if (syncSource === config.openproject.syncSource) return null;

    const raw = wp as unknown as Record<string, unknown>;

    // Canonical (spine) properties — native fields normalized to the ontology.
    const props: SpineProperties = {
      name: wp.subject,
      description: wp.description?.raw ?? '',
      status: wp._links?.status?.title ?? 'New',
      priority: wp._links?.priority?.title ?? 'Normal',
      assignee: wp._links?.assignee?.title,
      startDate: wp.startDate,
      endDate: wp.dueDate,
      dueDate: wp.dueDate,
      progress: wp.percentageDone,
      estimatedHours: parseISODuration(wp.estimatedTime),
      actualHours: parseISODuration(wp.spentTime),
      storyPoints: typeof raw['storyPoints'] === 'number' ? (raw['storyPoints'] as number) : undefined,
    };

    // True origin (provenance): data ingested from another tool carries it.
    const declared = String(raw['customField_source_system'] ?? 'openproject').toLowerCase();
    const source: SourceSystem = (KNOWN_SOURCES as string[]).includes(declared)
      ? (declared as SourceSystem)
      : 'openproject';
    const nativeId = String(raw['customField_external_id'] ?? wp.id);

    // Resolve to the spine via the ontology mapping layer.
    const typeName = wp._links?.type?.title ?? 'Task';
    const { label, dialectClass } = mapType('openproject', typeName, props);
    const nodeId = wpNodeId(wp.id!);

    // Fix-version pointer (kept as a property so syncEnrichment can link WPs to
    // Release nodes even when the Release is projected after the WP).
    const versionOpId = idFromHref(wp._links?.version?.href);
    const releaseId = versionOpId ? versionNodeId(versionOpId) : undefined;

    const properties: Record<string, unknown> = {
      ...props,
      type: typeName, // native OpenProject type
      updatedAt: typeof wp.updatedAt === 'string' ? wp.updatedAt : undefined,
      releaseId,
      spineClass: label,
      dialectClass,
      source, // true origin system (jira/msproject/planview/openproject)
      ingestedVia: 'openproject',
      nativeId,
      canonicalId: canonicalId(source, nativeId),
      syncedAt: new Date().toISOString(),
    };

    // ALSO carry arbitrary OpenProject attributes (esp. custom fields) onto the
    // node so the universal mapper can surface/transform them downstream. The
    // flattened APIv3 payload exposes custom fields as `customField_<name>` and
    // `customFieldN`; we write them under a stable `cf_*` prefix as graph-safe
    // scalars. Standard fields are already normalized above, so we add only the
    // extras here. Idempotent + never writes undefined.
    for (const [key, value] of Object.entries(raw)) {
      if (!key.startsWith('customField')) continue;
      const scalar = toGraphScalar(value);
      if (scalar === undefined) continue;
      properties[`cf_${key.replace(/^customField_?/, '')}`] = scalar;
    }

    // Transform bridge: also write canonical ontology-property values for every
    // synced mapping (so mapped attributes are queryable by ontology id + usable
    // as rule metrics, not just as raw cf_* props).
    await applyMappingBridge(source, raw, props as Record<string, unknown>, properties);

    await this.graph.upsertNode({ id: nodeId, label, properties });

    // Link to its project.
    const projectHref = wp._links?.project?.href;
    if (projectHref) {
      const opProjectId = projectHref.split('/').pop();
      if (opProjectId) {
        await this.graph.upsertEdge({
          fromId: projectNodeId(opProjectId),
          toId: nodeId,
          type: 'CONTAINS',
        });
      }
    }

    // Link to its release — guarded, so a webhook update never seeds an empty
    // placeholder Release node (syncEnrichment links any WPs synced earlier).
    if (releaseId) {
      await this.linkIfBothExist(nodeId, releaseId, 'TARGETS_RELEASE');
    }

    await recordEpisode({
      content: `${label} "${wp.subject}" (#${wp.id}) is ${props.status}`,
      source,
      subjectNodeId: nodeId,
      metadata: { spineClass: label, dialectClass, status: props.status, priority: props.priority },
    });

    return { label, nodeId };
  }

  /**
   * Create an edge only when BOTH endpoints already exist. A blind MERGE (as in
   * upsertEdge) would seed empty placeholder nodes for ids we have not synced;
   * the guarded MATCH makes enrichment safe to run in any order.
   */
  private async linkIfBothExist(
    fromId: string,
    toId: string,
    type: string,
    props: Record<string, unknown> = {},
  ): Promise<boolean> {
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(type)) throw new Error(`Unsafe edge type: ${type}`);
    const rows = await this.graph.query<{ created: number }>(
      `MATCH (a { id: $fromId }), (b { id: $toId })
       MERGE (a)-[r:${type}]->(b)
       SET r += $props
       RETURN count(r) AS created`,
      { fromId, toId, props },
    );
    return (rows[0]?.created ?? 0) > 0;
  }

  /** Project one OpenProject version as a Release node + Project->Release edge. */
  private async syncVersion(version: OpenProjectVersion): Promise<void> {
    const releaseId = versionNodeId(version.id);
    await this.graph.upsertNode({
      id: releaseId,
      label: 'Release',
      properties: {
        name: version.name,
        status: version.status,
        startDate: version.startDate,
        endDate: version.endDate,
        spineClass: 'Release',
        dialectClass: 'pm:Release',
        source: 'openproject',
        ingestedVia: 'openproject',
        syncedAt: new Date().toISOString(),
      },
    });
    const opProjectId = idFromHref(version._links?.definingProject?.href);
    if (opProjectId) {
      await this.linkIfBothExist(projectNodeId(opProjectId), releaseId, 'HAS_RELEASE');
    }
  }

  /**
   * Enrichment pass — relations, versions, time entries. Runs AFTER projects/WPs
   * exist (edges are guarded MATCHes), idempotent, and callable on its own so a
   * re-run can refresh dependency/cost data without a full WP re-scan.
   *
   * Time entries are aggregated in code (sum of hours per WP/project) rather
   * than projected as nodes — entry volume would swamp the graph for no
   * reasoning benefit.
   */
  async syncEnrichment(opts?: {
    pageSize?: number;
    onProgress?: (msg: string) => void;
  }): Promise<{ relations: number; releases: number; timeEntries: number }> {
    const pageSize = opts?.pageSize ?? 100;
    const log = opts?.onProgress ?? (() => {});

    // a) Relations -> canonical dependency edges between existing WP nodes.
    let relationCount = 0;
    for (let page = 1; ; page++) {
      const relations = await this.op.getRelations({ pageSize, offset: page });
      if (relations.length === 0) break;
      for (const rel of relations) {
        const fromOp = idFromHref(rel._links?.from?.href);
        const toOp = idFromHref(rel._links?.to?.href);
        if (!fromOp || !toOp) continue;
        const { edgeType, reversed } = RELATION_EDGE_MAP[rel.type] ?? DEFAULT_RELATION_EDGE;
        const fromId = wpNodeId(reversed ? toOp : fromOp);
        const toId = wpNodeId(reversed ? fromOp : toOp);
        if (await this.linkIfBothExist(fromId, toId, edgeType, { opType: rel.type })) {
          relationCount++;
        }
      }
      log(`relations: ${relationCount} projected`);
      if (relations.length < pageSize) break;
    }

    // b) Versions -> Release nodes per project already in the graph. Tolerate
    // per-project failures (archived project, module disabled) without aborting.
    const projects = await this.graph.query<{ id: string }>(
      `MATCH (p:Project) WHERE p.id STARTS WITH 'op-project-' RETURN p.id AS id`,
    );
    let releaseCount = 0;
    for (const p of projects) {
      const opProjectId = p.id.replace('op-project-', '');
      const versions = await this.op.getVersions(opProjectId).catch(() => []);
      for (const version of versions) {
        await this.syncVersion(version);
        releaseCount++;
      }
    }
    if (releaseCount > 0) log(`releases: ${releaseCount} projected`);

    // Connect WPs that carried a fix-version pointer to their Release — covers
    // WPs synced before their Release node existed.
    await this.graph.query(
      `MATCH (w) WHERE w.releaseId IS NOT NULL
       MATCH (r:Release) WHERE r.id = w.releaseId
       MERGE (w)-[:TARGETS_RELEASE]->(r)`,
    );

    // c) Time entries -> spentHours aggregates on WPs and projects.
    const wpHours = new Map<string, number>();
    const projectHours = new Map<string, number>();
    let entryCount = 0;
    for (let page = 1; ; page++) {
      const entries = await this.op.getTimeEntries({ pageSize, offset: page });
      if (entries.length === 0) break;
      for (const entry of entries) {
        const hours = parseISODuration(entry.hours) ?? 0;
        if (hours <= 0) continue;
        const wpOp = idFromHref(entry._links?.workPackage?.href);
        if (wpOp) {
          const id = wpNodeId(wpOp);
          wpHours.set(id, (wpHours.get(id) ?? 0) + hours);
        }
        const projOp = idFromHref(entry._links?.project?.href);
        if (projOp) {
          const id = projectNodeId(projOp);
          projectHours.set(id, (projectHours.get(id) ?? 0) + hours);
        }
      }
      entryCount += entries.length;
      log(`time entries: ${entryCount} aggregated`);
      if (entries.length < pageSize) break;
    }
    for (const [id, hours] of [...wpHours, ...projectHours]) {
      await this.graph.query(`MATCH (n { id: $id }) SET n.spentHours = $hours`, {
        id,
        hours: Math.round(hours * 100) / 100,
      });
    }

    return { relations: relationCount, releases: releaseCount, timeEntries: entryCount };
  }

  /**
   * Full backfill — seeds the graph from ALL existing OpenProject data so the
   * agent has a populated world-model before the first webhook fires.
   *
   * Pages through both projects and work packages (OpenProject's `offset` is a
   * 1-based page number); `onProgress` is invoked after each page for CLI output.
   */
  async syncAll(opts?: {
    pageSize?: number;
    onProgress?: (msg: string) => void;
  }): Promise<{
    projects: number;
    workPackages: number;
    skipped: number;
    relations: number;
    releases: number;
    timeEntries: number;
  }> {
    const pageSize = opts?.pageSize ?? 100;
    const log = opts?.onProgress ?? (() => {});

    let projectCount = 0;
    for (let page = 1; ; page++) {
      const projects = await this.op.listProjects({ pageSize, offset: page });
      if (projects.length === 0) break;
      for (const project of projects) await this.syncProject(project);
      projectCount += projects.length;
      log(`projects: ${projectCount} synced`);
      if (projects.length < pageSize) break;
    }

    let wpCount = 0;
    let skipped = 0;
    for (let page = 1; ; page++) {
      const wps = await this.op.listWorkPackages({ pageSize, offset: page });
      if (wps.length === 0) break;
      for (const wp of wps) {
        const result = await this.syncWorkPackage(wp);
        if (result) wpCount++;
        else skipped++;
      }
      log(`work packages: ${wpCount} synced, ${skipped} skipped`);
      if (wps.length < pageSize) break;
    }

    // Enrichment AFTER WPs so the guarded relation/release edges find both ends.
    log('enriching: relations, versions, time entries...');
    const enrichment = await this.syncEnrichment({ pageSize, onProgress: log });

    return { projects: projectCount, workPackages: wpCount, skipped, ...enrichment };
  }
}

let singleton: Projector | null = null;
export function getProjector(): Projector {
  if (!singleton) singleton = new Projector();
  return singleton;
}
