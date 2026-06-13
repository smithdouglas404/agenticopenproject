/**
 * Agent roster — lightweight attribution registry for deterministic findings.
 *
 * This is NOT an LLM reasoning roster. It gives detector- and rule-produced
 * findings a stable owner (id/name/domain), so the HITL console can group and
 * attribute findings by signal source. The actual reasoning agents live in the
 * separate Kyndral repo; this runtime only grounds + attributes.
 *
 * Mirrors the K360 agent domains in ontology/modules/k360.ttl (§2.2 of the README).
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
    owns: ['portfolio-insight', 'OverdueInProgress', 'StaleHighPriority', 'UnownedHighPriority', 'ReleaseAtRisk'],
    status: 'active',
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
    owns: ['CostAnomaly', 'CostBurnWithoutProgress', 'BudgetOverrun'],
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
    owns: ['CapacityOverload', 'ResourceConflict', 'BlockedCriticalWork'],
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
    id: 'rules',
    name: 'Rules Agent',
    domain: 'Rules',
    purpose: 'Evaluate OpenProject-authored rules against the world-model and raise breaches.',
    owns: ['RuleBreach'],
    status: 'active', // rules evaluator runs in the sweep + event path
  },
  {
    id: 'risk',
    name: 'Risk Agent',
    domain: 'Risk',
    purpose: 'Risk identification, probability/impact scoring, mitigation tracking and risk-driven escalation across the portfolio.',
    owns: ['RiskBreach', 'ValueAtRisk', 'EmergingRisk'],
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
