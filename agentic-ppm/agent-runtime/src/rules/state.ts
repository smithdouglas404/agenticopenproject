/**
 * Rule evaluation state — previous-value + cooldown memory.
 *
 * WHAT: Persists, per (rule, node), the last observed metric value and the last
 * time the rule fired, as (:RuleState) nodes in FalkorDB.
 * WHY: Temporal operators (changed / delta_* / crossed_*) need the PRIOR value,
 * and cooldown_minutes needs the last-fired time, to survive process restarts and
 * to work across the periodic sweep and the event path identically.
 */
import { getGraph } from '../graph/falkor.js';

export interface RuleState {
  id: string;
  ruleId: number;
  nodeId: string;
  /** Numeric when the metric is numeric, else the string value. */
  lastValue: number | string;
  /** ISO timestamp of the last firing (breach), or '' if it has never fired. */
  lastFiredAt: string;
}

function stateId(ruleId: number, nodeId: string): string {
  return `rulestate--${ruleId}--${nodeId}`.replace(/[^A-Za-z0-9_:-]/g, '_');
}

/** Load the stored state for a (rule, node), or null if none yet. */
export async function getState(ruleId: number, nodeId: string): Promise<RuleState | null> {
  const id = stateId(ruleId, nodeId);
  const rows = await getGraph().query<RuleState>(
    `MATCH (s:RuleState { id: $id })
     RETURN s.id AS id, s.ruleId AS ruleId, s.nodeId AS nodeId,
            s.lastValue AS lastValue, s.lastFiredAt AS lastFiredAt`,
    { id },
  );
  return rows[0] ?? null;
}

/**
 * Upsert the state for a (rule, node). Stores lastValue numeric when numeric,
 * else as a string. `firedAt` (ISO) is only written when provided, so updating
 * the observed value on a non-firing pass doesn't reset the cooldown clock.
 */
export async function setState(
  ruleId: number,
  nodeId: string,
  lastValue: number | string,
  firedAt?: string,
): Promise<void> {
  const id = stateId(ruleId, nodeId);
  const props: Record<string, unknown> = {
    id,
    ruleId,
    nodeId,
    lastValue: typeof lastValue === 'number' ? lastValue : String(lastValue),
  };
  if (firedAt) props.lastFiredAt = firedAt;
  await getGraph().query(
    `MERGE (s:RuleState { id: $id })
     SET s += $props`,
    { id, props },
  );
}

/** True when the rule fired within the last cooldownMinutes (so suppress now). */
export function withinCooldown(state: RuleState | null, cooldownMinutes: number): boolean {
  if (!state?.lastFiredAt || cooldownMinutes <= 0) return false;
  const last = Date.parse(state.lastFiredAt);
  if (Number.isNaN(last)) return false;
  return Date.now() - last < cooldownMinutes * 60_000;
}
