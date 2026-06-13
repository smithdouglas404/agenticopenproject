/**
 * Integrated (cross-cutting) domain pack — ported from Kyndral DeepIntegratedMgmtAgent
 * + the `integrated` AGENT_TEMPLATE. Synthesizes insights/quality across all agents.
 *
 * No AttributeDefinition file exists for Integrated in Kyndral; attributes inferred from
 * the deep agent's capabilities + the AgentObjectModel template. No declarative rules in source.
 */
import type { DomainPack } from './types.js';

export const integratedPack: DomainPack = {
  agentId: 'integrated',
  capabilities: [
    'Quality gate monitoring',
    'Testing metrics analysis',
    'Defect trend tracking',
    'Technical debt assessment',
    'Release readiness evaluation',
    'Multi-step quality planning',
  ],
  attributes: {
    cross_domain_synthesis: { name: 'cross_domain_synthesis', displayName: 'Cross-Domain Synthesis', type: 'text', description: 'Integrated view synthesized across all agent domains (JSON object)', unit: '', source: 'calculated', defaultThresholds: {} },
    detected_correlations: { name: 'detected_correlations', displayName: 'Detected Correlations', type: 'number', description: 'Number of detected correlations between agent signals', unit: 'count', source: 'calculated', defaultThresholds: {} },
    release_readiness_score: { name: 'release_readiness_score', displayName: 'Release Readiness Score', type: 'number', description: 'Composite release readiness across quality/testing/debt (0-100)', unit: 'score', source: 'calculated', defaultThresholds: { warning: 70, critical: 50 } },
  },
  rules: [],
};

export default integratedPack;
