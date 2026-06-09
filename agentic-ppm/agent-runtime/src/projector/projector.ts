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

/** SAFe type mapping: OP WP type name -> graph label. (from DOSv2 WP_TYPE_TO_ONTOLOGY) */
const WP_TYPE_TO_LABEL: Record<string, string> = {
  Epic: 'Epic',
  Capability: 'Feature',
  Feature: 'Feature',
  'User Story': 'Story',
  Task: 'Task',
  Risk: 'Risk',
  'Agent Alert': 'Insight',
  'Governance Gate': 'Project',
  'Demand Request': 'Project',
  'Change Request': 'Project',
  Phase: 'Project',
  Milestone: 'Project',
  Bug: 'Task',
};

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
        source: 'openproject',
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

    const typeName = wp._links?.type?.title ?? 'Task';
    const label = WP_TYPE_TO_LABEL[typeName] ?? 'Task';
    const nodeId = wpNodeId(wp.id!);

    const properties: Record<string, unknown> = {
      name: wp.subject,
      description: wp.description?.raw ?? '',
      type: typeName,
      status: wp._links?.status?.title ?? 'New',
      priority: wp._links?.priority?.title ?? 'Normal',
      assignee: wp._links?.assignee?.title,
      startDate: wp.startDate,
      endDate: wp.dueDate,
      progress: wp.percentageDone,
      estimatedHours: parseISODuration(wp.estimatedTime),
      actualHours: parseISODuration(wp.spentTime),
      source: 'openproject',
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
      content: `${typeName} "${wp.subject}" (#${wp.id}) is ${properties.status}`,
      source: 'openproject',
      metadata: { nodeId, label, status: properties.status, priority: properties.priority },
    });

    return { label, nodeId };
  }

  /** Full backfill — used for seeding the graph from existing OpenProject data. */
  async syncAll(): Promise<{ projects: number; workPackages: number }> {
    const projects = await this.op.listProjects();
    for (const project of projects) await this.syncProject(project);

    const workPackages = await this.op.listWorkPackages({ pageSize: 200 });
    let wpCount = 0;
    for (const wp of workPackages) {
      const result = await this.syncWorkPackage(wp);
      if (result) wpCount++;
    }
    return { projects: projects.length, workPackages: wpCount };
  }
}

let singleton: Projector | null = null;
export function getProjector(): Projector {
  if (!singleton) singleton = new Projector();
  return singleton;
}
