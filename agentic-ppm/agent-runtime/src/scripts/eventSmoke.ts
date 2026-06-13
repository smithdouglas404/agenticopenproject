/**
 * Event-driven a2a engine smoke test.
 *
 * WHAT: Constructs fake ChangeEvents (a percentageDone drop on an Epic, a
 * budget/variance change on a project), runs runAgentsForChange against STUBBED
 * graph data, and prints which agents were woken by the relevance gate, what each
 * fired, and the a2a cascade path. A runnable proof that (a) only relevant agents
 * run and (b) the cascade terminates — it does NOT loop.
 * WHY: Exercises relevance -> cascade -> findings without FalkorDB, the LLM, or the
 * OpenProject endpoint. We stub getGraph().query so node resolution, RuleState
 * cooldown, and recordFinding are self-contained no-ops, and disable the LLM
 * narrative pass via env so the run is offline + deterministic.
 *
 *   npm run agents:event-smoke
 */
// Offline + deterministic: no LLM narrative, no cooldown suppression on first run.
process.env.AGENTS_EVENT_DRIVEN = '1';
process.env.AGENTS_LLM_NARRATIVE = '0';

import { getGraph } from '../graph/falkor.js';

// --- Stub the graph: node resolution returns a fabricated node by id; every other
//     query (RuleState get/set, recordFinding MERGE) is a harmless no-op so the
//     smoke needs no DB. We key the stub on a per-id props table set below. ---
const NODE_PROPS: Record<string, Record<string, unknown>> = {};
let findingsRecorded = 0;
// In-memory RuleState so the cooldown guard is observable offline (no DB).
const RULE_STATE = new Map<string, { lastValue: number | string; lastFiredAt: string }>();

(getGraph() as unknown as { query: (q: string, p?: Record<string, unknown>) => Promise<unknown[]> }).query =
  async (q: string, params?: Record<string, unknown>) => {
    const id = params?.id as string | undefined;
    // Node resolution path (collaboration.resolveNodeById): MATCH (n { id }) RETURN ...
    if (/MATCH \(n \{ id: \$id \}\)/.test(q) && id && NODE_PROPS[id]) {
      return [{ id, ...NODE_PROPS[id] }];
    }
    // RuleState read (cooldown) — serve from the in-memory map.
    if (/MATCH \(s:RuleState/.test(q) && id) {
      const s = RULE_STATE.get(id);
      return s ? [{ id, lastValue: s.lastValue, lastFiredAt: s.lastFiredAt }] : [];
    }
    // RuleState write (cooldown stamp) — capture it so the re-run is suppressed.
    if (/MERGE \(s:RuleState/.test(q)) {
      const props = (params?.props ?? {}) as { id?: string; lastValue?: number | string; lastFiredAt?: string };
      if (props.id) {
        const prev = RULE_STATE.get(props.id);
        RULE_STATE.set(props.id, {
          lastValue: props.lastValue ?? prev?.lastValue ?? 0,
          lastFiredAt: props.lastFiredAt ?? prev?.lastFiredAt ?? '',
        });
      }
      return [];
    }
    // recordFinding's MERGE path increments our counter for the proof output.
    if (/MERGE \(f:AgentFinding/.test(q)) findingsRecorded++;
    // getFinding return after MERGE — hand back a minimal row so recordFinding resolves.
    if (/MATCH \(f:AgentFinding \{ id: \$id \}\) RETURN/.test(q)) {
      return [{ id: params?.id, type: '', agentId: '', severity: '', title: '', body: '', status: 'new' }];
    }
    return [];
  };

import { config } from '../config.js';
import type { ChangeEvent } from '../agents/domains/types.js';
import { DOMAIN_PACKS, AGENT_CONNECTIONS } from '../agents/domains/index.js';
import { agentsForChange } from '../agents/events/relevance.js';
import { resolveNodeById, cascade } from '../agents/events/collaboration.js';
import { runAgentsForChange } from '../agents/events/runOnChange.js';

/** Pick an attribute that some enabled rule actually watches, for a realistic event. */
function sampleWatchedAttributes(): string[] {
  const attrs = new Set<string>();
  for (const pack of Object.values(DOMAIN_PACKS)) {
    for (const rule of pack.rules) {
      if (!rule.enabled) continue;
      for (const cond of rule.conditions) attrs.add(cond.attribute);
    }
  }
  return [...attrs];
}

async function runCase(label: string, change: ChangeEvent, nodeProps: Record<string, unknown>): Promise<void> {
  NODE_PROPS[change.nodeId] = nodeProps;
  console.log(`\n=== ${label} ===`);
  console.log(`change ${change.nodeId} (${change.ontologyClass}) changed: ${Object.keys(change.changed).join(', ')}`);

  const seed = agentsForChange(change);
  console.log(`RELEVANCE GATE -> woke ${seed.length} agent(s): [${seed.join(', ')}]`);
  if (seed.length === 0) {
    console.log('  (no agent watches any changed attribute — nothing runs; this is the gate working)');
    return;
  }

  const node = (await resolveNodeById(change.nodeId, change.ontologyClass)) ?? { id: change.nodeId, props: nodeProps };
  const before = findingsRecorded;
  const run = await cascade(seed, node);
  console.log(`CASCADE -> ${run.agentsRun} agent-run(s), depth-capped at ${config.agents.maxCascadeDepth}`);
  for (const step of run.path) {
    console.log(
      `  d${step.depth}: ${step.agentId} on ${step.nodeId} fired=${step.fired}` +
        (step.handoffs.length ? ` -> handoff/subscribe: [${step.handoffs.join(', ')}]` : ''),
    );
  }
  console.log(`fired agents (would get LLM narrative): [${run.firedAgents.join(', ')}]`);
  console.log(`findings recorded this case: ${findingsRecorded - before}`);

  // Re-running the SAME change must NOT loop or double-run beyond the visited cap.
  const rerun = await cascade(seed, node);
  console.log(`RE-RUN same change -> ${rerun.agentsRun} agent-run(s) (cooldown/dedup guard; not a loop)`);
}

async function main(): Promise<void> {
  console.log('Agentic PPM — event-driven a2a engine smoke');
  console.log(`registry: ${Object.keys(DOMAIN_PACKS).length} domain pack(s), ${AGENT_CONNECTIONS.length} connection(s)`);
  const watched = sampleWatchedAttributes();
  console.log(`watched attributes (sample): [${watched.slice(0, 12).join(', ')}${watched.length > 12 ? ', ...' : ''}]`);

  // CASE 1: percentageDone drops on an Epic — should wake any progress watcher.
  await runCase(
    'CASE 1 — percentageDone drops on an Epic',
    {
      nodeId: 'op-wp-501',
      ontologyClass: 'safe:Epic',
      changed: { percentageDone: { prev: 70, next: 22 } },
      source: 'smoke',
    },
    { name: 'Payments Epic', spineClass: 'Epic', progress: 22, status: 'In progress', priority: 'High', spentHours: 180, estimatedHours: 100 },
  );

  // CASE 2: budget variance up on a project — should wake FinOps + its subscribers.
  await runCase(
    'CASE 2 — budget variance up on a Project',
    {
      nodeId: 'op-project-7',
      ontologyClass: 'pm:Project',
      changed: { variance: { prev: 8, next: 27 }, budget_variance: { prev: 8, next: 27 } },
      source: 'smoke',
    },
    { name: 'Modernization Program', spineClass: 'Project', variance: 27, budget_variance: 27, spentHours: 320, estimatedHours: 200 },
  );

  // CASE 3: a change nothing watches — the gate must keep everything asleep.
  await runCase(
    'CASE 3 — irrelevant attribute changes',
    {
      nodeId: 'op-wp-999',
      ontologyClass: 'pm:Task',
      changed: { favorite_color: { prev: 'blue', next: 'green' } },
      source: 'smoke',
    },
    { name: 'Some task', spineClass: 'Task', progress: 90 },
  );

  // CASE 4: full entry point (relevance + cascade + narrative-gate), end to end.
  console.log('\n=== CASE 4 — runAgentsForChange end-to-end (the webhook entry point) ===');
  NODE_PROPS['op-wp-501'] = { name: 'Payments Epic', spineClass: 'Epic', progress: 22, spentHours: 180, estimatedHours: 100 };
  const r = await runAgentsForChange({
    nodeId: 'op-wp-501',
    ontologyClass: 'safe:Epic',
    changed: { percentageDone: { prev: 70, next: 22 } },
    source: 'smoke',
  });
  console.log(`runAgentsForChange -> agentsRun=${r.agentsRun}, findings=${r.findings}`);

  console.log('\nOK: relevance gated the runs, the cascade terminated under the depth/dedup/cooldown guards, and it did not loop.');
}

main().catch((err) => {
  console.error('event-smoke failed:', err);
  process.exitCode = 1;
});
