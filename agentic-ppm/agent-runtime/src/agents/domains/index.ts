/**
 * Domain registry — the event engine consumes this.
 *
 * Aggregates every ported DomainPack (attributes + rules) and the agent
 * collaboration graph (connections), exposing the lookups the engine needs to run
 * agents EVENT-DRIVEN + RELEVANCE-GATED.
 */
import type { DomainPack, DomainRule, AgentConnection } from './types.js';
import { companyPack } from './company.js';
import { strategicPmoPack } from './strategicPmo.js';
import { governancePack } from './governance.js';
import { finopsPack } from './finops.js';
import { vroPack } from './vro.js';
import { okrPack } from './okr.js';
import { planningPack } from './planning.js';
import { ocmPack } from './ocm.js';
import { tmoPack } from './tmo.js';
import { riskPack } from './risk.js';
import { notificationPack } from './notification.js';
import { integratedPack } from './integrated.js';
import { AGENT_CONNECTIONS } from './connections.js';

/** All domain packs keyed by roster (agent) id. */
export const DOMAIN_PACKS: Record<string, DomainPack> = {
  [companyPack.agentId]: companyPack,
  [strategicPmoPack.agentId]: strategicPmoPack,
  [governancePack.agentId]: governancePack,
  [finopsPack.agentId]: finopsPack,
  [vroPack.agentId]: vroPack,
  [okrPack.agentId]: okrPack,
  [planningPack.agentId]: planningPack,
  [ocmPack.agentId]: ocmPack,
  [tmoPack.agentId]: tmoPack,
  [riskPack.agentId]: riskPack,
  [notificationPack.agentId]: notificationPack,
  [integratedPack.agentId]: integratedPack,
};

export { AGENT_CONNECTIONS } from './connections.js';

/** Look up a single domain pack by roster id. */
export function getDomainPack(agentId: string): DomainPack | undefined {
  return DOMAIN_PACKS[agentId];
}

/** Connection types that mean "this agent reacts to an upstream attribute". */
const SUBSCRIBING_CONNECTION_TYPES: ReadonlySet<AgentConnection['connectionType']> = new Set([
  'subscribes_to',
  'escalates_to',
  'depends_on',
]);

/**
 * Agents that subscribe to (or escalate_to / depend_on) the given attribute via the
 * collaboration graph — i.e. the `fromAgent` of any such edge whose `attributes` list
 * includes the attribute or the wildcard '*'.
 */
export function agentsSubscribedTo(attribute: string): string[] {
  const agents = new Set<string>();
  for (const conn of AGENT_CONNECTIONS) {
    if (!SUBSCRIBING_CONNECTION_TYPES.has(conn.connectionType)) continue;
    if (conn.attributes.includes('*') || conn.attributes.includes(attribute)) {
      agents.add(conn.fromAgent);
    }
  }
  return [...agents];
}

/** Every (agent, rule) whose rule conditions reference the given attribute. */
export function rulesWatching(attribute: string): { agentId: string; rule: DomainRule }[] {
  const out: { agentId: string; rule: DomainRule }[] = [];
  for (const pack of Object.values(DOMAIN_PACKS)) {
    for (const rule of pack.rules) {
      if (rule.conditions.some((c) => c.attribute === attribute)) {
        out.push({ agentId: pack.agentId, rule });
      }
    }
  }
  return out;
}

/** Union of all attributes referenced by rule conditions + connection edges. */
export function allWatchedAttributes(): Set<string> {
  const attrs = new Set<string>();
  for (const pack of Object.values(DOMAIN_PACKS)) {
    for (const rule of pack.rules) {
      for (const cond of rule.conditions) attrs.add(cond.attribute);
    }
  }
  for (const conn of AGENT_CONNECTIONS) {
    for (const attr of conn.attributes) attrs.add(attr);
  }
  return attrs;
}
