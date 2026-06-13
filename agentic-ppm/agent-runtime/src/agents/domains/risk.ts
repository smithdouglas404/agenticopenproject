/**
 * Risk domain pack — ported from Kyndral DeepRiskAgent + RiskAgentAttributes.
 * Risk assessment, mitigation planning, ROAM, risk scoring.
 *
 * NOTE: 'risk' is a NEW roster id (the parent agent adds it to roster.ts).
 */
import type { DomainPack } from './types.js';

export const riskPack: DomainPack = {
  agentId: 'risk',
  capabilities: [
    'Risk probability analysis',
    'Impact assessment and calculation',
    'Mitigation strategy evaluation',
    'Risk trend forecasting',
    'Response plan recommendations',
    'Multi-step risk planning',
  ],
  attributes: {
    riskScore: { name: 'riskScore', displayName: 'Overall Risk Score', type: 'number', description: 'Composite risk score based on all identified risks (0-100)', unit: 'score', source: 'calculated', defaultThresholds: { warning: 50, critical: 70 } },
    probabilityOfFailure: { name: 'probabilityOfFailure', displayName: 'Probability of Failure', type: 'percentage', description: 'Calculated probability that project will fail to meet objectives', unit: '%', source: 'calculated', defaultThresholds: { warning: 40, critical: 70 } },
    highPriorityRisksCount: { name: 'highPriorityRisksCount', displayName: 'High Priority Risks Count', type: 'number', description: 'Number of high or critical priority risks', unit: 'count', source: 'calculated', defaultThresholds: { warning: 3, critical: 5 } },
    financialExposure: { name: 'financialExposure', displayName: 'Financial Exposure', type: 'currency', description: 'Total potential financial impact of identified risks', unit: '$', source: 'calculated', defaultThresholds: { warning: 500000, critical: 1000000 } },
    scheduleExposure: { name: 'scheduleExposure', displayName: 'Schedule Exposure', type: 'number', description: 'Potential schedule delay in days from risks', unit: 'days', source: 'calculated', defaultThresholds: { warning: 14, critical: 30 } },
    mitigationCoverage: { name: 'mitigationCoverage', displayName: 'Mitigation Coverage', type: 'percentage', description: 'Percentage of risks with active mitigation plans', unit: '%', source: 'calculated', defaultThresholds: { warning: 70, critical: 50 } },
    emergingRisksCount: { name: 'emergingRisksCount', displayName: 'Emerging Risks Count', type: 'number', description: 'Number of newly identified risks in last period', unit: 'count', source: 'calculated', defaultThresholds: { warning: 2, critical: 4 } },
    riskTrend: { name: 'riskTrend', displayName: 'Risk Trend', type: 'enum', description: 'Direction of overall risk trajectory', values: ['improving', 'stable', 'worsening', 'critical'], source: 'calculated', defaultThresholds: { warning: 'worsening', critical: 'critical' } },
    risk_id: { name: 'risk_id', displayName: 'Risk ID', type: 'text', description: 'Unique risk identifier', unit: '', source: 'project_field', defaultThresholds: {} },
    parent_risk_id: { name: 'parent_risk_id', displayName: 'Parent Risk ID', type: 'text', description: 'Parent risk if this is a sub-risk', unit: '', source: 'project_field', defaultThresholds: {} },
    roam_status: { name: 'roam_status', displayName: 'ROAM Status', type: 'enum', description: 'ROAM classification', values: ['Resolved', 'Owned', 'Accepted', 'Mitigated'], source: 'project_field', defaultThresholds: {} },
    exposure_value: { name: 'exposure_value', displayName: 'Exposure Value', type: 'currency', description: 'Financial exposure (Probability × Impact)', unit: '$', source: 'calculated', defaultThresholds: { warning: 50000, critical: 100000 } },
    impact_score: { name: 'impact_score', displayName: 'Impact Score', type: 'number', description: 'Severity if risk occurs (1-10)', unit: 'score', source: 'project_field', defaultThresholds: { warning: 7, critical: 9 } },
    probability_score: { name: 'probability_score', displayName: 'Probability Score', type: 'number', description: 'Likelihood of occurrence (0-1)', unit: 'score', source: 'calculated', defaultThresholds: { warning: 0.7, critical: 0.9 } },
    risk_score_calc: { name: 'risk_score_calc', displayName: 'Risk Score (Calculated)', type: 'number', description: 'impact_score × probability_score × 10', unit: 'score', source: 'calculated', defaultThresholds: { warning: 50, critical: 70 } },
    risk_category: { name: 'risk_category', displayName: 'Risk Category', type: 'enum', description: 'Type of risk', values: ['Technical', 'Schedule', 'Budget', 'Resource', 'External'], source: 'project_field', defaultThresholds: {} },
    risk_tier: { name: 'risk_tier', displayName: 'Risk Tier', type: 'enum', description: 'Level at which risk exists', values: ['Portfolio', 'Program', 'Team'], source: 'project_field', defaultThresholds: {} },
    mitigation_strategy: { name: 'mitigation_strategy', displayName: 'Mitigation Strategy', type: 'text', description: 'Planned response', unit: '', source: 'project_field', defaultThresholds: {} },
    mitigation_owner: { name: 'mitigation_owner', displayName: 'Mitigation Owner', type: 'text', description: 'Person responsible', unit: '', source: 'project_field', defaultThresholds: {} },
    mitigation_cost: { name: 'mitigation_cost', displayName: 'Mitigation Cost', type: 'currency', description: 'Cost to mitigate', unit: '$', source: 'calculated', defaultThresholds: {} },
    mitigation_deadline: { name: 'mitigation_deadline', displayName: 'Mitigation Deadline', type: 'text', description: 'When mitigation must be complete', unit: '', source: 'project_field', defaultThresholds: {} },
    mitigation_status: { name: 'mitigation_status', displayName: 'Mitigation Status', type: 'enum', description: 'Status of mitigation effort', values: ['Not Started', 'In Progress', 'Complete'], source: 'project_field', defaultThresholds: { warning: 'Not Started' } },
    mitigation_velocity: { name: 'mitigation_velocity', displayName: 'Mitigation Velocity', type: 'number', description: 'Risks mitigated per period', unit: 'count', source: 'calculated', defaultThresholds: { warning: 2, critical: 1 } },
    residual_risk: { name: 'residual_risk', displayName: 'Residual Risk', type: 'number', description: 'Risk remaining after mitigation', unit: 'score', source: 'calculated', defaultThresholds: { warning: 30, critical: 50 } },
    residual_exposure: { name: 'residual_exposure', displayName: 'Residual Exposure', type: 'currency', description: 'Financial exposure after mitigation', unit: '$', source: 'calculated', defaultThresholds: { warning: 25000, critical: 50000 } },
    risk_burndown_rate: { name: 'risk_burndown_rate', displayName: 'Risk Burndown Rate', type: 'number', description: 'Risks closed per period', unit: 'count', source: 'calculated', defaultThresholds: {} },
    risk_velocity: { name: 'risk_velocity', displayName: 'Risk Velocity', type: 'number', description: 'New risks identified per period', unit: 'count', source: 'calculated', defaultThresholds: { warning: 5, critical: 10 } },
    threat_opportunity_ratio: { name: 'threat_opportunity_ratio', displayName: 'Threat/Opportunity Ratio', type: 'number', description: 'Negative vs positive risks', unit: 'ratio', source: 'calculated', defaultThresholds: {} },
    contingency_reserve: { name: 'contingency_reserve', displayName: 'Contingency Reserve', type: 'currency', description: 'Remaining risk budget', unit: '$', source: 'project_field', defaultThresholds: { warning: 50000, critical: 25000 } },
    contingency_used: { name: 'contingency_used', displayName: 'Contingency Used', type: 'currency', description: 'Reserve already consumed', unit: '$', source: 'calculated', defaultThresholds: {} },
    risk_response_type: { name: 'risk_response_type', displayName: 'Risk Response Type', type: 'enum', description: 'Type of risk response', values: ['Avoid', 'Transfer', 'Mitigate', 'Accept', 'Exploit'], source: 'project_field', defaultThresholds: {} },
    risk_response_effectiveness: { name: 'risk_response_effectiveness', displayName: 'Risk Response Effectiveness', type: 'percentage', description: '% risks successfully mitigated', unit: '%', source: 'calculated', defaultThresholds: { warning: 70, critical: 50 } },
    dependency_risks: { name: 'dependency_risks', displayName: 'Dependency Risks', type: 'text', description: 'Risks related to dependencies (array)', unit: '', source: 'calculated', defaultThresholds: {} },
    external_dependencies: { name: 'external_dependencies', displayName: 'External Dependencies', type: 'text', description: 'Risks from external parties (array)', unit: '', source: 'project_field', defaultThresholds: {} },
    risk_identified_date: { name: 'risk_identified_date', displayName: 'Risk Identified Date', type: 'text', description: 'When risk was first identified', unit: '', source: 'project_field', defaultThresholds: {} },
    risk_closed_date: { name: 'risk_closed_date', displayName: 'Risk Closed Date', type: 'text', description: 'When risk was resolved', unit: '', source: 'project_field', defaultThresholds: {} },
    last_assessment_date: { name: 'last_assessment_date', displayName: 'Last Assessment Date', type: 'text', description: 'Last time risk was reviewed', unit: '', source: 'calculated', defaultThresholds: {} },
    escalation_required: { name: 'escalation_required', displayName: 'Escalation Required', type: 'boolean', description: 'Does this need executive attention?', source: 'calculated', defaultThresholds: {} },
    escalation_level: { name: 'escalation_level', displayName: 'Escalation Level', type: 'enum', description: 'Level of escalation', values: ['Team', 'Program', 'Portfolio', 'Executive'], source: 'calculated', defaultThresholds: { warning: 'Portfolio', critical: 'Executive' } },
  },
  rules: [
    {
      id: 'risk-critical-score',
      name: 'Critical Risk Score Alert',
      description: 'Escalate when overall risk score reaches critical level',
      enabled: true,
      conditions: [{ attribute: 'riskScore', operator: '>', threshold: 70 }],
      actions: [
        { type: 'escalate', targetAgents: ['governance'], severity: 'critical', message: 'Risk score critical - governance review required' },
        { type: 'trigger_agent', targetAgents: ['finops', 'vro'], severity: 'high', message: 'High risk detected - assess financial and value impact' },
        { type: 'notify', targetUsers: ['risk-lead', 'pmo-lead'], severity: 'critical', message: 'Critical risk level - immediate action required' },
      ],
    },
    {
      id: 'risk-high-failure-probability',
      name: 'High Probability of Failure',
      description: 'Alert when failure probability exceeds acceptable threshold',
      enabled: true,
      conditions: [{ attribute: 'probabilityOfFailure', operator: '>', threshold: 70 }],
      actions: [
        { type: 'escalate', targetAgents: ['governance', 'vro'], severity: 'critical', message: 'High probability of failure - strategic review needed' },
        { type: 'trigger_agent', targetAgents: ['tmo', 'finops'], severity: 'critical', message: 'Failure risk high - assess schedule and budget recovery options' },
      ],
    },
    {
      id: 'risk-high-financial-exposure',
      name: 'High Financial Exposure',
      description: 'Alert when potential financial impact is significant',
      enabled: true,
      conditions: [{ attribute: 'financialExposure', operator: '>', threshold: 1000000 }],
      actions: [
        { type: 'alert', targetAgents: ['finops'], severity: 'critical', message: 'Financial exposure exceeds $1M - budget contingency assessment needed' },
        { type: 'notify', targetUsers: ['risk-lead', 'finops-lead', 'cfo'], severity: 'critical', message: 'High financial risk exposure - executive review required' },
      ],
    },
    {
      id: 'risk-low-mitigation-coverage',
      name: 'Low Mitigation Coverage',
      description: 'Alert when too many risks lack mitigation plans',
      enabled: true,
      conditions: [{ attribute: 'mitigationCoverage', operator: '<', threshold: 70 }],
      actions: [
        { type: 'alert', targetAgents: ['strategic-pmo'], severity: 'medium', message: 'Low mitigation coverage - risk response planning needed' },
        { type: 'notify', targetUsers: ['risk-lead'], severity: 'medium', message: 'Less than 70% of risks have mitigation plans' },
      ],
    },
    {
      id: 'risk-worsening-trend',
      name: 'Worsening Risk Trend',
      description: 'Alert when risk trend is deteriorating',
      enabled: true,
      conditions: [{ attribute: 'riskTrend', operator: '==', threshold: 'worsening' }],
      actions: [
        { type: 'alert', targetAgents: ['strategic-pmo', 'tmo'], severity: 'high', message: 'Risk trend worsening - review project health' },
        { type: 'notify', targetUsers: ['risk-lead', 'pmo-lead'], severity: 'high', message: 'Risk trajectory deteriorating - intervention may be needed' },
      ],
    },
    {
      id: 'risk-schedule-exposure-high',
      name: 'High Schedule Exposure',
      description: 'Alert when schedule risk exposure is significant',
      enabled: true,
      conditions: [{ attribute: 'scheduleExposure', operator: '>', threshold: 30 }],
      actions: [
        { type: 'alert', targetAgents: ['tmo'], severity: 'high', message: 'Schedule exposure exceeds 30 days - timeline recovery assessment needed' },
        { type: 'trigger_agent', targetAgents: ['vro'], severity: 'high', message: 'Schedule delays may impact value delivery' },
      ],
    },
  ],
};

export default riskPack;
