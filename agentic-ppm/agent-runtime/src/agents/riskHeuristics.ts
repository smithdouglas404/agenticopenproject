/**
 * Deterministic risk math.
 *
 * LIFTED from DOSv2 `server/agents/deep/DeepRiskAgent.ts` (the formulas in
 * analyze_risk_probability / calculate_risk_impact). Re-expressed as pure functions
 * over a normalized work-item shape pulled from the graph, instead of the Drizzle
 * `project` object + Mem0 broadcast loop the original was wired to.
 *
 * These run *before* the LLM so the model reasons over computed scores rather than
 * inventing them — keeps findings grounded and cheap.
 */

export interface RiskInput {
  id: string;
  name: string;
  status?: string;
  priority?: string;
  progress?: number; // 0-100 (percentageDone)
  expectedProgress?: number; // 0-100, schedule baseline
  budget?: number;
  actualCost?: number;
  startDate?: string;
  endDate?: string;
}

export type RiskType =
  | 'schedule_delay'
  | 'cost_overrun'
  | 'scope_reduction'
  | 'quality_issue'
  | 'resource_loss';

export type Severity = 'minor' | 'moderate' | 'major' | 'critical';

/** Impact multipliers by severity. (DOSv2 severityMultipliers) */
const SEVERITY_MULTIPLIERS: Record<Severity, number> = {
  minor: 0.1,
  moderate: 0.25,
  major: 0.5,
  critical: 1.0,
};

export interface ProbabilityResult {
  score: number; // 0-100
  level: 'high' | 'medium' | 'low';
  factors: string[];
}

/** Probability of a risk materializing from project health indicators. */
export function analyzeRiskProbability(item: RiskInput): ProbabilityResult {
  const factors: string[] = [];

  const scheduleAtRisk =
    item.progress !== undefined &&
    item.expectedProgress !== undefined &&
    item.progress < item.expectedProgress;
  const budgetAtRisk =
    item.budget !== undefined &&
    item.actualCost !== undefined &&
    item.actualCost > item.budget * 0.9;

  if (scheduleAtRisk) factors.push('Schedule behind baseline increases delivery risk');
  if (budgetAtRisk) factors.push('Spend near budget ceiling increases resource risk');
  if (item.status === 'at-risk' || item.status === 'red') {
    factors.push('Work item status indicates elevated risk');
  }
  if (item.priority === 'High' || item.priority === 'Immediate') {
    factors.push('High priority item — failure impact amplified');
  }

  // Each contributing factor adds 25 points, capped at 100. (derived from DOSv2 thresholds)
  const score = Math.min(factors.length * 25, 100);
  const level = score > 70 ? 'high' : score > 40 ? 'medium' : 'low';
  return { score, level, factors };
}

export interface ImpactResult {
  scheduleDelayDays: number;
  costImpact: number;
  qualityImpact: string;
  overallScore: number; // 0-100
  level: 'critical' | 'high' | 'medium' | 'low';
}

/** Impact if a risk of a given type materializes. (DOSv2 calculate_risk_impact) */
export function calculateRiskImpact(
  item: RiskInput,
  riskType: RiskType,
  severity: Severity = 'moderate',
): ImpactResult {
  const multiplier = SEVERITY_MULTIPLIERS[severity];
  const budget = item.budget ?? 0;

  let scheduleImpactDays = 0;
  let costImpact = 0;
  let qualityImpact = '';

  switch (riskType) {
    case 'schedule_delay': {
      const span = durationDays(item.startDate, item.endDate) ?? 90;
      scheduleImpactDays = Math.ceil(span * multiplier);
      costImpact = budget * 0.01 * scheduleImpactDays; // 1% budget per day
      qualityImpact = 'Potential quality compromise due to rushing';
      break;
    }
    case 'cost_overrun':
      costImpact = budget * multiplier;
      scheduleImpactDays = severity === 'critical' ? 30 : severity === 'major' ? 15 : 0;
      qualityImpact = severity === 'critical' ? 'Scope reduction likely' : 'Minor scope adjustments';
      break;
    case 'scope_reduction':
      costImpact = budget * multiplier * 0.5;
      qualityImpact = `${(multiplier * 100).toFixed(0)}% scope reduction`;
      break;
    case 'quality_issue':
      scheduleImpactDays = Math.ceil(30 * multiplier);
      costImpact = budget * multiplier * 0.3;
      qualityImpact = 'Rework required, stakeholder dissatisfaction';
      break;
    case 'resource_loss':
      scheduleImpactDays = Math.ceil(45 * multiplier);
      costImpact = budget * multiplier * 0.2;
      qualityImpact = 'Knowledge loss, productivity impact';
      break;
  }

  const scheduleImpactPercent = (scheduleImpactDays / 90) * 100; // 90-day baseline
  const costImpactPercent = budget > 0 ? (costImpact / budget) * 100 : 0;
  const overallScore = (scheduleImpactPercent + costImpactPercent) / 2;
  const level =
    overallScore > 50 ? 'critical' : overallScore > 25 ? 'high' : overallScore > 10 ? 'medium' : 'low';

  return { scheduleDelayDays: scheduleImpactDays, costImpact, qualityImpact, overallScore, level };
}

function durationDays(start?: string, end?: string): number | undefined {
  if (!start || !end) return undefined;
  const s = new Date(start).getTime();
  const e = new Date(end).getTime();
  if (Number.isNaN(s) || Number.isNaN(e)) return undefined;
  return Math.max(0, Math.ceil((e - s) / (1000 * 60 * 60 * 24)));
}
