/**
 * Detector sweep — runs the inference detectors, records findings in the graph
 * store (deduped), and publishes only NEW findings to the OpenProject inbox.
 *
 * Triggered (a) periodically (DETECTOR_SWEEP_MINUTES) and (b) opportunistically
 * after webhook events, throttled so bursts of updates don't hammer the graph.
 */
import { runDetectors } from './detectors.js';
import { recordFinding, setFindingStatus, setFindingNarrative, openFindingSeverityCounts } from '../store/findings.js';
import { writeFinding, type AlertSeverity } from '../inbox/inbox.js';
import { getOpenProjectClient } from '../openproject/client.js';
import { assessAllProjects } from './projectAssessor.js';
import { runAgents } from './reasoningAgents.js';
import { recordPrediction, resolveOutcomes, severityAdjustment } from '../learning/outcomes.js';
import {
  generateNarrative,
  fetchWorkItemContext,
  fetchProjectContext,
} from './narrativeGenerator.js';
import { config } from '../config.js';
import { evaluateRules, publishBreaches } from '../rules/evaluator.js';

const SEVERITY_TO_ALERT: Record<'low' | 'medium' | 'high', AlertSeverity> = {
  low: 'notification',
  medium: 'warning',
  high: 'alarm',
};

let lastSweepAt = 0;
let sweeping = false;

export interface SweepResult {
  detected: number;
  newFindings: number;
  published: number;
}

export async function runSweep(reason: string): Promise<SweepResult> {
  if (sweeping) return { detected: 0, newFindings: 0, published: 0 };
  sweeping = true;
  try {
    const findings = await runDetectors();
    let newCount = 0;
    let published = 0;

    for (const f of findings) {
      // Dedup FIRST: open findings are skipped before any LLM spend, so the
      // hourly sweep doesn't re-narrate findings that are already standing.
      const { finding, isNew } = await recordFinding({
        type: f.type,
        agentId: f.agentId,
        severity: f.severity,
        title: f.title,
        body: f.body,
        nodeId: f.nodeId,
        workPackageId: f.workPackageId,
      });
      if (!isNew) continue;
      newCount++;

      // LEARNING: record the detector call as a prediction so the outcome loop
      // can later score it against what actually happened to the node.
      await recordPrediction({
        id: finding.id,
        type: f.type,
        agentId: f.agentId,
        severity: f.severity,
        nodeId: f.nodeId,
        workPackageId: f.workPackageId,
      }).catch((err) => console.warn(`[sweep] prediction record failed for ${finding.id}: ${err.message}`));

      // Enrich ONLY new findings with an LLM-generated narrative + project link.
      let narrative: string | undefined;
      if (f.nodeId) {
        try {
          const [workItem, project] = await Promise.all([
            fetchWorkItemContext(f.nodeId),
            fetchProjectContext(f.nodeId),
          ]);
          if (workItem) {
            const result = await generateNarrative(f, workItem, project);
            narrative = result.narrative;
            await setFindingNarrative(finding.id, result);
          }
        } catch (err: any) {
          console.warn(`[sweep] narrative generation failed for ${f.nodeId}: ${err.message}`);
        }
      }

      if (config.detectors.publish) {
        try {
          // Track-record weighting: agents with a poor resolved-prediction
          // record get their PUBLISHED severity downgraded one notch.
          const tuned = await severityAdjustment(f.agentId, f.severity);
          const note = tuned.adjusted ? `\n\n_${tuned.note}_` : '';
          const alertWpId = await writeFinding({
            title: `${f.type}: ${f.title}`,
            body: `${narrative ?? f.body}${note}\n\nAgent: ${f.agentId} · Finding: ${finding.id}`,
            severity: SEVERITY_TO_ALERT[tuned.severity],
            relatedWorkPackageId: f.workPackageId,
          });
          await setFindingStatus(finding.id, 'published', { alertWpId });
          published++;
        } catch (err: any) {
          console.warn(`[sweep] publish failed for ${finding.id}: ${err.message}`);
        }
      }
    }

    // LEARNING: resolve open predictions against actual graph state (after the
    // detectors have refreshed findings, before projects are re-assessed).
    if (config.learning.enabled) {
      await resolveOutcomes().catch((err) => console.warn(`[sweep] outcome resolution failed: ${err.message}`));
    }

    lastSweepAt = Date.now();
    if (findings.length > 0 || newCount > 0) {
      console.log(
        `[sweep:${reason}] ${findings.length} detected, ${newCount} new, ${published} published`,
      );
    }
    await updateAlertsRollup().catch((err) => console.warn(`[sweep] rollup failed: ${err.message}`));
    // Refresh every project's status banner so it tracks predictably, not only on edits.
    if (config.insights.reassessOnSweep) {
      const n = await assessAllProjects().catch((err) => {
        console.warn(`[sweep] project re-assessment failed: ${err.message}`);
        return 0;
      });
      if (n) console.log(`[sweep:${reason}] re-assessed ${n} project(s)`);
    }
    // Run all roster agents as reasoning agents over the portfolio.
    if (config.reasoning.enabled) {
      const n = await runAgents().catch((err) => {
        console.warn(`[sweep] reasoning agents failed: ${err.message}`);
        return 0;
      });
      if (n) console.log(`[sweep:${reason}] reasoning agents raised ${n} new finding(s)`);
    }
    // RULES: evaluate OpenProject-authored rules against the graph and publish
    // breaches into both UIs. Resilient — a failure here never fails the sweep.
    if (config.rules.enabled && config.rules.evaluateOnSweep) {
      try {
        const breaches = await evaluateRules();
        const n = await publishBreaches(breaches);
        if (breaches.length > 0 || n > 0) {
          console.log(`[sweep:${reason}] rules: ${breaches.length} breach(es), ${n} new finding(s)`);
        }
      } catch (err: any) {
        console.warn(`[sweep] rule evaluation failed: ${err.message}`);
      }
    }
    return { detected: findings.length, newFindings: newCount, published };
  } finally {
    sweeping = false;
  }
}

/** Set the alerts project's status banner to a portfolio rollup of open findings. */
async function updateAlertsRollup(): Promise<void> {
  if (!config.actions.setProjectStatus) return;
  const c = await openFindingSeverityCounts();
  const total = c.high + c.medium + c.low;
  const status = c.high > 0 ? 'off_track' : c.medium > 0 ? 'at_risk' : 'on_track';
  const explanation =
    total === 0
      ? 'No open agent findings. The portfolio is clear.'
      : `**${total} open finding(s)** across the portfolio: ` +
        `🔴 ${c.high} high · 🟠 ${c.medium} medium · 🔵 ${c.low} low.\n\n` +
        `Review and approve/reject in the Agent Console, or by changing each alert's status here. ` +
        `_Updated ${new Date().toISOString().slice(0, 16).replace('T', ' ')} UTC._`;
  await getOpenProjectClient().updateProjectStatus(config.openproject.alertsProject, status, explanation);
}

/** Sweep after webhook events, at most once per throttle window. */
export function maybeSweepAfterEvent(): void {
  const minGapMs = config.detectors.eventThrottleMinutes * 60_000;
  if (Date.now() - lastSweepAt < minGapMs) return;
  void runSweep('event').catch((err) => console.warn(`[sweep] failed: ${err.message}`));
}

/** Start the periodic sweep loop (no-op if disabled). */
export function startSweepLoop(): void {
  const minutes = config.detectors.sweepMinutes;
  if (minutes <= 0) {
    console.log('[sweep] periodic sweep disabled (DETECTOR_SWEEP_MINUTES=0)');
    return;
  }
  console.log(`[sweep] periodic sweep every ${minutes} min`);
  setInterval(() => {
    void runSweep('schedule').catch((err) => console.warn(`[sweep] failed: ${err.message}`));
  }, minutes * 60_000).unref();
}
