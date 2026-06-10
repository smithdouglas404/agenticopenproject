/**
 * Insight finding schema.
 *
 * LIFTED almost verbatim from DOSv2 `server/executiveInsights.ts`
 * (`ExecutiveInsightSchema`). This is the finding format the Insights inbox renders.
 * The energy-industry-specific wording from DOSv2 is intentionally NOT baked into the
 * schema — it lived in the prompt, which we re-point at generic portfolio data.
 */
import { z } from 'zod';

export const InsightSchema = z.object({
  headline: z.string().min(10),
  portfolioHealth: z.enum(['green', 'amber', 'red']),
  healthSummary: z.string().min(20),
  keyRisks: z
    .array(
      z.object({
        title: z.string(),
        impact: z.string(),
        mitigation: z.string(),
        severity: z.enum(['high', 'medium', 'low']),
        linkedEntity: z.string().optional(),
      }),
    )
    .min(1)
    .max(5),
  opportunities: z
    .array(
      z.object({
        title: z.string(),
        potentialValue: z.string(),
        action: z.string(),
        linkedEntity: z.string().optional(),
      }),
    )
    .max(4),
  recommendations: z
    .array(
      z.object({
        action: z.string(),
        rationale: z.string(),
        priority: z.enum(['urgent', 'high', 'medium']),
        actionRef: z.string().optional(),
      }),
    )
    .min(1)
    .max(4),
  kpiHighlights: z
    .array(
      z.object({
        name: z.string(),
        status: z.enum(['on-track', 'at-risk', 'off-track']),
        delta: z.string(),
      }),
    )
    .max(6),
});

export type Insight = z.infer<typeof InsightSchema> & { generatedAt: string };
