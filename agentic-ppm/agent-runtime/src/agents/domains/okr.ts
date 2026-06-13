/**
 * OKR Alignment domain pack — ported from Kyndral DeepOKRInferenceAgent.
 * OKR linkage inference, strategic alignment, data quality monitoring.
 *
 * No AttributeDefinition file exists for OKR in Kyndral; attributes inferred from
 * the deep agent's capabilities/tools. No declarative rules in source.
 */
import type { DomainPack } from './types.js';

export const okrPack: DomainPack = {
  agentId: 'okr',
  capabilities: [
    'OKR linkage inference using fuzzy matching',
    'Data completeness assessment',
    'Pattern recognition for strategic alignment',
    'Confidence scoring with reasoning',
    'Data quality monitoring',
    'Multi-step strategic planning',
  ],
  attributes: {
    strategic_alignment_score: { name: 'strategic_alignment_score', displayName: 'Strategic Alignment Score', type: 'number', description: 'Inferred alignment of an initiative to its parent objective/key-result (0-100)', unit: 'score', source: 'calculated', defaultThresholds: { warning: 60, critical: 40 } },
    okr_linkage_confidence: { name: 'okr_linkage_confidence', displayName: 'OKR Linkage Confidence', type: 'percentage', description: 'Confidence in inferred OKR linkage via fuzzy matching', unit: '%', source: 'calculated', defaultThresholds: { warning: 70, critical: 50 } },
    data_completeness_score: { name: 'data_completeness_score', displayName: 'Data Completeness Score', type: 'percentage', description: 'Completeness of OKR/strategic-alignment data for a project', unit: '%', source: 'calculated', defaultThresholds: { warning: 70, critical: 50 } },
    orphaned_objective_count: { name: 'orphaned_objective_count', displayName: 'Orphaned Objective Count', type: 'number', description: 'Objectives with no linked initiatives/key-results', unit: 'count', source: 'calculated', defaultThresholds: { warning: 1, critical: 3 } },
  },
  rules: [],
};

export default okrPack;
