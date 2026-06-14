/**
 * Learning API — ML-suggested rule thresholds endpoint.
 *
 * NEW BUILD ("Later" feature). Surfaces the deterministic threshold suggester
 * (suggest.ts) so the OpenProject rules-authoring UI can offer a "suggest a
 * threshold from history" affordance next to a metric. Read-only and grounded:
 * the number comes from resolved bad-outcome predictions, never an LLM.
 *
 *   GET /api/rules/suggest?class=safe:Epic&metric=percentageDone -> ThresholdSuggestion
 *
 * Degrades gracefully: a missing param or a thin/empty graph returns a
 * suggested:null payload with a rationale, never a 500.
 */
import type { Router } from 'express';
import { suggestThreshold } from './suggest.js';

/** Mount the learning endpoints onto an existing router. */
export function mountLearningRoutes(router: Router): void {
  router.get('/api/rules/suggest', async (req, res) => {
    const ontologyClass = String(req.query.class ?? '').trim();
    const metric = String(req.query.metric ?? '').trim();
    if (!ontologyClass || !metric) {
      res.json({
        metric,
        ontologyClass,
        suggested: null,
        operator: 'lt',
        rationale: 'both ?class and ?metric are required',
        sampleSize: 0,
        confidence: 0,
      });
      return;
    }
    try {
      res.json(await suggestThreshold({ ontologyClass, metric }));
    } catch (err: any) {
      res.json({
        metric,
        ontologyClass,
        suggested: null,
        operator: 'lt',
        rationale: `suggestion failed: ${err?.message ?? String(err)}`,
        sampleSize: 0,
        confidence: 0,
      });
    }
  });
}
