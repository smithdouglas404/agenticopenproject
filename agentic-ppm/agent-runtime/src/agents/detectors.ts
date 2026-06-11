/**
 * Inference detectors — the K360 "derived risk classes" as Cypher.
 *
 * The ontology declares inference classes (OrphanedProject, CostAnomaly, …) that
 * a triplestore reasoner would derive. FalkorDB has no reasoner, so we implement
 * them as explicit, auditable Cypher queries. Each detector belongs to an agent
 * in the roster and emits findings the inbox can publish.
 *
 * Only detectors that work on the data currently in the graph (work items with
 * status/priority/dates/assignee + Project containment) are active. Cost/Objective
 * detectors light up once those entities are ingested.
 */
import { getGraph } from '../graph/falkor.js';
import { config } from '../config.js';

export type FindingSeverity = 'low' | 'medium' | 'high';

export interface DetectorFinding {
  type: string;
  agentId: string;
  severity: FindingSeverity;
  title: string;
  body: string;
  nodeId: string;
  workPackageId?: number;
}

export interface Detector {
  type: string;
  agentId: string;
  description: string;
  run(): Promise<DetectorFinding[]>;
}

const OPEN_STATUSES_EXCLUDED = ['Closed', 'Rejected', 'Done', 'Completed', 'On hold'];
const WORK_LABELS = ['Task', 'Story', 'Feature', 'Epic', 'Issue'];
const HIGH_PRIORITIES = ['High', 'Immediate', 'Urgent', 'Critical'];

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

function wpId(nodeId: string): number | undefined {
  const m = nodeId.match(/op-wp-(\d+)/);
  return m ? Number(m[1]) : undefined;
}

interface Row {
  id: string;
  name: string;
  status?: string;
  priority?: string;
  endDate?: string;
  source?: string;
}

/** Past-due work that is still open. */
const overdueInProgress: Detector = {
  type: 'OverdueInProgress',
  agentId: 'strategic-pmo',
  description: 'Work item whose end date has passed but is not closed.',
  async run() {
    const rows = await getGraph().query<Row>(
      `MATCH (w)
       WHERE w.spineClass IN $labels
         AND w.endDate IS NOT NULL AND w.endDate < $today
         AND NOT coalesce(w.status, 'New') IN $closed
       RETURN w.id AS id, w.name AS name, w.status AS status, w.endDate AS endDate, w.source AS source
       LIMIT 100`,
      { labels: WORK_LABELS, today: today(), closed: OPEN_STATUSES_EXCLUDED },
    );
    return rows.map((r) => ({
      type: 'OverdueInProgress',
      agentId: 'strategic-pmo',
      severity: 'high' as FindingSeverity,
      title: `Overdue: "${r.name}"`,
      body: `Due ${r.endDate} but still "${r.status ?? 'open'}" (source: ${r.source ?? 'openproject'}).`,
      nodeId: r.id,
      workPackageId: wpId(r.id),
    }));
  },
};

/** High-priority work with no owner. */
const unownedHighPriority: Detector = {
  type: 'UnownedHighPriority',
  agentId: 'strategic-pmo',
  description: 'High-priority work item with no assignee.',
  async run() {
    const rows = await getGraph().query<Row>(
      `MATCH (w)
       WHERE w.spineClass IN $labels
         AND coalesce(w.priority, 'Normal') IN $high
         AND (w.assignee IS NULL OR w.assignee = '')
         AND NOT coalesce(w.status, 'New') IN $closed
       RETURN w.id AS id, w.name AS name, w.priority AS priority, w.status AS status
       LIMIT 100`,
      { labels: WORK_LABELS, high: HIGH_PRIORITIES, closed: OPEN_STATUSES_EXCLUDED },
    );
    return rows.map((r) => ({
      type: 'UnownedHighPriority',
      agentId: 'strategic-pmo',
      severity: 'medium' as FindingSeverity,
      title: `Unowned ${r.priority} work: "${r.name}"`,
      body: `Priority ${r.priority} with no assignee while still "${r.status ?? 'open'}".`,
      nodeId: r.id,
      workPackageId: wpId(r.id),
    }));
  },
};

/** Work item not contained by any project (the available form of OrphanedProject). */
const orphanedWorkItem: Detector = {
  type: 'OrphanedProject',
  agentId: 'governance',
  description: 'Work item with no parent Project (governance lineage gap).',
  async run() {
    const rows = await getGraph().query<Row>(
      `MATCH (w)
       WHERE w.spineClass IN $labels
         AND NOT ( (:Project)-[:CONTAINS]->(w) )
       RETURN w.id AS id, w.name AS name, w.source AS source
       LIMIT 100`,
      { labels: WORK_LABELS },
    );
    return rows.map((r) => ({
      type: 'OrphanedProject',
      agentId: 'governance',
      severity: 'low' as FindingSeverity,
      title: `Orphaned work item: "${r.name}"`,
      body: `Not linked to any project (source: ${r.source ?? 'openproject'}) — governance lineage is incomplete.`,
      nodeId: r.id,
      workPackageId: wpId(r.id),
    }));
  },
};

/** Assignee carrying more open work items than the capacity threshold. */
const capacityOverload: Detector = {
  type: 'CapacityOverload',
  agentId: 'planning',
  description: 'Assignee with more open work items than the capacity threshold.',
  async run() {
    const threshold = config.detectors.capacityThreshold;
    const rows = await getGraph().query<{ assignee: string; open: number }>(
      `MATCH (w)
       WHERE w.spineClass IN $labels
         AND w.assignee IS NOT NULL AND w.assignee <> ''
         AND NOT coalesce(w.status, 'New') IN $closed
       WITH w.assignee AS assignee, count(w) AS open
       WHERE open >= $threshold
       RETURN assignee, open
       LIMIT 50`,
      { labels: WORK_LABELS, closed: OPEN_STATUSES_EXCLUDED, threshold },
    );
    return rows.map((r) => ({
      type: 'CapacityOverload',
      agentId: 'planning',
      severity: (r.open >= threshold * 2 ? 'high' : 'medium') as FindingSeverity,
      title: `${r.assignee} is carrying ${r.open} open items`,
      body: `${r.assignee} has ${r.open} open work items (threshold ${threshold}). Re-balance assignments or re-plan scope.`,
      nodeId: `assignee-${r.assignee}`,
    }));
  },
};

export const DETECTORS: Detector[] = [
  overdueInProgress,
  unownedHighPriority,
  orphanedWorkItem,
  capacityOverload,
];

/** Run all active detectors and return their findings. */
export async function runDetectors(): Promise<DetectorFinding[]> {
  const results = await Promise.all(
    DETECTORS.map((d) =>
      d.run().catch((err) => {
        console.warn(`[detector:${d.type}] failed: ${err.message}`);
        return [] as DetectorFinding[];
      }),
    ),
  );
  return results.flat();
}
