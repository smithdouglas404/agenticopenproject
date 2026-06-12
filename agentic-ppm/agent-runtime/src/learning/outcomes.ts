/**
 * Learning loop (GROUNDING_AND_HALLUCINATION.md §3) — predictions → outcomes →
 * accuracy → weighting.
 *
 * Findings with teeth (high/medium severity on a real node) are recorded as
 * (:Prediction) nodes with a DETERMINISTIC claim derived from the finding type.
 * The sweep later resolves each open prediction against the graph state of its
 * node (did the item slip? did it get an owner?), and the HITL decision path
 * supplies the strongest label of all: a human approved or rejected the finding.
 * Per-agent accuracy over resolved predictions then auto-tunes the published
 * severity of future findings — provable learning, not vibes.
 */
import { getGraph } from '../graph/falkor.js';
import { getFinding, type StoredFinding } from '../store/findings.js';
import { OPEN_STATUSES_EXCLUDED } from '../agents/detectors.js';
import { config } from '../config.js';

export type FindingSeverityLevel = 'low' | 'medium' | 'high';

export interface Prediction {
  id: string;
  findingId: string;
  agentId: string;
  type: string;
  nodeId: string;
  predictedAt: string;
  claim: string;
  status: 'open' | 'resolved';
  outcome?: string;
  correctness?: string;
  resolvedAt?: string;
}

export interface AgentAccuracy {
  total: number;
  correct: number;
  incorrect: number;
  humanConfirmed: number;
  humanRejected: number;
  /** (correct + humanConfirmed) / (those + incorrect + humanRejected); null if <3 resolved. */
  accuracy: number | null;
}

/** Deterministic claim per finding type — no LLM, so the ledger is auditable. */
function claimFor(type: string, recommendation?: string): string {
  switch (type) {
    case 'OverdueInProgress':
      return 'will remain overdue/slip';
    case 'UnownedHighPriority':
      return 'will stay unowned without intervention';
    case 'CapacityOverload':
      return 'assignee load will remain above the capacity threshold';
    case 'OrphanedProject':
      return 'work item will remain outside project governance';
    default:
      return recommendation?.trim() || `finding of type ${type} will hold`;
  }
}

const PREDICTION_FIELDS = `p.id AS id, p.findingId AS findingId, p.agentId AS agentId, p.type AS type,
  p.nodeId AS nodeId, p.predictedAt AS predictedAt, p.claim AS claim, p.status AS status,
  p.outcome AS outcome, p.correctness AS correctness, p.resolvedAt AS resolvedAt`;

/**
 * Record a prediction for a finding worth tracking (severity high/medium with a
 * concrete subject). Idempotent: one prediction per finding id.
 */
export async function recordPrediction(finding: {
  id: string;
  type: string;
  agentId: string;
  severity: string;
  nodeId?: string;
  workPackageId?: number;
  projectId?: number;
  recommendation?: string;
}): Promise<void> {
  if (!config.learning.enabled) return;
  if (finding.severity !== 'high' && finding.severity !== 'medium') return;
  if (!finding.nodeId || (!finding.workPackageId && !finding.projectId && !/^op-/.test(finding.nodeId))) return;

  const graph = getGraph();
  const id = `prediction--${finding.id}`;
  const existing = await graph.query<{ id: string }>(
    `MATCH (p:Prediction { id: $id }) RETURN p.id AS id`,
    { id },
  );
  if (existing.length > 0) return;

  await graph.query(
    `MERGE (p:Prediction { id: $id }) SET p += $props`,
    {
      id,
      props: {
        id,
        findingId: finding.id,
        agentId: finding.agentId,
        type: finding.type,
        nodeId: finding.nodeId,
        predictedAt: new Date().toISOString(),
        claim: claimFor(finding.type, finding.recommendation),
        status: 'open',
      },
    },
  );
}

interface NodeState {
  status?: string;
  endDate?: string;
  assignee?: string;
}

function isClosed(status?: string): boolean {
  return !!status && OPEN_STATUSES_EXCLUDED.includes(status);
}

const STILL_OPEN_GRACE_DAYS = 7;

/**
 * Resolve open predictions against (a) the HITL label on the finding — the most
 * reliable signal, weighted strongest — and (b) the current graph state of the
 * predicted node. Deterministic per finding type.
 */
export async function resolveOutcomes(): Promise<{ resolved: number }> {
  if (!config.learning.enabled) return { resolved: 0 };
  const graph = getGraph();
  const open = await graph.query<Prediction>(
    `MATCH (p:Prediction { status: 'open' }) RETURN ${PREDICTION_FIELDS} LIMIT 500`,
  );
  if (open.length === 0) return { resolved: 0 };

  const today = new Date().toISOString().slice(0, 10);
  let resolved = 0;

  for (const p of open) {
    let outcome: string | null = null;
    let correctness: string | null = null;

    // (1) HITL label first — a human approving/rejecting the alert is the most
    // reliable label we have; it always wins.
    const finding = await getFinding(p.findingId).catch(() => null);
    if (finding?.status === 'approved') {
      outcome = 'human-confirmed';
      correctness = 'correct';
    } else if (finding?.status === 'rejected') {
      outcome = 'human-rejected';
      correctness = 'incorrect';
    }

    // (2) Graph-state resolution per finding type.
    if (!outcome) {
      const rows = await graph
        .query<NodeState>(
          `MATCH (n { id: $nodeId })
           RETURN n.status AS status, n.endDate AS endDate, n.assignee AS assignee LIMIT 1`,
          { nodeId: p.nodeId },
        )
        .catch(() => [] as NodeState[]);
      const node = rows[0];
      if (node) {
        if (p.type === 'OverdueInProgress') {
          if (isClosed(node.status)) {
            // Closed after its endDate (it did slip) → correct; closed with the
            // deadline moved into the future (recovered on time) → incorrect.
            const slipped = !node.endDate || node.endDate < today;
            outcome = 'closed';
            correctness = slipped ? 'correct' : 'incorrect';
          } else if (
            node.endDate && node.endDate < today &&
            Date.parse(p.predictedAt) < Date.now() - STILL_OPEN_GRACE_DAYS * 86_400_000
          ) {
            // Still open past due well after the call was made → it did slip.
            outcome = 'still-overdue';
            correctness = 'correct';
          }
        } else if (p.type === 'UnownedHighPriority') {
          if (node.assignee && node.assignee !== '') {
            // Ownership arrived after the alert — the alert drove/coincided with
            // it; mark addressed rather than claiming predictive correctness.
            outcome = 'addressed';
            correctness = 'addressed';
          } else if (isClosed(node.status)) {
            outcome = 'closed';
            correctness = 'unknown';
          }
        } else if (isClosed(node.status)) {
          // Generic reasoning findings: node closed, no type-specific logic.
          outcome = 'closed';
          correctness = 'unknown';
        }
      }
    }

    if (!outcome) continue;
    await graph.query(
      `MATCH (p:Prediction { id: $id })
       SET p.status = 'resolved', p.outcome = $outcome, p.correctness = $correctness, p.resolvedAt = $now`,
      { id: p.id, outcome, correctness: correctness ?? 'unknown', now: new Date().toISOString() },
    );
    resolved++;
  }

  if (resolved > 0) console.log(`[learning] resolved ${resolved} prediction(s)`);
  return { resolved };
}

/**
 * Resolve a prediction immediately from a HITL decision (called from the shared
 * decision path, so both the console and OpenProject-status HITL record labels).
 */
export async function recordHumanDecision(
  finding: StoredFinding,
  decision: 'approved' | 'rejected',
): Promise<void> {
  if (!config.learning.enabled) return;
  const outcome = decision === 'approved' ? 'human-confirmed' : 'human-rejected';
  const correctness = decision === 'approved' ? 'correct' : 'incorrect';
  await getGraph()
    .query(
      `MATCH (p:Prediction { findingId: $findingId, status: 'open' })
       SET p.status = 'resolved', p.outcome = $outcome, p.correctness = $correctness, p.resolvedAt = $now`,
      { findingId: finding.id, outcome, correctness, now: new Date().toISOString() },
    )
    .catch((err) => console.warn(`[learning] human label failed for ${finding.id}: ${err.message}`));
}

/** Per-agent track record over resolved predictions. */
export async function agentAccuracy(): Promise<Record<string, AgentAccuracy>> {
  const rows = await getGraph().query<{ agentId: string; outcome: string; correctness: string; c: number }>(
    `MATCH (p:Prediction { status: 'resolved' })
     RETURN p.agentId AS agentId, p.outcome AS outcome, p.correctness AS correctness, count(p) AS c`,
  );
  const out: Record<string, AgentAccuracy> = {};
  for (const r of rows) {
    const a = (out[r.agentId] ??= { total: 0, correct: 0, incorrect: 0, humanConfirmed: 0, humanRejected: 0, accuracy: null });
    a.total += r.c;
    if (r.outcome === 'human-confirmed') a.humanConfirmed += r.c;
    else if (r.outcome === 'human-rejected') a.humanRejected += r.c;
    else if (r.correctness === 'correct') a.correct += r.c;
    else if (r.correctness === 'incorrect') a.incorrect += r.c;
  }
  for (const a of Object.values(out)) {
    const positive = a.correct + a.humanConfirmed;
    const denom = positive + a.incorrect + a.humanRejected;
    a.accuracy = a.total >= 3 && denom > 0 ? Math.round((positive / denom) * 100) / 100 : null;
  }
  return out;
}

/** Recently resolved predictions, newest first (console "track record" feed). */
export async function recentResolvedPredictions(limit = 20): Promise<Prediction[]> {
  return getGraph().query<Prediction>(
    `MATCH (p:Prediction { status: 'resolved' })
     RETURN ${PREDICTION_FIELDS}
     ORDER BY p.resolvedAt DESC LIMIT ${Math.min(limit, 100)}`,
  );
}

// Accuracy cache so per-finding publish-time adjustments don't re-query the
// graph for every finding in a sweep.
let accuracyCache: { at: number; data: Record<string, AgentAccuracy> } | null = null;
async function cachedAccuracy(): Promise<Record<string, AgentAccuracy>> {
  if (accuracyCache && Date.now() - accuracyCache.at < 60_000) return accuracyCache.data;
  const data = await agentAccuracy().catch(() => ({}) as Record<string, AgentAccuracy>);
  accuracyCache = { at: Date.now(), data };
  return data;
}

const DOWNGRADE: Record<FindingSeverityLevel, FindingSeverityLevel> = {
  high: 'medium',
  medium: 'low',
  low: 'low',
};

export const SEVERITY_AUTOTUNE_NOTE = '(severity auto-tuned by track record)';

/**
 * Track-record weighting applied at publish time: an agent whose accuracy over
 * ≥5 resolved predictions is below 0.4 gets its published severity downgraded
 * one notch. Conservative by design — good track records never UPGRADE severity.
 */
export async function severityAdjustment(
  agentId: string,
  severity: FindingSeverityLevel,
): Promise<{ severity: FindingSeverityLevel; adjusted: boolean; note?: string }> {
  if (!config.learning.enabled || !config.grounding.autoTuneSeverity) {
    return { severity, adjusted: false };
  }
  const acc = (await cachedAccuracy())[agentId];
  if (!acc || acc.total < 5 || acc.accuracy === null) return { severity, adjusted: false };
  if (acc.accuracy < 0.4 && severity !== 'low') {
    return { severity: DOWNGRADE[severity], adjusted: true, note: SEVERITY_AUTOTUNE_NOTE };
  }
  return { severity, adjusted: false };
}
