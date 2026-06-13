/**
 * Strategic PMO domain pack — ported from Kyndral DeepPMOAgent + PMOAgentAttributes.
 * Portfolio management, project health, SAFe flow + delivery metrics, governance.
 *
 * NOTE: source Kyndral types `string`/`date` are mapped to the contract `text`;
 * sources `external`/`input`/`system` are mapped to `external_api`/`project_field`/`calculated`.
 */
import type { DomainPack } from './types.js';

export const strategicPmoPack: DomainPack = {
  agentId: 'strategic-pmo',
  capabilities: [
    'Project health analysis',
    'Milestone tracking and prediction',
    'Resource optimization',
    'Governance enforcement',
    'Status report generation',
    'Multi-step portfolio planning',
  ],
  attributes: {
    projectHealthScore: { name: 'projectHealthScore', displayName: 'Project Health Score', type: 'number', description: 'Composite project health score (0-100)', unit: 'score', source: 'calculated', defaultThresholds: { warning: 60, critical: 40 } },
    onTimeDeliveryRate: { name: 'onTimeDeliveryRate', displayName: 'On-Time Delivery Rate', type: 'percentage', description: 'Percentage of deliverables completed on time', unit: '%', source: 'calculated', defaultThresholds: { warning: 80, critical: 60 } },
    teamVelocityTrend: { name: 'teamVelocityTrend', displayName: 'Team Velocity Trend', type: 'percentage', description: 'Change in team velocity over recent periods', unit: '%', source: 'calculated', defaultThresholds: { warning: -15, critical: -30 } },
    qualityMetrics: { name: 'qualityMetrics', displayName: 'Quality Score', type: 'number', description: 'Composite quality score based on defects, rework, and reviews', unit: 'score', source: 'calculated', defaultThresholds: { warning: 70, critical: 50 } },
    deliveryPredictability: { name: 'deliveryPredictability', displayName: 'Delivery Predictability', type: 'percentage', description: 'Consistency in meeting delivery commitments', unit: '%', source: 'calculated', defaultThresholds: { warning: 75, critical: 60 } },
    teamMoraleScore: { name: 'teamMoraleScore', displayName: 'Team Morale Score', type: 'number', description: 'Team satisfaction and engagement score (0-100)', unit: 'score', source: 'calculated', defaultThresholds: { warning: 60, critical: 40 } },
    scopeCreep: { name: 'scopeCreep', displayName: 'Scope Creep', type: 'percentage', description: 'Percentage of scope growth beyond baseline', unit: '%', source: 'calculated', defaultThresholds: { warning: 15, critical: 30 } },
    issueResolutionTime: { name: 'issueResolutionTime', displayName: 'Avg Issue Resolution Time', type: 'number', description: 'Average days to resolve issues', unit: 'days', source: 'calculated', defaultThresholds: { warning: 7, critical: 14 } },
    feature_uuid: { name: 'feature_uuid', displayName: 'Feature UUID', type: 'text', description: 'Global unique identifier across ALM tools', unit: '', source: 'external_api', defaultThresholds: {} },
    parent_epic_id: { name: 'parent_epic_id', displayName: 'Parent Epic ID', type: 'text', description: 'Upward traceability to Portfolio', unit: '', source: 'external_api', defaultThresholds: {} },
    art_id: { name: 'art_id', displayName: 'ART ID', type: 'text', description: 'The specific Agile Release Train responsible', unit: '', source: 'external_api', defaultThresholds: {} },
    wsjf_score: { name: 'wsjf_score', displayName: 'WSJF Score', type: 'number', description: 'Weighted Shortest Job First (CoD/JobSize) primary priority driver', unit: 'score', source: 'calculated', defaultThresholds: { warning: 5, critical: 3 } },
    user_business_value: { name: 'user_business_value', displayName: 'User Business Value', type: 'number', description: 'Component of Cost of Delay (1-20)', unit: 'score', source: 'project_field', defaultThresholds: { warning: 10, critical: 5 } },
    time_criticality: { name: 'time_criticality', displayName: 'Time Criticality', type: 'number', description: 'Component of Cost of Delay (1-20)', unit: 'score', source: 'project_field', defaultThresholds: { warning: 10, critical: 5 } },
    rroe_value: { name: 'rroe_value', displayName: 'RR/OE Value', type: 'number', description: 'Risk Reduction / Opportunity Enablement - Component of CoD (1-20)', unit: 'score', source: 'project_field', defaultThresholds: { warning: 10, critical: 5 } },
    estimated_story_points: { name: 'estimated_story_points', displayName: 'Estimated Story Points', type: 'number', description: 'Total size of feature in points', unit: 'points', source: 'external_api', defaultThresholds: {} },
    actual_points_completed: { name: 'actual_points_completed', displayName: 'Actual Points Completed', type: 'number', description: 'Real-time burn count from synced Stories', unit: 'points', source: 'external_api', defaultThresholds: {} },
    percent_complete: { name: 'percent_complete', displayName: 'Percent Complete', type: 'percentage', description: 'Actual/Estimated completion percentage', unit: '%', source: 'calculated', defaultThresholds: {} },
    flow_status: { name: 'flow_status', displayName: 'Flow Status', type: 'text', description: 'SAFe flow state: Funnel, Analyzing, Backlog, Implementing, Validating, Done', unit: '', source: 'external_api', defaultThresholds: {} },
    wip_age: { name: 'wip_age', displayName: 'WIP Age', type: 'number', description: 'Time elapsed since entering "Implementing" status (days)', unit: 'days', source: 'calculated', defaultThresholds: { warning: 14, critical: 30 } },
    flow_efficiency: { name: 'flow_efficiency', displayName: 'Flow Efficiency', type: 'percentage', description: 'Active Time / Total Lead Time (%)', unit: '%', source: 'calculated', defaultThresholds: { warning: 40, critical: 20 } },
    cycle_time_avg: { name: 'cycle_time_avg', displayName: 'Avg Cycle Time', type: 'number', description: 'Average time to finish similar features', unit: 'days', source: 'calculated', defaultThresholds: { warning: 30, critical: 60 } },
    lead_time: { name: 'lead_time', displayName: 'Lead Time', type: 'number', description: 'Total time from Funnel to Done', unit: 'days', source: 'calculated', defaultThresholds: { warning: 90, critical: 120 } },
    dependency_count: { name: 'dependency_count', displayName: 'Dependency Count', type: 'number', description: 'Number of blocked/blocking links', unit: 'count', source: 'external_api', defaultThresholds: { warning: 3, critical: 5 } },
    blocker_status: { name: 'blocker_status', displayName: 'Blocker Status', type: 'boolean', description: 'Is there an active "Red" impediment?', unit: '', source: 'external_api', defaultThresholds: {} },
    planned_finish_date: { name: 'planned_finish_date', displayName: 'Planned Finish Date', type: 'text', description: 'Targeted PI/Sprint end', unit: '', source: 'external_api', defaultThresholds: {} },
    forecasted_finish_date: { name: 'forecasted_finish_date', displayName: 'Forecasted Finish Date', type: 'text', description: 'Agent-calculated date based on current velocity', unit: '', source: 'calculated', defaultThresholds: {} },
    say_do_variance: { name: 'say_do_variance', displayName: 'Say-Do Variance', type: 'number', description: 'Variance between planned vs actual points', unit: 'points', source: 'calculated', defaultThresholds: { warning: 20, critical: 40 } },
    refinement_depth: { name: 'refinement_depth', displayName: 'Refinement Depth', type: 'percentage', description: '% of child stories with "Ready" status', unit: '%', source: 'calculated', defaultThresholds: { warning: 70, critical: 50 } },
    quality_gate_status: { name: 'quality_gate_status', displayName: 'Quality Gate Status', type: 'text', description: 'Pass/Fail based on Definition of Done (DoD)', unit: '', source: 'calculated', defaultThresholds: {} },
    enabler_ratio: { name: 'enabler_ratio', displayName: 'Enabler Ratio', type: 'number', description: 'Ratio of technical debt/infrastructure vs business value', unit: 'ratio', source: 'calculated', defaultThresholds: { warning: 0.4, critical: 0.6 } },
    team_velocity_current: { name: 'team_velocity_current', displayName: 'Current Team Velocity', type: 'number', description: 'Combined velocity of teams assigned to feature', unit: 'points', source: 'calculated', defaultThresholds: {} },
    sprint_load_factor: { name: 'sprint_load_factor', displayName: 'Sprint Load Factor', type: 'number', description: 'Current WIP vs Capacity for assigned teams', unit: 'ratio', source: 'calculated', defaultThresholds: { warning: 0.85, critical: 0.95 } },
    scope_growth: { name: 'scope_growth', displayName: 'Scope Growth', type: 'percentage', description: 'Points added after Feature was "In Progress"', unit: '%', source: 'calculated', defaultThresholds: { warning: 20, critical: 35 } },
    release_vehicle_id: { name: 'release_vehicle_id', displayName: 'Release Vehicle ID', type: 'text', description: 'The deployment package ID', unit: '', source: 'external_api', defaultThresholds: {} },
    feature_owner: { name: 'feature_owner', displayName: 'Feature Owner', type: 'text', description: 'Human PM responsible', unit: '', source: 'external_api', defaultThresholds: {} },
    last_sync_timestamp: { name: 'last_sync_timestamp', displayName: 'Last Sync Timestamp', type: 'text', description: 'When agent last polled the ALM', unit: '', source: 'calculated', defaultThresholds: {} },
    agent_health_status: { name: 'agent_health_status', displayName: 'Agent Health Status', type: 'text', description: 'Green/Yellow/Red for data integrity', unit: '', source: 'calculated', defaultThresholds: {} },
  },
  rules: [
    {
      id: 'pmo-low-health-score',
      name: 'Low Project Health Score',
      description: 'Alert when overall project health is declining',
      enabled: true,
      conditions: [{ attribute: 'projectHealthScore', operator: '<', threshold: 60 }],
      actions: [
        { type: 'alert', targetAgents: ['risk', 'vro'], severity: 'high', message: 'Project health below 60 - risk and value assessment needed' },
        { type: 'notify', targetUsers: ['pmo-lead', 'sponsor'], severity: 'high', message: 'Project health declining - intervention required' },
      ],
    },
    {
      id: 'pmo-low-delivery-rate',
      name: 'Low On-Time Delivery Rate',
      description: 'Alert when delivery performance is poor',
      enabled: true,
      conditions: [{ attribute: 'onTimeDeliveryRate', operator: '<', threshold: 80 }],
      actions: [
        { type: 'alert', targetAgents: ['tmo'], severity: 'high', message: 'On-time delivery below 80% - schedule management review needed' },
        { type: 'trigger_agent', targetAgents: ['risk'], severity: 'high', message: 'Poor delivery performance - assess delivery risks' },
        { type: 'notify', targetUsers: ['pmo-lead', 'delivery-manager'], severity: 'high', message: 'On-time delivery rate low - process improvement needed' },
      ],
    },
    {
      id: 'pmo-velocity-decline',
      name: 'Declining Team Velocity',
      description: 'Alert when team velocity is trending downward',
      enabled: true,
      conditions: [{ attribute: 'teamVelocityTrend', operator: '<', threshold: -20 }],
      actions: [
        { type: 'alert', targetAgents: ['tmo', 'ocm'], severity: 'high', message: 'Team velocity declining 20% - schedule impact and morale assessment needed' },
        { type: 'notify', targetUsers: ['pmo-lead', 'team-lead'], severity: 'high', message: 'Team velocity declining significantly - investigate impediments' },
      ],
    },
    {
      id: 'pmo-quality-issues',
      name: 'Quality Issues',
      description: 'Alert when quality metrics are below acceptable levels',
      enabled: true,
      conditions: [{ attribute: 'qualityMetrics', operator: '<', threshold: 70 }],
      actions: [
        { type: 'alert', targetAgents: ['risk'], severity: 'high', message: 'Quality score below 70 - technical debt and rework risks' },
        { type: 'notify', targetUsers: ['pmo-lead', 'quality-lead'], severity: 'high', message: 'Quality metrics declining - quality assurance review needed' },
      ],
    },
    {
      id: 'pmo-low-predictability',
      name: 'Low Delivery Predictability',
      description: 'Alert when delivery becomes unpredictable',
      enabled: true,
      conditions: [{ attribute: 'deliveryPredictability', operator: '<', threshold: 75 }],
      actions: [
        { type: 'alert', targetAgents: ['tmo'], severity: 'medium', message: 'Delivery predictability low - estimation and planning improvements needed' },
        { type: 'notify', targetUsers: ['pmo-lead'], severity: 'medium', message: 'Inconsistent delivery performance - process review required' },
      ],
    },
    {
      id: 'pmo-low-morale',
      name: 'Low Team Morale',
      description: 'Alert when team morale is declining',
      enabled: true,
      conditions: [{ attribute: 'teamMoraleScore', operator: '<', threshold: 60 }],
      actions: [
        { type: 'alert', targetAgents: ['ocm'], severity: 'high', message: 'Low team morale - change management and support needed' },
        { type: 'notify', targetUsers: ['pmo-lead', 'team-lead', 'hr-lead'], severity: 'high', message: 'Team morale low - retention and productivity risk' },
      ],
    },
    {
      id: 'pmo-high-scope-creep',
      name: 'High Scope Creep',
      description: 'Alert when scope is growing beyond acceptable levels',
      enabled: true,
      conditions: [{ attribute: 'scopeCreep', operator: '>', threshold: 20 }],
      actions: [
        { type: 'alert', targetAgents: ['finops', 'tmo'], severity: 'high', message: 'Scope creep over 20% - budget and schedule impact assessment needed' },
        { type: 'trigger_agent', targetAgents: ['governance'], severity: 'high', message: 'High scope creep - scope control and change management review needed' },
        { type: 'notify', targetUsers: ['pmo-lead', 'sponsor'], severity: 'high', message: 'Excessive scope growth - formal scope baseline review required' },
      ],
    },
    {
      id: 'pmo-slow-issue-resolution',
      name: 'Slow Issue Resolution',
      description: 'Alert when issues are taking too long to resolve',
      enabled: true,
      conditions: [{ attribute: 'issueResolutionTime', operator: '>', threshold: 10 }],
      actions: [
        { type: 'alert', targetAgents: ['tmo'], severity: 'medium', message: 'Issue resolution time over 10 days - blocking impacts schedule' },
        { type: 'notify', targetUsers: ['pmo-lead'], severity: 'medium', message: 'Slow issue resolution - process improvement or escalation needed' },
      ],
    },
  ],
};

export default strategicPmoPack;
