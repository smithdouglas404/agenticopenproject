/**
 * Governance domain pack — ported from Kyndral DeepGovernanceAgent + GovernanceAgentAttributes.
 * Compliance, audit, security, policy enforcement, quality gates.
 */
import type { DomainPack } from './types.js';

export const governancePack: DomainPack = {
  agentId: 'governance',
  capabilities: [
    'Compliance status monitoring',
    'Stage-gate approval tracking',
    'Policy violation detection',
    'Escalation management',
    'Regulatory adherence verification',
    'Multi-step compliance planning',
  ],
  attributes: {
    compliance_framework: { name: 'compliance_framework', displayName: 'Compliance Framework', type: 'enum', description: 'Applicable compliance framework', values: ['GDPR', 'SOC2', 'ISO27001', 'HIPAA', 'PCI-DSS'], source: 'project_field', defaultThresholds: {} },
    compliance_version: { name: 'compliance_version', displayName: 'Compliance Version', type: 'text', description: 'Version of framework (e.g., "ISO27001:2013")', unit: '', source: 'project_field', defaultThresholds: {} },
    gate_status: { name: 'gate_status', displayName: 'Gate Status', type: 'enum', description: 'Current gate status', values: ['Open', 'Blocked', 'Conditional'], source: 'calculated', defaultThresholds: { warning: 'Conditional', critical: 'Blocked' } },
    gate_decision_reason: { name: 'gate_decision_reason', displayName: 'Gate Decision Reason', type: 'text', description: 'Why gate is in current state', unit: '', source: 'calculated', defaultThresholds: {} },
    gate_decision_date: { name: 'gate_decision_date', displayName: 'Gate Decision Date', type: 'text', description: 'When status last changed', unit: '', source: 'calculated', defaultThresholds: {} },
    critical_vuln_count: { name: 'critical_vuln_count', displayName: 'Critical Vulnerability Count', type: 'number', description: '# of critical vulnerabilities', unit: 'count', source: 'external_api', defaultThresholds: { warning: 1, critical: 3 } },
    high_vuln_count: { name: 'high_vuln_count', displayName: 'High Vulnerability Count', type: 'number', description: '# of high severity vulnerabilities', unit: 'count', source: 'external_api', defaultThresholds: { warning: 5, critical: 10 } },
    medium_vuln_count: { name: 'medium_vuln_count', displayName: 'Medium Vulnerability Count', type: 'number', description: '# of medium severity vulnerabilities', unit: 'count', source: 'external_api', defaultThresholds: { warning: 20, critical: 50 } },
    vuln_remediation_time_avg: { name: 'vuln_remediation_time_avg', displayName: 'Avg Vulnerability Remediation Time', type: 'number', description: 'Avg time to fix vulnerabilities (days)', unit: 'days', source: 'calculated', defaultThresholds: { warning: 14, critical: 30 } },
    dod_adherence: { name: 'dod_adherence', displayName: 'DoD Adherence', type: 'percentage', description: '% of DoD criteria met', unit: '%', source: 'calculated', defaultThresholds: { warning: 80, critical: 70 } },
    dod_exceptions: { name: 'dod_exceptions', displayName: 'DoD Exceptions', type: 'number', description: '# of approved DoD exceptions', unit: 'count', source: 'project_field', defaultThresholds: { warning: 3, critical: 5 } },
    dod_checklist_items: { name: 'dod_checklist_items', displayName: 'DoD Checklist Items', type: 'text', description: 'List of DoD criteria (array)', unit: '', source: 'project_field', defaultThresholds: {} },
    audit_readiness: { name: 'audit_readiness', displayName: 'Audit Readiness', type: 'percentage', description: 'Readiness for external audit', unit: '%', source: 'calculated', defaultThresholds: { warning: 80, critical: 70 } },
    last_audit_date: { name: 'last_audit_date', displayName: 'Last Audit Date', type: 'text', description: 'Most recent audit', unit: '', source: 'project_field', defaultThresholds: {} },
    next_audit_date: { name: 'next_audit_date', displayName: 'Next Audit Date', type: 'text', description: 'Scheduled next audit', unit: '', source: 'project_field', defaultThresholds: {} },
    audit_findings: { name: 'audit_findings', displayName: 'Audit Findings', type: 'text', description: 'Open findings from last audit (array)', unit: '', source: 'external_api', defaultThresholds: {} },
    audit_score: { name: 'audit_score', displayName: 'Audit Score', type: 'number', description: 'Score from last audit (0-100)', unit: 'score', source: 'external_api', defaultThresholds: { warning: 80, critical: 70 } },
    compliance_debt_count: { name: 'compliance_debt_count', displayName: 'Compliance Debt Count', type: 'number', description: '# of compliance issues', unit: 'count', source: 'calculated', defaultThresholds: { warning: 3, critical: 5 } },
    compliance_debt_severity: { name: 'compliance_debt_severity', displayName: 'Compliance Debt Severity', type: 'enum', description: 'Severity of compliance issues', values: ['Low', 'Medium', 'High', 'Critical'], source: 'calculated', defaultThresholds: { warning: 'High', critical: 'Critical' } },
    compliance_debt_age: { name: 'compliance_debt_age', displayName: 'Compliance Debt Age', type: 'number', description: 'Age of oldest issue (days)', unit: 'days', source: 'calculated', defaultThresholds: { warning: 30, critical: 60 } },
    regulatory_date: { name: 'regulatory_date', displayName: 'Regulatory Date', type: 'text', description: 'Hard deadline for compliance', unit: '', source: 'project_field', defaultThresholds: {} },
    regulatory_risk: { name: 'regulatory_risk', displayName: 'Regulatory Risk', type: 'number', description: 'Risk of regulatory penalty (0-100)', unit: 'score', source: 'calculated', defaultThresholds: { warning: 60, critical: 80 } },
    regulatory_body: { name: 'regulatory_body', displayName: 'Regulatory Body', type: 'text', description: 'Regulating organization', unit: '', source: 'project_field', defaultThresholds: {} },
    control_effectiveness: { name: 'control_effectiveness', displayName: 'Control Effectiveness', type: 'percentage', description: '% controls passing', unit: '%', source: 'calculated', defaultThresholds: { warning: 85, critical: 75 } },
    control_failures: { name: 'control_failures', displayName: 'Control Failures', type: 'number', description: '# of failed controls', unit: 'count', source: 'calculated', defaultThresholds: { warning: 2, critical: 5 } },
    control_test_frequency: { name: 'control_test_frequency', displayName: 'Control Test Frequency', type: 'text', description: 'How often controls tested', unit: '', source: 'project_field', defaultThresholds: {} },
    policy_violations: { name: 'policy_violations', displayName: 'Policy Violations', type: 'number', description: '# violations detected', unit: 'count', source: 'external_api', defaultThresholds: { warning: 2, critical: 5 } },
    policy_version: { name: 'policy_version', displayName: 'Policy Version', type: 'text', description: 'Current policy version', unit: '', source: 'project_field', defaultThresholds: {} },
    policy_review_date: { name: 'policy_review_date', displayName: 'Policy Review Date', type: 'text', description: 'Last policy review', unit: '', source: 'project_field', defaultThresholds: {} },
    security_score: { name: 'security_score', displayName: 'Security Score', type: 'number', description: 'Overall security posture (0-100)', unit: 'score', source: 'external_api', defaultThresholds: { warning: 70, critical: 50 } },
    pen_test_date: { name: 'pen_test_date', displayName: 'Penetration Test Date', type: 'text', description: 'Last penetration test', unit: '', source: 'external_api', defaultThresholds: {} },
    security_exceptions: { name: 'security_exceptions', displayName: 'Security Exceptions', type: 'text', description: 'Approved security exceptions (array)', unit: '', source: 'project_field', defaultThresholds: {} },
  },
  rules: [
    {
      id: 'governance-gate-blocked',
      name: 'Gate Blocked',
      description: 'Alert when governance gate is blocked',
      enabled: true,
      conditions: [{ attribute: 'gate_status', operator: '==', threshold: 'Blocked' }],
      actions: [
        { type: 'block', targetAgents: ['strategic-pmo', 'finops'], severity: 'critical', message: 'Governance gate blocked - no releases until resolved' },
        { type: 'escalate', targetAgents: ['risk'], severity: 'critical', message: 'Governance gate blocked - assess impact' },
        { type: 'notify', targetUsers: ['governance-lead', 'ciso', 'sponsor'], severity: 'critical', message: 'Governance gate blocked - immediate resolution required' },
      ],
    },
    {
      id: 'governance-critical-vulns',
      name: 'Critical Vulnerabilities Detected',
      description: 'Alert when critical vulnerabilities found',
      enabled: true,
      conditions: [{ attribute: 'critical_vuln_count', operator: '>', threshold: 0 }],
      actions: [
        { type: 'block', targetAgents: ['strategic-pmo'], severity: 'critical', message: 'Critical vulnerabilities detected - releases blocked' },
        { type: 'trigger_agent', targetAgents: ['risk'], severity: 'critical', message: 'Critical security vulnerabilities require immediate mitigation' },
        { type: 'notify', targetUsers: ['governance-lead', 'security-lead', 'ciso'], severity: 'critical', message: 'Critical vulnerabilities must be remediated before release' },
      ],
    },
    {
      id: 'governance-low-audit-readiness',
      name: 'Low Audit Readiness',
      description: 'Alert when audit readiness is insufficient',
      enabled: true,
      conditions: [{ attribute: 'audit_readiness', operator: '<', threshold: 80 }],
      actions: [
        { type: 'alert', targetAgents: ['strategic-pmo', 'risk'], severity: 'high', message: 'Audit readiness below 80% - compliance risk' },
        { type: 'notify', targetUsers: ['governance-lead', 'compliance-lead'], severity: 'high', message: 'Low audit readiness - remediation plan needed' },
      ],
    },
    {
      id: 'governance-high-regulatory-risk',
      name: 'High Regulatory Risk',
      description: 'Alert when regulatory risk is high',
      enabled: true,
      conditions: [{ attribute: 'regulatory_risk', operator: '>', threshold: 70 }],
      actions: [
        { type: 'escalate', targetAgents: ['risk'], severity: 'critical', message: 'High regulatory risk - potential penalties' },
        { type: 'notify', targetUsers: ['governance-lead', 'legal-counsel', 'cxo'], severity: 'critical', message: 'High regulatory risk - executive review required' },
      ],
    },
    {
      id: 'governance-low-dod-adherence',
      name: 'Low DoD Adherence',
      description: 'Alert when Definition of Done adherence is low',
      enabled: true,
      conditions: [{ attribute: 'dod_adherence', operator: '<', threshold: 80 }],
      actions: [
        { type: 'alert', targetAgents: ['strategic-pmo'], severity: 'high', message: 'DoD adherence below 80% - quality risk' },
        { type: 'notify', targetUsers: ['governance-lead', 'quality-lead'], severity: 'high', message: 'Low DoD adherence - quality gate review needed' },
      ],
    },
    {
      id: 'governance-policy-violations',
      name: 'Policy Violations Detected',
      description: 'Alert when policy violations are found',
      enabled: true,
      conditions: [{ attribute: 'policy_violations', operator: '>', threshold: 3 }],
      actions: [
        { type: 'alert', targetAgents: ['risk', 'strategic-pmo'], severity: 'high', message: 'Multiple policy violations detected' },
        { type: 'notify', targetUsers: ['governance-lead', 'compliance-lead'], severity: 'high', message: 'Policy violations require investigation and remediation' },
      ],
    },
  ],
};

export default governancePack;
