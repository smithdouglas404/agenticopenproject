/**
 * Agent findings store — k360:AgentFinding materialized in FalkorDB.
 *
 * Every insight/detector finding the agents produce is recorded here as an
 * (:AgentFinding) node with a lifecycle status. This is the single source the
 * HITL console reads, and it dedups detectors: a finding is keyed by
 * (type, subject nodeId), so re-running a detector doesn't re-raise an open one.
 *
 * Lifecycle: new -> published (posted to OpenProject) -> approved | rejected | resolved
 */
import { getGraph } from '../graph/falkor.js';

export type FindingStatus = 'new' | 'published' | 'approved' | 'rejected' | 'resolved';

export interface StoredFinding {
  id: string;
  type: string;
  agentId: string;
  severity: string;
  title: string;
  body: string;
  status: FindingStatus;
  nodeId?: string;
  workPackageId?: number;
  /** The Agent Alert WP created in OpenProject for this finding, if published. */
  alertWpId?: number;
  /** LLM-generated polished narrative for the finding. Falls back to body if absent. */
  narrative?: string;
  /** OpenProject project ID for generating a clickable link in the console. */
  projectId?: number;
  /** Human-readable project name for display alongside the link. */
  projectName?: string;
  /** Follow-up WP the agent created on approval, if any. */
  followupWpId?: number;
  createdAt: string;
  updatedAt: string;
  decidedBy?: string;
}

function findingId(type: string, subject: string): string {
  return `finding--${type}--${subject}`.replace(/[^A-Za-z0-9_:-]/g, '_');
}

/**
 * Record a finding if no OPEN finding with the same key exists.
 * Returns the stored finding and whether it is newly created.
 */
export async function recordFinding(input: {
  type: string;
  agentId: string;
  severity: string;
  title: string;
  body: string;
  nodeId?: string;
  workPackageId?: number;
  status?: FindingStatus;
  alertWpId?: number;
  narrative?: string;
  projectId?: number;
  projectName?: string;
}): Promise<{ finding: StoredFinding; isNew: boolean }> {
  const graph = getGraph();
  const id = findingId(input.type, input.nodeId ?? input.title);
  const now = new Date().toISOString();

  // Open = not rejected/resolved. If an open one exists, just bump updatedAt.
  const existing = await graph.query<{ id: string; status: string }>(
    `MATCH (f:AgentFinding { id: $id })
     WHERE NOT f.status IN ['rejected', 'resolved']
     SET f.updatedAt = $now
     RETURN f.id AS id, f.status AS status`,
    { id, now },
  );
  if (existing.length > 0) {
    const rows = await getFinding(id);
    return { finding: rows!, isNew: false };
  }

  await graph.query(
    `MERGE (f:AgentFinding { id: $id })
     SET f += $props`,
    {
      id,
      props: {
        id,
        type: input.type,
        agentId: input.agentId,
        severity: input.severity,
        title: input.title,
        body: input.body,
        status: input.status ?? 'new',
        nodeId: input.nodeId ?? '',
        workPackageId: input.workPackageId ?? 0,
        alertWpId: input.alertWpId ?? 0,
        narrative: input.narrative ?? '',
        projectId: input.projectId ?? 0,
        projectName: input.projectName ?? '',
        createdAt: now,
        updatedAt: now,
      },
    },
  );

  // Link the finding to the node it concerns, so the graph carries lineage.
  if (input.nodeId) {
    await graph
      .query(
        `MATCH (f:AgentFinding { id: $id }), (n { id: $nodeId })
         MERGE (f)-[:CONCERNS]->(n)`,
        { id, nodeId: input.nodeId },
      )
      .catch(() => {});
  }

  return { finding: (await getFinding(id))!, isNew: true };
}

const RETURN_FIELDS = `f.id AS id, f.type AS type, f.agentId AS agentId, f.severity AS severity,
  f.title AS title, f.body AS body, f.status AS status, f.nodeId AS nodeId,
  f.workPackageId AS workPackageId, f.alertWpId AS alertWpId, f.followupWpId AS followupWpId,
  f.narrative AS narrative, f.projectId AS projectId, f.projectName AS projectName,
  f.createdAt AS createdAt, f.updatedAt AS updatedAt, f.decidedBy AS decidedBy`;

export async function getFinding(id: string): Promise<StoredFinding | null> {
  const rows = await getGraph().query<StoredFinding>(
    `MATCH (f:AgentFinding { id: $id }) RETURN ${RETURN_FIELDS}`,
    { id },
  );
  return rows[0] ?? null;
}

export async function listFindings(filter?: {
  status?: FindingStatus;
  agentId?: string;
  limit?: number;
}): Promise<StoredFinding[]> {
  const where: string[] = [];
  if (filter?.status) where.push('f.status = $status');
  if (filter?.agentId) where.push('f.agentId = $agentId');
  const rows = await getGraph().query<StoredFinding>(
    `MATCH (f:AgentFinding)
     ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
     RETURN ${RETURN_FIELDS}
     ORDER BY f.updatedAt DESC
     LIMIT ${Math.min(filter?.limit ?? 200, 500)}`,
    { status: filter?.status, agentId: filter?.agentId },
  );
  return rows;
}

export async function setFindingStatus(
  id: string,
  status: FindingStatus,
  opts?: { decidedBy?: string; alertWpId?: number; followupWpId?: number },
): Promise<StoredFinding | null> {
  await getGraph().query(
    `MATCH (f:AgentFinding { id: $id })
     SET f.status = $status, f.updatedAt = $now
         ${opts?.decidedBy ? ', f.decidedBy = $decidedBy' : ''}
         ${opts?.alertWpId ? ', f.alertWpId = $alertWpId' : ''}
         ${opts?.followupWpId ? ', f.followupWpId = $followupWpId' : ''}`,
    {
      id, status, now: new Date().toISOString(),
      decidedBy: opts?.decidedBy, alertWpId: opts?.alertWpId, followupWpId: opts?.followupWpId,
    },
  );
  return getFinding(id);
}

/** Counts per agent for the console roster cards. */
export async function findingCountsByAgent(): Promise<Record<string, { open: number; total: number }>> {
  const rows = await getGraph().query<{ agentId: string; status: string; c: number }>(
    `MATCH (f:AgentFinding)
     RETURN f.agentId AS agentId, f.status AS status, count(f) AS c`,
  );
  const out: Record<string, { open: number; total: number }> = {};
  for (const r of rows) {
    const entry = (out[r.agentId] ??= { open: 0, total: 0 });
    entry.total += r.c;
    if (r.status === 'new' || r.status === 'published') entry.open += r.c;
  }
  return out;
}
