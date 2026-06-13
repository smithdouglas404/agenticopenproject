/**
 * Planning domain pack — ported from Kyndral DeepPlanningAgent + PlanningAgentAttributes.
 * Capacity planning, resource management, sprint/PI planning, feasibility analysis.
 */
import type { DomainPack } from './types.js';

export const planningPack: DomainPack = {
  agentId: 'planning',
  capabilities: [
    'Dependency analysis and tracking',
    'Resource capacity planning',
    'Roadmap conflict detection',
    'Cross-team coordination',
    'Blocked work item management',
    'Multi-step planning optimization',
  ],
  attributes: {
    plan_id: { name: 'plan_id', displayName: 'Plan ID', type: 'text', description: 'Unique identifier for PI or Sprint plan', unit: '', source: 'project_field', defaultThresholds: {} },
    total_capacity_pts: { name: 'total_capacity_pts', displayName: 'Total Capacity (Points)', type: 'number', description: 'Aggregated story points available across teams', unit: 'points', source: 'calculated', defaultThresholds: {} },
    load_vs_capacity_ratio: { name: 'load_vs_capacity_ratio', displayName: 'Load vs Capacity Ratio', type: 'number', description: 'Planned Points / Capacity (goal: < 90%)', unit: 'ratio', source: 'calculated', defaultThresholds: { warning: 0.85, critical: 0.95 } },
    uncommitted_objectives: { name: 'uncommitted_objectives', displayName: 'Uncommitted Objectives', type: 'number', description: 'Count of "Stretch" goals for PI', unit: 'count', source: 'project_field', defaultThresholds: {} },
    dependency_map_id: { name: 'dependency_map_id', displayName: 'Dependency Map ID', type: 'text', description: 'Link to visual cross-team dependency string', unit: '', source: 'project_field', defaultThresholds: {} },
    critical_path_id: { name: 'critical_path_id', displayName: 'Critical Path ID', type: 'text', description: 'Sequence of features dictating end date', unit: '', source: 'calculated', defaultThresholds: {} },
    buffer_allocation_pct: { name: 'buffer_allocation_pct', displayName: 'Buffer Allocation %', type: 'percentage', description: 'Points held back for emergent work', unit: '%', source: 'project_field', defaultThresholds: { warning: 10, critical: 5 } },
    historical_velocity_avg: { name: 'historical_velocity_avg', displayName: 'Historical Velocity (Avg)', type: 'number', description: '3-PI average of points delivered', unit: 'points', source: 'calculated', defaultThresholds: {} },
    planning_confidence_score: { name: 'planning_confidence_score', displayName: 'Planning Confidence Score', type: 'number', description: 'Team vote during PI Planning (1-5)', unit: 'score', source: 'project_field', defaultThresholds: { warning: 3, critical: 2 } },
    cross_art_sync_status: { name: 'cross_art_sync_status', displayName: 'Cross-ART Sync Status', type: 'enum', description: 'Synchronization status across ARTs', values: ['In-Sync', 'Lagging', 'Conflict Detected'], source: 'calculated', defaultThresholds: { warning: 'Lagging', critical: 'Conflict Detected' } },
    milestone_alignment: { name: 'milestone_alignment', displayName: 'Milestone Alignment', type: 'boolean', description: 'Does plan hit hard "Fixed-Date" milestones?', source: 'calculated', defaultThresholds: {} },
    resource_bottleneck_id: { name: 'resource_bottleneck_id', displayName: 'Resource Bottleneck ID', type: 'text', description: 'Shared service over-capacity (UX, DevOps)', unit: '', source: 'calculated', defaultThresholds: {} },
    capacity_leaks: { name: 'capacity_leaks', displayName: 'Capacity Leaks', type: 'number', description: 'Points lost to non-value work', unit: 'points', source: 'calculated', defaultThresholds: { warning: 10, critical: 20 } },
    plan_volatility_idx: { name: 'plan_volatility_idx', displayName: 'Plan Volatility Index', type: 'number', description: 'Rate of change to plan after PI start', unit: 'index', source: 'calculated', defaultThresholds: { warning: 0.3, critical: 0.5 } },
    iteration_cadence_days: { name: 'iteration_cadence_days', displayName: 'Iteration Cadence (Days)', type: 'number', description: 'Length of sprint cycles', unit: 'days', source: 'project_field', defaultThresholds: {} },
    backlog_readiness_idx: { name: 'backlog_readiness_idx', displayName: 'Backlog Readiness Index', type: 'percentage', description: '% features meeting "Definition of Ready"', unit: '%', source: 'calculated', defaultThresholds: { warning: 70, critical: 50 } },
    feature_priority_rank: { name: 'feature_priority_rank', displayName: 'Feature Priority Rank', type: 'number', description: 'Global stack rank', unit: 'rank', source: 'project_field', defaultThresholds: {} },
    team_stability_score: { name: 'team_stability_score', displayName: 'Team Stability Score', type: 'percentage', description: '% team members consistent (no churn)', unit: '%', source: 'calculated', defaultThresholds: { warning: 80, critical: 70 } },
    sync_frequency_hrs: { name: 'sync_frequency_hrs', displayName: 'Sync Frequency (Hours)', type: 'number', description: 'How often agent polls for plan changes', unit: 'hours', source: 'project_field', defaultThresholds: {} },
    sprint_goal_attainment: { name: 'sprint_goal_attainment', displayName: 'Sprint Goal Attainment', type: 'percentage', description: 'Historical success rate hitting goals', unit: '%', source: 'calculated', defaultThresholds: { warning: 75, critical: 60 } },
    sprint_overrun_avg: { name: 'sprint_overrun_avg', displayName: 'Sprint Overrun (Avg)', type: 'number', description: 'Average sprint overrun (days)', unit: 'days', source: 'calculated', defaultThresholds: { warning: 1, critical: 2 } },
    holiday_calendar_ref: { name: 'holiday_calendar_ref', displayName: 'Holiday Calendar Reference', type: 'text', description: 'Reference to org holiday schedule', unit: '', source: 'project_field', defaultThresholds: {} },
    timezone_offset: { name: 'timezone_offset', displayName: 'Timezone Offset', type: 'text', description: 'Team timezone', unit: '', source: 'project_field', defaultThresholds: {} },
    program_board_health: { name: 'program_board_health', displayName: 'Program Board Health', type: 'number', description: 'Program board quality score (0-100)', unit: 'score', source: 'calculated', defaultThresholds: { warning: 70, critical: 50 } },
    feature_cycle_time: { name: 'feature_cycle_time', displayName: 'Feature Cycle Time', type: 'number', description: 'Avg time to complete features (days)', unit: 'days', source: 'calculated', defaultThresholds: { warning: 30, critical: 60 } },
    technical_debt_ratio: { name: 'technical_debt_ratio', displayName: 'Technical Debt Ratio', type: 'percentage', description: 'Technical debt vs new features', unit: '%', source: 'calculated', defaultThresholds: { warning: 30, critical: 50 } },
    test_automation_coverage: { name: 'test_automation_coverage', displayName: 'Test Automation Coverage', type: 'percentage', description: 'Automated test coverage', unit: '%', source: 'external_api', defaultThresholds: { warning: 70, critical: 50 } },
    built_in_quality_score: { name: 'built_in_quality_score', displayName: 'Built-in Quality Score', type: 'number', description: 'Quality practices score (0-100)', unit: 'score', source: 'calculated', defaultThresholds: { warning: 70, critical: 50 } },
    release_on_demand_capability: { name: 'release_on_demand_capability', displayName: 'Release on Demand Capability', type: 'boolean', description: 'Can release any time?', source: 'calculated', defaultThresholds: {} },
    team_sync_effectiveness: { name: 'team_sync_effectiveness', displayName: 'Team Sync Effectiveness', type: 'number', description: 'Sync meeting quality score (0-100)', unit: 'score', source: 'calculated', defaultThresholds: { warning: 70, critical: 50 } },
  },
  rules: [
    {
      id: 'planning-overloaded-capacity',
      name: 'Overloaded Capacity',
      description: 'Alert when load exceeds capacity',
      enabled: true,
      conditions: [{ attribute: 'load_vs_capacity_ratio', operator: '>', threshold: 0.9 }],
      actions: [
        { type: 'alert', targetAgents: ['strategic-pmo', 'tmo'], severity: 'high', message: 'Load exceeds 90% capacity - risk of burnout and delivery failure' },
        { type: 'notify', targetUsers: ['planning-lead', 'team-lead'], severity: 'high', message: 'Capacity overload - reduce scope or extend timeline' },
      ],
    },
    {
      id: 'planning-low-confidence',
      name: 'Low Planning Confidence',
      description: 'Alert when planning confidence is low',
      enabled: true,
      conditions: [{ attribute: 'planning_confidence_score', operator: '<', threshold: 3 }],
      actions: [
        { type: 'alert', targetAgents: ['risk', 'strategic-pmo'], severity: 'high', message: 'Low planning confidence - high delivery risk' },
        { type: 'notify', targetUsers: ['planning-lead'], severity: 'high', message: 'Team confidence in plan is low - review and adjust' },
      ],
    },
    {
      id: 'planning-cross-art-conflict',
      name: 'Cross-ART Conflict',
      description: 'Alert when cross-ART conflicts detected',
      enabled: true,
      conditions: [{ attribute: 'cross_art_sync_status', operator: '==', threshold: 'Conflict Detected' }],
      actions: [
        { type: 'escalate', targetAgents: ['governance'], severity: 'critical', message: 'Cross-ART conflict detected - resolution needed' },
        { type: 'notify', targetUsers: ['planning-lead', 'rte'], severity: 'critical', message: 'Cross-ART conflict requires immediate resolution' },
      ],
    },
    {
      id: 'planning-low-backlog-readiness',
      name: 'Low Backlog Readiness',
      description: 'Alert when backlog is not ready',
      enabled: true,
      conditions: [{ attribute: 'backlog_readiness_idx', operator: '<', threshold: 70 }],
      actions: [
        { type: 'alert', targetAgents: ['strategic-pmo'], severity: 'medium', message: 'Backlog readiness below 70% - refinement needed' },
        { type: 'notify', targetUsers: ['planning-lead', 'po'], severity: 'medium', message: 'Insufficient backlog refinement - delivery at risk' },
      ],
    },
    {
      id: 'planning-high-volatility',
      name: 'High Plan Volatility',
      description: 'Alert when plan is changing too much',
      enabled: true,
      conditions: [{ attribute: 'plan_volatility_idx', operator: '>', threshold: 0.4 }],
      actions: [
        { type: 'alert', targetAgents: ['strategic-pmo', 'ocm'], severity: 'high', message: 'High plan volatility - stability and morale at risk' },
        { type: 'notify', targetUsers: ['planning-lead'], severity: 'high', message: 'Excessive plan changes - review change management' },
      ],
    },
  ],
};

export default planningPack;
