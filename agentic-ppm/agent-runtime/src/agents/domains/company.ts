/**
 * Company (ROOT) context pack — ported from Kyndral CompanyAgentAttributes + COMPANY_AGENT.
 * Company-level context, strategic priorities, enterprise metrics. Provides context to
 * all other agents. This is a context pack, not a roster agent.
 */
import type { DomainPack } from './types.js';

export const companyPack: DomainPack = {
  agentId: 'company',
  // No deep agent file for Company; capabilities inferred from its attributes/role.
  capabilities: [
    'Enterprise context provisioning',
    'Strategic priority broadcasting',
    'Corporate governance scoring',
    'Portfolio health oversight',
  ],
  attributes: {
    company_name: { name: 'company_name', displayName: 'Company Name', type: 'text', description: 'Organization name', unit: '', source: 'project_field', defaultThresholds: {} },
    stock_ticker: { name: 'stock_ticker', displayName: 'Stock Ticker', type: 'text', description: 'Stock symbol (if public)', unit: '', source: 'project_field', defaultThresholds: {} },
    industry: { name: 'industry', displayName: 'Industry', type: 'text', description: 'Industry sector', unit: '', source: 'project_field', defaultThresholds: {} },
    annual_revenue: { name: 'annual_revenue', displayName: 'Annual Revenue', type: 'currency', description: 'Yearly revenue', unit: '$', source: 'external_api', defaultThresholds: {} },
    fiscal_year: { name: 'fiscal_year', displayName: 'Fiscal Year', type: 'text', description: 'Fiscal year (start, end, current_quarter) JSON', unit: '', source: 'project_field', defaultThresholds: {} },
    market_capitalization: { name: 'market_capitalization', displayName: 'Market Capitalization', type: 'currency', description: 'Market cap', unit: '$', source: 'external_api', defaultThresholds: {} },
    debt_to_equity_ratio: { name: 'debt_to_equity_ratio', displayName: 'Debt to Equity Ratio', type: 'number', description: 'Financial leverage', unit: 'ratio', source: 'external_api', defaultThresholds: { warning: 1.5, critical: 2.0 } },
    operating_margin: { name: 'operating_margin', displayName: 'Operating Margin', type: 'percentage', description: 'Operating profit margin', unit: '%', source: 'external_api', defaultThresholds: { warning: 10, critical: 5 } },
    cash_reserves: { name: 'cash_reserves', displayName: 'Cash Reserves', type: 'currency', description: 'Available cash', unit: '$', source: 'external_api', defaultThresholds: {} },
    credit_rating: { name: 'credit_rating', displayName: 'Credit Rating', type: 'text', description: 'Credit rating (AAA, AA, etc.)', unit: '', source: 'external_api', defaultThresholds: {} },
    employee_count: { name: 'employee_count', displayName: 'Employee Count', type: 'number', description: 'Total employees', unit: 'count', source: 'project_field', defaultThresholds: {} },
    board_size: { name: 'board_size', displayName: 'Board Size', type: 'number', description: '# board members', unit: 'count', source: 'project_field', defaultThresholds: {} },
    organizational_maturity: { name: 'organizational_maturity', displayName: 'Organizational Maturity', type: 'number', description: 'Agile maturity level (0-5)', unit: 'score', source: 'calculated', defaultThresholds: { warning: 2.5, critical: 2.0 } },
    strategic_priorities: { name: 'strategic_priorities', displayName: 'Strategic Priorities', type: 'text', description: 'Company strategic themes (array) - provides to LPM', unit: '', source: 'project_field', defaultThresholds: {} },
    mission: { name: 'mission', displayName: 'Mission', type: 'text', description: 'Company mission statement', unit: '', source: 'project_field', defaultThresholds: {} },
    vision: { name: 'vision', displayName: 'Vision', type: 'text', description: 'Company vision', unit: '', source: 'project_field', defaultThresholds: {} },
    values: { name: 'values', displayName: 'Values', type: 'text', description: 'Company values (array)', unit: '', source: 'project_field', defaultThresholds: {} },
    risk_factors: { name: 'risk_factors', displayName: 'Risk Factors', type: 'text', description: 'Enterprise risks (array) - provides to Risk agent', unit: '', source: 'project_field', defaultThresholds: {} },
    governance_score: { name: 'governance_score', displayName: 'Governance Score', type: 'number', description: 'Corporate governance (0-100)', unit: 'score', source: 'calculated', defaultThresholds: { warning: 70, critical: 50 } },
    compliance_frameworks: { name: 'compliance_frameworks', displayName: 'Compliance Frameworks', type: 'text', description: 'Applicable frameworks (array) e.g., [SOX, GDPR]', unit: '', source: 'project_field', defaultThresholds: {} },
    portfolio_health: { name: 'portfolio_health', displayName: 'Portfolio Health', type: 'number', description: 'Overall portfolio health (0-100)', unit: 'score', source: 'calculated', defaultThresholds: { warning: 60, critical: 40 } },
    art_count: { name: 'art_count', displayName: 'ART Count', type: 'number', description: '# of Agile Release Trains', unit: 'count', source: 'calculated', defaultThresholds: {} },
    value_stream_count: { name: 'value_stream_count', displayName: 'Value Stream Count', type: 'number', description: '# of Value Streams', unit: 'count', source: 'calculated', defaultThresholds: {} },
  },
  rules: [
    {
      id: 'company-low-portfolio-health',
      name: 'Low Portfolio Health',
      description: 'Alert when overall portfolio health is declining',
      enabled: true,
      conditions: [{ attribute: 'portfolio_health', operator: '<', threshold: 60 }],
      actions: [
        { type: 'escalate', targetAgents: ['governance', 'vro'], severity: 'high', message: 'Portfolio health below 60 - strategic review needed' },
        { type: 'notify', targetUsers: ['cxo', 'portfolio-lead'], severity: 'high', message: 'Portfolio health declining - executive intervention required' },
      ],
    },
    {
      id: 'company-low-organizational-maturity',
      name: 'Low Organizational Maturity',
      description: 'Alert when agile maturity is low',
      enabled: true,
      conditions: [{ attribute: 'organizational_maturity', operator: '<', threshold: 2.5 }],
      actions: [
        { type: 'alert', targetAgents: ['tmo', 'ocm'], severity: 'medium', message: 'Low organizational maturity - transformation support needed' },
        { type: 'notify', targetUsers: ['transformation-lead'], severity: 'medium', message: 'Organizational maturity below target - coaching and training needed' },
      ],
    },
    {
      id: 'company-high-debt-ratio',
      name: 'High Debt to Equity Ratio',
      description: 'Alert when financial leverage is high',
      enabled: true,
      conditions: [{ attribute: 'debt_to_equity_ratio', operator: '>', threshold: 1.5 }],
      actions: [
        { type: 'alert', targetAgents: ['finops', 'risk'], severity: 'high', message: 'High debt-to-equity ratio - financial risk assessment needed' },
        { type: 'notify', targetUsers: ['cfo'], severity: 'high', message: 'Debt levels elevated - financial strategy review required' },
      ],
    },
    {
      id: 'company-low-governance-score',
      name: 'Low Governance Score',
      description: 'Alert when corporate governance score is low',
      enabled: true,
      conditions: [{ attribute: 'governance_score', operator: '<', threshold: 70 }],
      actions: [
        { type: 'escalate', targetAgents: ['governance'], severity: 'critical', message: 'Low governance score - compliance and control improvements needed' },
        { type: 'notify', targetUsers: ['board', 'cxo'], severity: 'critical', message: 'Corporate governance score low - board review required' },
      ],
    },
  ],
};

export default companyPack;
