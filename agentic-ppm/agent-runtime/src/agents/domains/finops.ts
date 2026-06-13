/**
 * FinOps domain pack — ported from Kyndral DeepFinOpsAgent + FinOpsAgentAttributes.
 * Financial operations, budget management, EVM, cost optimization.
 */
import type { DomainPack } from './types.js';

export const finopsPack: DomainPack = {
  agentId: 'finops',
  capabilities: [
    'Budget variance analysis',
    'Cost forecasting',
    'ROI optimization',
    'EVM calculations',
    'Financial risk assessment',
    'Multi-step financial planning',
  ],
  attributes: {
    variance: { name: 'variance', displayName: 'Budget Variance', type: 'percentage', description: 'Percentage difference between actual spend and planned budget', unit: '%', source: 'calculated', defaultThresholds: { warning: 15, critical: 20 } },
    burnRate: { name: 'burnRate', displayName: 'Burn Rate', type: 'percentage', description: 'Rate of budget consumption compared to timeline progress', unit: '%', source: 'calculated', defaultThresholds: { warning: 120, critical: 150 } },
    budgetHealth: { name: 'budgetHealth', displayName: 'Budget Health Status', type: 'enum', description: 'Overall financial health assessment', values: ['healthy', 'warning', 'critical', 'overrun'], source: 'calculated', defaultThresholds: { warning: 'warning', critical: 'critical' } },
    remainingBudget: { name: 'remainingBudget', displayName: 'Remaining Budget', type: 'currency', description: 'Unspent budget remaining', unit: '$', source: 'project_field', sourcePath: 'remainingBudget' },
    forecastAccuracy: { name: 'forecastAccuracy', displayName: 'Forecast Accuracy', type: 'percentage', description: 'Accuracy of financial forecasting vs actuals', unit: '%', source: 'calculated', defaultThresholds: { warning: 70, critical: 50 } },
    costPerFeature: { name: 'costPerFeature', displayName: 'Cost Per Feature', type: 'currency', description: 'Average cost per delivered feature', unit: '$', source: 'calculated' },
    totalSpend: { name: 'totalSpend', displayName: 'Total Spend', type: 'currency', description: 'Total budget spent to date', unit: '$', source: 'project_field', sourcePath: 'totalSpend' },
    monthlyBurnAmount: { name: 'monthlyBurnAmount', displayName: 'Monthly Burn Amount', type: 'currency', description: 'Average monthly spending rate', unit: '$', source: 'calculated' },
    budget_line_item: { name: 'budget_line_item', displayName: 'Budget Line Item', type: 'text', description: 'Link to specific funding source', unit: '', source: 'external_api', defaultThresholds: {} },
    investment_horizon: { name: 'investment_horizon', displayName: 'Investment Horizon', type: 'enum', description: 'SAFe investment horizon classification', values: ['H1_Current', 'H2_Emerging', 'H3_Future'], source: 'project_field', defaultThresholds: {} },
    capital_vs_operating: { name: 'capital_vs_operating', displayName: 'CapEx/OpEx', type: 'enum', description: 'Capital vs Operating expense classification for accounting', values: ['CapEx', 'OpEx'], source: 'project_field', defaultThresholds: {} },
    allocated_budget: { name: 'allocated_budget', displayName: 'Allocated Budget', type: 'currency', description: 'Total funding approved for Epic/Feature', unit: '$', source: 'project_field', defaultThresholds: {} },
    actual_spend_to_date: { name: 'actual_spend_to_date', displayName: 'Actual Spend to Date', type: 'currency', description: 'Real-time cost based on labor + tools', unit: '$', source: 'calculated', defaultThresholds: {} },
    burn_rate_monthly: { name: 'burn_rate_monthly', displayName: 'Monthly Burn Rate', type: 'currency', description: 'Projected spend per month', unit: '$', source: 'calculated', defaultThresholds: {} },
    etc_estimate_to_complete: { name: 'etc_estimate_to_complete', displayName: 'ETC (Estimate to Complete)', type: 'currency', description: 'Financial forecast to finish work', unit: '$', source: 'calculated', defaultThresholds: {} },
    eac_estimate_at_completion: { name: 'eac_estimate_at_completion', displayName: 'EAC (Estimate at Completion)', type: 'currency', description: 'Actual + ETC', unit: '$', source: 'calculated', defaultThresholds: {} },
    cost_variance: { name: 'cost_variance', displayName: 'Cost Variance', type: 'currency', description: 'Budget − Actual', unit: '$', source: 'calculated', defaultThresholds: { warning: -50000, critical: -100000 } },
    labor_rate_blended: { name: 'labor_rate_blended', displayName: 'Blended Labor Rate', type: 'currency', description: 'Average cost per team member/day', unit: '$', source: 'calculated', defaultThresholds: {} },
    external_vendor_spend: { name: 'external_vendor_spend', displayName: 'External Vendor Spend', type: 'currency', description: '3rd party contractors/licenses', unit: '$', source: 'external_api', defaultThresholds: {} },
    cost_of_delay_monthly: { name: 'cost_of_delay_monthly', displayName: 'Cost of Delay (Monthly)', type: 'currency', description: 'Revenue/Value lost per month delayed', unit: '$', source: 'calculated', defaultThresholds: { warning: 50000, critical: 100000 } },
    roi_projected: { name: 'roi_projected', displayName: 'Projected ROI', type: 'number', description: 'Expected multiplier (Value/Cost)', unit: 'x', source: 'calculated', defaultThresholds: { warning: 1.5, critical: 1.0 } },
    roi_realized: { name: 'roi_realized', displayName: 'Realized ROI', type: 'number', description: 'Post-launch financial impact', unit: 'x', source: 'calculated', defaultThresholds: {} },
    funding_status: { name: 'funding_status', displayName: 'Funding Status', type: 'enum', description: 'Current funding state', values: ['Funded', 'Partially', 'Pending', 'Over-budget'], source: 'calculated', defaultThresholds: { warning: 'Partially', critical: 'Over-budget' } },
    financial_guardrail_compliance: { name: 'financial_guardrail_compliance', displayName: 'Financial Guardrail Compliance', type: 'boolean', description: 'Within 10% variance limit?', source: 'calculated', defaultThresholds: {} },
    participatory_budget_rank: { name: 'participatory_budget_rank', displayName: 'Participatory Budget Rank', type: 'number', description: 'Ranking from last PB event', unit: 'rank', source: 'project_field', defaultThresholds: {} },
    tax_credit_eligibility: { name: 'tax_credit_eligibility', displayName: 'Tax Credit Eligibility', type: 'boolean', description: 'Is this R&D Tax Credit eligible?', source: 'project_field', defaultThresholds: {} },
    benefit_owner: { name: 'benefit_owner', displayName: 'Benefit Owner', type: 'text', description: 'Exec responsible for realizing value', unit: '', source: 'project_field', defaultThresholds: {} },
    cost_per_story_point: { name: 'cost_per_story_point', displayName: 'Cost Per Story Point', type: 'currency', description: 'ActualSpend/Points', unit: '$', source: 'calculated', defaultThresholds: {} },
    depreciation_schedule: { name: 'depreciation_schedule', displayName: 'Depreciation Schedule', type: 'text', description: 'Asset depreciation timeline (JSON object)', unit: '', source: 'external_api', defaultThresholds: {} },
    amortization_start: { name: 'amortization_start', displayName: 'Amortization Start', type: 'text', description: 'When amortization begins', unit: '', source: 'project_field', defaultThresholds: {} },
    capital_approval_date: { name: 'capital_approval_date', displayName: 'Capital Approval Date', type: 'text', description: 'Board approval date', unit: '', source: 'project_field', defaultThresholds: {} },
    accounting_period: { name: 'accounting_period', displayName: 'Accounting Period', type: 'text', description: 'Fiscal quarter/year', unit: '', source: 'project_field', defaultThresholds: {} },
    cost_center: { name: 'cost_center', displayName: 'Cost Center', type: 'text', description: 'Organizational cost center code', unit: '', source: 'project_field', defaultThresholds: {} },
    gl_account: { name: 'gl_account', displayName: 'GL Account', type: 'text', description: 'General Ledger account number', unit: '', source: 'project_field', defaultThresholds: {} },
    payment_terms: { name: 'payment_terms', displayName: 'Payment Terms', type: 'text', description: 'Vendor payment schedule', unit: '', source: 'external_api', defaultThresholds: {} },
    currency_code: { name: 'currency_code', displayName: 'Currency Code', type: 'text', description: 'ISO currency code', unit: '', source: 'project_field', defaultThresholds: {} },
    exchange_rate: { name: 'exchange_rate', displayName: 'Exchange Rate', type: 'number', description: 'Current forex rate if applicable', unit: 'rate', source: 'external_api', defaultThresholds: {} },
    inflation_adjustment: { name: 'inflation_adjustment', displayName: 'Inflation Adjustment', type: 'percentage', description: 'Annual inflation factor', unit: '%', source: 'calculated', defaultThresholds: {} },
  },
  rules: [
    {
      id: 'finops-high-variance',
      name: 'High Budget Variance Alert',
      description: 'Alert when budget variance exceeds acceptable threshold',
      enabled: true,
      conditions: [{ attribute: 'variance', operator: '>', threshold: 20 }],
      actions: [
        { type: 'alert', targetAgents: ['risk'], severity: 'high', message: 'Budget variance exceeds 20% - financial risk assessment needed' },
        { type: 'notify', targetUsers: ['finops-lead'], severity: 'high', message: 'High budget variance detected - review required' },
      ],
    },
    {
      id: 'finops-critical-burn-rate',
      name: 'Critical Burn Rate',
      description: 'Escalate when burn rate indicates likely budget overrun',
      enabled: true,
      conditions: [{ attribute: 'burnRate', operator: '>', threshold: 150 }],
      actions: [
        { type: 'escalate', targetAgents: ['governance'], severity: 'critical', message: 'Critical burn rate detected - governance review required' },
        { type: 'trigger_agent', targetAgents: ['risk'], severity: 'critical', message: 'High burn rate - assess financial risk' },
      ],
    },
    {
      id: 'finops-budget-overrun',
      name: 'Budget Overrun',
      description: 'Immediate action when budget health is critical or overrun',
      enabled: true,
      conditions: [{ attribute: 'budgetHealth', operator: '==', threshold: 'critical' }],
      actions: [
        { type: 'escalate', targetAgents: ['governance'], severity: 'critical', message: 'Budget in critical state - immediate review needed' },
        { type: 'trigger_agent', targetAgents: ['vro', 'risk'], severity: 'critical', message: 'Budget critical - assess value delivery and risk impact' },
        { type: 'notify', targetUsers: ['finops-lead', 'cfo'], severity: 'critical', message: 'Budget health critical - executive attention required' },
      ],
    },
    {
      id: 'finops-low-forecast-accuracy',
      name: 'Low Forecast Accuracy',
      description: 'Alert when financial forecasting becomes unreliable',
      enabled: true,
      conditions: [{ attribute: 'forecastAccuracy', operator: '<', threshold: 70 }],
      actions: [
        { type: 'alert', targetAgents: ['tmo'], severity: 'medium', message: 'Low forecast accuracy - schedule projections may be unreliable' },
        { type: 'notify', targetUsers: ['finops-lead'], severity: 'medium', message: 'Forecast accuracy below 70% - review forecasting methods' },
      ],
    },
    {
      id: 'finops-remaining-budget-low',
      name: 'Remaining Budget Low',
      description: 'Alert when remaining budget falls below critical threshold',
      enabled: true,
      conditions: [{ attribute: 'remainingBudget', operator: '<', threshold: 100000 }],
      actions: [
        { type: 'alert', targetAgents: ['risk', 'vro'], severity: 'high', message: 'Remaining budget below $100K - assess delivery risk' },
        { type: 'notify', targetUsers: ['finops-lead'], severity: 'high', message: 'Low remaining budget - scope/schedule adjustments may be needed' },
      ],
    },
  ],
};

export default finopsPack;
