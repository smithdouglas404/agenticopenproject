/**
 * OpenProject -> graph projector.
 *
 * ADAPTED from DOSv2 `server/services/sync/OpenProjectToPalantirSync.ts`.
 * The WP-type -> ontology mapping and ISO-duration parsing are kept verbatim in
 * spirit; the Palantir sink (`pushToPalantir`) is replaced with FalkorDB node/edge
 * upserts plus a Graphiti episode. Object-type names are reused as graph labels.
 */
import { getOpenProjectClient } from '../openproject/client.js';
import type { OpenProjectProject, OpenProjectWorkPackage } from '../openproject/types.js';
import { getGraph } from '../graph/falkor.js';
import { recordEpisode } from '../graph/graphiti.js';
import { config } from '../config.js';
import { mapType, canonicalId, type SourceSystem } from '../ontology/mapping.js';
import type { SpineProperties } from '../ontology/spine.js';

const KNOWN_SOURCES: SourceSystem[] = ['openproject', 'jira', 'msproject', 'planview'];

/** Parse ISO 8601 duration (PT2H30M) to hours. (lifted from DOSv2) */
function parseISODuration(duration?: string): number | undefined {
  if (!duration) return undefined;
  const match = duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?/);
  if (!match) return undefined;
  const hours = parseInt(match[1] || '0', 10);
  const minutes = parseInt(match[2] || '0', 10);
  return hours + minutes / 60;
}

function projectNodeId(opId: number | string): string {
  return `op-project-${opId}`;
}
function wpNodeId(opId: number | string): string {
  return `op-wp-${opId}`;
}

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

    const properties: Record<string, unknown> = {
      ...props,
      type: typeName, // native OpenProject type
      spineClass: label,
      dialectClass,
      source, // true origin system (jira/msproject/planview/openproject)
      ingestedVia: 'openproject',
      nativeId,
      canonicalId: canonicalId(source, nativeId),
      syncedAt: new Date().toISOString(),
    };

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

    await recordEpisode({
      content: `${label} "${wp.subject}" (#${wp.id}) is ${props.status}`,
      source,
      metadata: { nodeId, spineClass: label, dialectClass, status: props.status, priority: props.priority },
    });

    return { label, nodeId };
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
  }): Promise<{ projects: number; workPackages: number; skipped: number }> {
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

    return { projects: projectCount, workPackages: wpCount, skipped };
  }
}

let singleton: Projector | null = null;
export function getProjector(): Projector {
  if (!singleton) singleton = new Projector();
  return singleton;
}
