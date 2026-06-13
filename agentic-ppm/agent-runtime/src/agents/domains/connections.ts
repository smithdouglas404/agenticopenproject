/**
 * Agent collaboration graph — ported from Kyndral server/lib/AgentObjectModel.ts
 * (the `connections` arrays on each AGENT_TEMPLATE). This is the a2a routing graph:
 * who reacts to whom, and which attributes flow across each edge.
 *
 * Kyndral agent ids are translated to agent-runtime roster ids: 'pmo' -> 'strategic-pmo'.
 * All other ids (company, finops, governance, vro, tmo, risk, ocm, planning, integrated)
 * map 1:1. The Kyndral `id`/`autoSync` fields are dropped (not in the contract).
 */
import type { AgentConnection } from './types.js';

export const AGENT_CONNECTIONS: AgentConnection[] = [
  // ===== Company (ROOT) provides context to other agents =====
  { fromAgent: 'company', toAgent: 'strategic-pmo', connectionType: 'provides_to', attributes: ['strategicPriorities', 'riskFactors'], bidirectional: false },
  { fromAgent: 'company', toAgent: 'finops', connectionType: 'provides_to', attributes: ['annualRevenue', 'fiscalYear'], bidirectional: false },
  { fromAgent: 'company', toAgent: 'governance', connectionType: 'provides_to', attributes: ['governanceScore', 'riskFactors', 'boardSize'], bidirectional: false },
  { fromAgent: 'company', toAgent: 'vro', connectionType: 'provides_to', attributes: ['strategicPriorities', 'mission', 'vision'], bidirectional: false },

  // ===== PMO (strategic-pmo) subscribes to / escalates to other agents =====
  { fromAgent: 'strategic-pmo', toAgent: 'finops', connectionType: 'subscribes_to', attributes: ['cpi', 'spi', 'budgetVariance'], bidirectional: true },
  { fromAgent: 'strategic-pmo', toAgent: 'risk', connectionType: 'subscribes_to', attributes: ['topRisks', 'riskScore'], bidirectional: true },
  { fromAgent: 'strategic-pmo', toAgent: 'vro', connectionType: 'subscribes_to', attributes: ['benefitsRealized', 'valueScore'], bidirectional: true },
  { fromAgent: 'strategic-pmo', toAgent: 'ocm', connectionType: 'subscribes_to', attributes: ['adoptionRate', 'resistanceAreas'], bidirectional: true },
  { fromAgent: 'strategic-pmo', toAgent: 'tmo', connectionType: 'subscribes_to', attributes: ['scheduleVariance', 'criticalPath'], bidirectional: true },
  { fromAgent: 'strategic-pmo', toAgent: 'governance', connectionType: 'escalates_to', attributes: ['criticalIssues', 'complianceViolations'], bidirectional: false },

  // ===== FinOps =====
  { fromAgent: 'finops', toAgent: 'strategic-pmo', connectionType: 'provides_to', attributes: ['cpi', 'spi', 'budgetVariance'], bidirectional: true },
  { fromAgent: 'finops', toAgent: 'governance', connectionType: 'escalates_to', attributes: ['budgetOverrunAlerts', 'complianceIssues'], bidirectional: false },
  { fromAgent: 'finops', toAgent: 'company', connectionType: 'subscribes_to', attributes: ['annualRevenue', 'fiscalYear'], bidirectional: false },

  // ===== VRO =====
  { fromAgent: 'vro', toAgent: 'strategic-pmo', connectionType: 'provides_to', attributes: ['benefitsRealized', 'valueScore'], bidirectional: true },
  { fromAgent: 'vro', toAgent: 'company', connectionType: 'subscribes_to', attributes: ['strategicPriorities', 'mission'], bidirectional: false },
  { fromAgent: 'vro', toAgent: 'finops', connectionType: 'subscribes_to', attributes: ['actualSpent', 'budgetVariance'], bidirectional: true },

  // ===== TMO =====
  { fromAgent: 'tmo', toAgent: 'strategic-pmo', connectionType: 'provides_to', attributes: ['scheduleVariance', 'criticalPathHealth'], bidirectional: true },

  // ===== Risk =====
  { fromAgent: 'risk', toAgent: 'strategic-pmo', connectionType: 'provides_to', attributes: ['aggregateRiskScore', 'topRisks'], bidirectional: true },
  { fromAgent: 'risk', toAgent: 'governance', connectionType: 'escalates_to', attributes: ['criticalRisks'], bidirectional: false },

  // ===== OCM =====
  { fromAgent: 'ocm', toAgent: 'strategic-pmo', connectionType: 'provides_to', attributes: ['adoptionRate', 'resistanceAreas'], bidirectional: true },

  // ===== Governance =====
  { fromAgent: 'governance', toAgent: 'company', connectionType: 'subscribes_to', attributes: ['governanceScore', 'riskFactors'], bidirectional: false },
  { fromAgent: 'governance', toAgent: 'strategic-pmo', connectionType: 'provides_to', attributes: ['complianceScore', 'activeViolations'], bidirectional: true },

  // ===== Planning =====
  { fromAgent: 'planning', toAgent: 'strategic-pmo', connectionType: 'provides_to', attributes: ['roadmapHealth', 'criticalDependencies'], bidirectional: true },
  { fromAgent: 'planning', toAgent: 'company', connectionType: 'subscribes_to', attributes: ['strategicPriorities'], bidirectional: false },

  // ===== Integrated subscribes to ALL ('*') =====
  { fromAgent: 'integrated', toAgent: 'strategic-pmo', connectionType: 'subscribes_to', attributes: ['*'], bidirectional: false },
];
