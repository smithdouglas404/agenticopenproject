/**
 * Grounding validation layer (GROUNDING_AND_HALLUCINATION.md §2).
 *
 * Every LLM-produced finding passes through here before it is recorded or
 * published. Three controls, all deterministic, no LLM involved:
 *   1. Entity-existence check — every referenced node id must exist in the graph
 *      (a finding about an entity that isn't there is a hallucination; drop it).
 *   2. Claim–evidence consistency — cited evidence (entityId, metric, value) is
 *      re-queried against the graph and compared (tolerance for floats), plus
 *      numeric sanity (progress 0–100, dates parseable).
 *   3. Cross-agent contradiction / convergence check — opposing recommendations
 *      on the same node from different agents are flagged for governance, and
 *      2+ high-severity findings on the same node are surfaced as convergence.
 */
import { getGraph } from '../graph/falkor.js';
import { recordFinding } from '../store/findings.js';
import { config } from '../config.js';

export interface EvidenceItem {
  entityId: string;
  metric: string;
  value: string;
}

export interface GroundingResult {
  ok: boolean;
  entityChecks: { ref: string; exists: boolean }[];
  violations: string[];
  confidence: number;
}

export interface ResolvedEntity {
  id: string;
  name: string;
  type: string;
}

/**
 * Check each referenced node id (e.g. op-wp-42, op-project-7) EXISTS in the
 * graph. Single Cypher round-trip via UNWIND; non-matching refs simply produce
 * no row, so unresolved = refs - resolved.
 */
export async function resolveEntities(
  refs: string[],
): Promise<{ resolved: Map<string, ResolvedEntity>; unresolved: string[] }> {
  const resolved = new Map<string, ResolvedEntity>();
  const unique = [...new Set(refs.filter((r) => !!r && r.trim() !== ''))];
  if (unique.length === 0) return { resolved, unresolved: [] };

  const rows = await getGraph().query<{ id: string; name: string; type: string }>(
    `UNWIND $refs AS ref
     MATCH (n { id: ref })
     RETURN n.id AS id, coalesce(n.name, n.title, '') AS name, coalesce(labels(n)[0], '') AS type`,
    { refs: unique },
  );
  for (const r of rows) resolved.set(r.id, { id: r.id, name: r.name, type: r.type });
  const unresolved = unique.filter((r) => !resolved.has(r));
  return { resolved, unresolved };
}

/** Fetch the raw property bags for a set of node ids (for evidence comparison). */
async function fetchNodeProperties(ids: string[]): Promise<Map<string, Record<string, unknown>>> {
  const out = new Map<string, Record<string, unknown>>();
  const unique = [...new Set(ids.filter((r) => !!r))];
  if (unique.length === 0) return out;
  const rows = await getGraph().query<{ id: string; node: unknown }>(
    `UNWIND $ids AS ref
     MATCH (n { id: ref })
     RETURN n.id AS id, n AS node`,
    { ids: unique },
  );
  for (const r of rows) {
    const props = (r.node as { properties?: Record<string, unknown> })?.properties ?? r.node;
    if (props && typeof props === 'object') out.set(r.id, props as Record<string, unknown>);
  }
  return out;
}

const DATE_METRICS = /date|due|deadline/i;

/** Compare a cited value against the graph value, with float tolerance. */
function valuesMatch(cited: string, actual: unknown): boolean {
  if (actual === null || actual === undefined) return false;
  const citedStr = String(cited).trim();
  const actualStr = String(actual).trim();
  // Numeric compare with tolerance (handles "41", "41%", 41.2 …).
  const citedNum = Number(citedStr.replace(/%$/, ''));
  const actualNum = Number(actualStr.replace(/%$/, ''));
  if (Number.isFinite(citedNum) && Number.isFinite(actualNum)) {
    const diff = Math.abs(citedNum - actualNum);
    return diff <= 0.51 || diff / Math.max(Math.abs(citedNum), Math.abs(actualNum), 1) <= 0.02;
  }
  // String compare, case-insensitive, substring-tolerant either way.
  const a = citedStr.toLowerCase();
  const b = actualStr.toLowerCase();
  return a === b || a.includes(b) || b.includes(a);
}

export interface FindingToValidate {
  title: string;
  severity: string;
  relatedNodeId?: string;
  /** Other entity refs the finding names (e.g. an Insight's linkedEntity values). */
  linkedEntities?: string[];
  evidence?: EvidenceItem[];
  confidence?: number;
}

/**
 * Validate one LLM finding against the graph. A finding whose entity refs do
 * not resolve is NOT publishable (ok=false) — callers drop it and log why.
 * Evidence mismatches and sanity violations lower confidence; the finding is
 * also dropped when confidence falls below config.grounding.minConfidence.
 */
export async function validateFinding(finding: FindingToValidate): Promise<GroundingResult> {
  const violations: string[] = [];
  const entityChecks: { ref: string; exists: boolean }[] = [];

  // ---- 1. Entity existence: relatedNodeId + linkedEntities + evidence ids ----
  const refs = [
    ...(finding.relatedNodeId ? [finding.relatedNodeId] : []),
    ...(finding.linkedEntities ?? []),
    ...(finding.evidence ?? []).map((e) => e.entityId),
  ];
  let unresolvedCount = 0;
  try {
    const { resolved, unresolved } = await resolveEntities(refs);
    for (const ref of new Set(refs.filter(Boolean))) {
      entityChecks.push({ ref, exists: resolved.has(ref) });
    }
    for (const ref of unresolved) {
      violations.push(`references non-existent entity ${ref}`);
      unresolvedCount++;
    }
  } catch (err: any) {
    // Graph unreachable: degrade gracefully — don't fail every finding closed.
    console.warn(`[grounding] entity resolution unavailable: ${err.message}`);
  }

  // ---- 2. Claim–evidence consistency + numeric sanity ----
  let evidenceMismatches = 0;
  if (finding.evidence && finding.evidence.length > 0) {
    const props = await fetchNodeProperties(finding.evidence.map((e) => e.entityId)).catch(
      () => new Map<string, Record<string, unknown>>(),
    );
    for (const ev of finding.evidence) {
      // Numeric sanity: progress must be 0–100.
      if (/progress/i.test(ev.metric)) {
        const n = Number(String(ev.value).replace(/%$/, ''));
        if (Number.isFinite(n) && (n < 0 || n > 100)) {
          violations.push(`evidence ${ev.entityId}.${ev.metric}=${ev.value} out of range 0–100`);
        }
      }
      // Numeric sanity: date-shaped metrics must parse.
      if (DATE_METRICS.test(ev.metric) && Number.isNaN(Date.parse(String(ev.value)))) {
        violations.push(`evidence ${ev.entityId}.${ev.metric}=${ev.value} is not a parseable date`);
      }
      // Re-query and compare against the graph value (only when the metric is a
      // real node property — computed/derived metrics can't be spot-checked here).
      const bag = props.get(ev.entityId);
      if (bag && ev.metric in bag) {
        if (!valuesMatch(ev.value, bag[ev.metric])) {
          violations.push(
            `evidence mismatch on ${ev.entityId}.${ev.metric}: cited "${ev.value}" but graph says "${bag[ev.metric]}"`,
          );
          evidenceMismatches++;
        }
      }
    }
  }

  // ---- Confidence: start from the agent's own, decay per violation ----
  let confidence = finding.confidence ?? 0.7;
  confidence -= unresolvedCount * 0.3 + evidenceMismatches * 0.2;
  confidence -= (violations.length - unresolvedCount - evidenceMismatches) * 0.1;
  confidence = Math.max(0, Math.min(1, confidence));

  const entityOk = !config.grounding.enforceEntityCheck || unresolvedCount === 0;
  const ok = entityOk && confidence >= config.grounding.minConfidence;
  return { ok, entityChecks, violations, confidence };
}

// ---------------------------------------------------------------------------
// Cross-agent contradiction / convergence check
// ---------------------------------------------------------------------------

export interface ContradictionInput {
  id: string;
  agentId: string;
  severity: string;
  title: string;
  nodeId?: string;
  /** Recommendation / narrative text to scan for opposing directions. */
  text?: string;
}

export interface Contradiction {
  kind: 'contradiction' | 'convergence';
  nodeId: string;
  findingIds: string[];
  agentIds: string[];
  detail: string;
}

/** Simple opposing-direction keyword pairs — auditable, no LLM. */
const OPPOSING_PAIRS: [RegExp, RegExp, string][] = [
  [/\bincrease\b/i, /\b(decrease|reduce)\b/i, 'increase vs decrease'],
  [/\b(hire|hiring|add (head ?count|staff|people))\b/i, /\b(freeze|hiring freeze|head ?count freeze)\b/i, 'hire vs freeze'],
  [/\baccelerat/i, /\b(delay|defer|postpone|slow down)\b/i, 'accelerate vs delay'],
  [/\b(add|expand|extend) scope\b/i, /\b(remove|cut|reduce|descope) scope\b/i, 'add vs remove scope'],
  [/\bescalat/i, /\b(de-?prioriti[sz]e|stand down)\b/i, 'escalate vs deprioritize'],
];

/**
 * Pure detection pass: group findings by nodeId and flag (a) opposing
 * recommendations from different agents, (b) 2+ agents converging with
 * high-severity findings on the same node (a signal worth surfacing).
 */
export function detectContradictions(findings: ContradictionInput[]): Contradiction[] {
  const out: Contradiction[] = [];
  const byNode = new Map<string, ContradictionInput[]>();
  for (const f of findings) {
    if (!f.nodeId) continue;
    (byNode.get(f.nodeId) ?? byNode.set(f.nodeId, []).get(f.nodeId)!).push(f);
  }

  for (const [nodeId, group] of byNode) {
    // (a) opposing recommendations from different agents.
    for (let i = 0; i < group.length; i++) {
      for (let j = i + 1; j < group.length; j++) {
        const a = group[i];
        const b = group[j];
        if (a.agentId === b.agentId) continue;
        const ta = a.text ?? '';
        const tb = b.text ?? '';
        if (!ta || !tb) continue;
        for (const [left, right, label] of OPPOSING_PAIRS) {
          if ((left.test(ta) && right.test(tb)) || (left.test(tb) && right.test(ta))) {
            out.push({
              kind: 'contradiction',
              nodeId,
              findingIds: [a.id, b.id],
              agentIds: [a.agentId, b.agentId],
              detail: `Opposing recommendations (${label}) on ${nodeId}: "${a.title}" (${a.agentId}) vs "${b.title}" (${b.agentId})`,
            });
            break;
          }
        }
      }
    }
    // (b) convergence: 2+ distinct agents raising high-severity findings on the node.
    const high = group.filter((f) => f.severity === 'high');
    const highAgents = [...new Set(high.map((f) => f.agentId))];
    if (highAgents.length >= 2) {
      out.push({
        kind: 'convergence',
        nodeId,
        findingIds: high.map((f) => f.id),
        agentIds: highAgents,
        detail: `${highAgents.length} agents (${highAgents.join(', ')}) independently raised high-severity findings on ${nodeId} — convergence signal.`,
      });
    }
  }
  return out;
}

/**
 * Detect AND persist contradictions/convergences as governance AgentFindings
 * (type 'AgentContradiction', deduped by nodeId via the findings store).
 * Returns what was detected; persistence failures are logged, not thrown.
 */
export async function checkContradictions(
  newFindings: ContradictionInput[],
  openFindings: ContradictionInput[],
): Promise<Contradiction[]> {
  // Dedupe by finding id (a new finding may already be in the open list).
  const byId = new Map<string, ContradictionInput>();
  for (const f of [...openFindings, ...newFindings]) byId.set(f.id, f);
  const contradictions = detectContradictions([...byId.values()]);

  for (const c of contradictions) {
    try {
      await recordFinding({
        type: 'AgentContradiction',
        agentId: 'governance',
        severity: 'medium',
        title:
          c.kind === 'convergence'
            ? `Convergence: ${c.agentIds.length} agents flag ${c.nodeId}`
            : `Contradiction on ${c.nodeId}`,
        body: `${c.detail}\n\nLinked findings: ${c.findingIds.join(' · ')}\nSignal: ${c.kind}`,
        nodeId: c.nodeId,
      });
    } catch (err: any) {
      console.warn(`[grounding] failed to persist ${c.kind} for ${c.nodeId}: ${err.message}`);
    }
  }
  return contradictions;
}
