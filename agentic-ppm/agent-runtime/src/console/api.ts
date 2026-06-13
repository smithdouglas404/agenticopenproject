/**
 * Agent Console API — the HITL backend (Phase 2).
 *
 * GET  /console                      the console UI
 * GET  /api/roster                   agents + open/total finding counts
 * GET  /api/findings?status=&agent=  findings ("open" = new|published)
 * GET  /api/metrics                  computed portfolio metrics (deterministic, no LLM)
 * GET  /api/learning                 per-agent accuracy + recent resolved predictions
 * POST /api/findings/:id/approve     human approves -> comment on alert WP
 * POST /api/findings/:id/reject      human rejects  -> comment on alert WP
 * POST /api/sweep                    run the detector sweep on demand
 *
 * If CONSOLE_TOKEN is set, all of the above require Bearer auth (or ?token=).
 * Decisions are auditable: status + decidedBy land on the AgentFinding node, and
 * a comment is posted on the corresponding Agent Alert WP in OpenProject.
 */
import { Router, type Request, type Response, type NextFunction } from 'express';
import { AGENT_ROSTER } from '../agents/roster.js';
import { listFindings, findingCountsByAgent, type FindingStatus } from '../store/findings.js';
import { decideFinding } from '../agents/decisions.js';
import { runSweep } from '../agents/sweep.js';
import { computePortfolioMetrics } from '../grounding/metrics.js';
import { agentAccuracy, recentResolvedPredictions } from '../learning/outcomes.js';
import { collectChecks, type Check } from '../preflight.js';
import { config } from '../config.js';
import { CONSOLE_HTML } from './page.js';
import { mountMappingRoutes } from '../mapping/routes.js';

// Dependency health, cached so the 30s console refresh doesn't hammer Graphiti.
let statusCache: { at: number; checks: Check[] } | null = null;
async function getStatus(): Promise<Check[]> {
  if (statusCache && Date.now() - statusCache.at < 120_000) return statusCache.checks;
  const checks = await collectChecks();
  statusCache = { at: Date.now(), checks };
  return checks;
}

function auth(req: Request, res: Response, next: NextFunction): void {
  const token = config.console.token;
  if (!token) return next(); // private-network deployment; no token configured
  const presented =
    (req.headers.authorization ?? '').replace(/^Bearer\s+/i, '') ||
    String(req.query.token ?? '');
  if (presented === token) return next();
  res.status(401).json({ error: 'unauthorized' });
}

async function decide(req: Request, res: Response, decision: 'approved' | 'rejected'): Promise<void> {
  const decidedBy = String(req.body?.decidedBy ?? 'console');
  const result = await decideFinding(req.params.id, decision, decidedBy);
  res.status(result.ok ? result.code : result.code).json(
    result.ok ? { ...result.finding, action: result.action } : { error: result.error },
  );
}

export function buildConsoleRouter(): Router {
  const router = Router();
  router.use(['/console', '/api'], auth);

  router.get('/console', (_req, res) => {
    // Inject the OpenProject base URL so finding links open OpenProject.
    res
      .type('html')
      .send(CONSOLE_HTML.replace('__OPENPROJECT_BASE_URL__', config.openproject.baseUrl.replace(/\/$/, '')));
  });

  router.get('/api/roster', async (_req, res) => {
    const counts = await findingCountsByAgent().catch(() => ({}) as Record<string, { open: number; total: number }>);
    res.json(AGENT_ROSTER.map((a) => ({ ...a, counts: counts[a.id] ?? { open: 0, total: 0 } })));
  });

  router.get('/api/findings', async (req, res) => {
    const status = String(req.query.status ?? '');
    const agentId = req.query.agent ? String(req.query.agent) : undefined;
    // The task-level feed excludes portfolio-insight; those have their own section.
    const exclude = 'portfolio-insight';
    if (status === 'open' || status === '') {
      const [fresh, published] = await Promise.all([
        listFindings({ status: 'new', agentId, excludeType: exclude }),
        listFindings({ status: 'published', agentId, excludeType: exclude }),
      ]);
      const merged = [...fresh, ...published].sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
      res.json(status === '' ? await listFindings({ agentId, excludeType: exclude }) : merged);
      return;
    }
    res.json(await listFindings({ status: status as FindingStatus, agentId, excludeType: exclude }));
  });

  router.post('/api/findings/:id/approve', (req, res) => void decide(req, res, 'approved'));
  router.post('/api/findings/:id/reject', (req, res) => void decide(req, res, 'rejected'));

  router.post('/api/sweep', async (_req, res) => {
    res.json(await runSweep('manual'));
  });

  router.get('/api/status', async (_req, res) => {
    res.json(await getStatus());
  });

  // Computed-metrics channel: deterministic Cypher aggregates, never the LLM.
  // Degrades to an empty metric list when the graph is unreachable/empty.
  router.get('/api/metrics', async (_req, res) => {
    try {
      res.json(await computePortfolioMetrics());
    } catch (err: any) {
      res.json({ computedAt: new Date().toISOString(), metrics: [], error: err.message });
    }
  });

  // Learning loop: per-agent track record + recently resolved predictions.
  router.get('/api/learning', async (_req, res) => {
    const [accuracy, recent] = await Promise.all([
      agentAccuracy().catch(() => ({})),
      recentResolvedPredictions(20).catch(() => []),
    ]);
    res.json({ accuracy, recent });
  });

  // Project-level portfolio assessments (the banner-quality insights), latest
  // per project — separate from the task-level findings feed.
  // Active rule definitions (authored in OpenProject; the runtime evaluates
  // them). Read-only surface for UIs; the rules API token stays server-side.
  router.get('/api/rules', async (_req, res) => {
    try {
      const { loadRules } = await import('../rules/loader.js');
      res.json({ rules: await loadRules() });
    } catch (err: any) {
      res.json({ rules: [], error: err.message });
    }
  });

  router.get('/api/project-status', async (_req, res) => {
    const all = await listFindings({ type: 'portfolio-insight', limit: 200 });
    const latest = new Map<string, (typeof all)[number]>();
    for (const f of all) {
      const key = f.nodeId || f.id;
      if (!latest.has(key)) latest.set(key, f); // already sorted updatedAt DESC
    }
    res.json([...latest.values()]);
  });

  // Ontology-as-universal-mapper endpoints (schema/properties/widgets/mapping).
  mountMappingRoutes(router);

  return router;
}
