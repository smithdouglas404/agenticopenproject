/**
 * Agent roster — the K360 agent domains, declared as the system's spec.
 *
 * Defining the full roster NOW (even though most are not yet implemented) gives
 * the system a stable contract: every Insight/Finding/Recommendation is owned by
 * a known agent, the HITL console can group by agent, and we implement them
 * incrementally without changing the data model.
 *
 * Mirrors the 9 agent domains in ontology/modules/k360.ttl (§2.2 of the README).
 */

export type AgentStatus = 'active' | 'planned';

export interface AgentDomain {
  /** Stable id used on findings/recommendations (provenance). */
  id: string;
  /** Human-facing name. */
  name: string;
  /** K360 domain. */
  domain: string;
  /** What this agent watches over. */
  purpose: string;
  /** Inference detectors / insight types this agent owns (see detectors.ts). */
  owns: string[];
  status: AgentStatus;
}

export const AGENT_ROSTER: AgentDomain[] = [
  {
    id: 'strategic-pmo',
    name: 'Strategic PMO Agent',
    domain: 'Strategic PMO',
    purpose: 'Delivery risk, schedule variance, dependency and portfolio health.',
    owns: ['portfolio-insight', 'OverdueInProgress', 'StaleHighPriority', 'UnownedHighPriority'],
    status: 'active', // implemented as insightsRiskAgent.ts
  },
  {
    id: 'governance',
    name: 'Governance Agent',
    domain: 'Governance',
    purpose: 'Compliance checkpoints, policy violations, stage-gate adherence.',
    owns: ['OrphanedProject', 'MissingGovernanceGate', 'PolicyViolation'],
    status: 'active', // OrphanedProject detector runs in the sweep
  },
  {
    id: 'finops',
    name: 'FinOps Agent',
    domain: 'FinOps',
    purpose: 'Cost anomalies, budget burn, cost optimization.',
    owns: ['CostAnomaly', 'BudgetOverrun'],
    status: 'active',
  },
  {
    id: 'vro',
    name: 'Value Realization Agent',
    domain: 'VRO',
    purpose: 'Benefit realization, value metrics, business outcomes.',
    owns: ['UnrealizedBenefit', 'ValueAtRisk'],
    status: 'active',
  },
  {
    id: 'okr',
    name: 'OKR Alignment Agent',
    domain: 'OKR',
    purpose: 'Objective/key-result cascade and alignment scoring.',
    owns: ['MisalignedInitiative', 'OrphanedObjective'],
    status: 'active',
  },
  {
    id: 'planning',
    name: 'Planning Agent',
    domain: 'Planning',
    purpose: 'Capacity forecast, resource allocation, roadmap feasibility.',
    owns: ['CapacityOverload', 'ResourceConflict'],
    status: 'active', // CapacityOverload detector runs in the sweep
  },
  {
    id: 'ocm',
    name: 'Change Management Agent',
    domain: 'OCM',
    purpose: 'Readiness, adoption barriers, transformation fatigue.',
    owns: ['LowReadinessInitiative', 'TransformationFatigue'],
    status: 'active',
  },
  {
    id: 'tmo',
    name: 'Transformation Agent',
    domain: 'TMO',
    purpose: 'Transformation programs, initiatives, scenario analysis.',
    owns: ['StalledInitiative'],
    status: 'active',
  },
  {
    id: 'notification',
    name: 'Notification Agent',
    domain: 'Notification',
    purpose: 'Routing, escalation paths, alert delivery to the HITL console.',
    owns: ['EscalationRequired'],
    status: 'active',
  },
];

export function getAgent(id: string): AgentDomain | undefined {
  return AGENT_ROSTER.find((a) => a.id === id);
}

/** Which agent owns a given detector/insight type. */
export function agentForFinding(findingType: string): AgentDomain | undefined {
  return AGENT_ROSTER.find((a) => a.owns.includes(findingType));
}
