/**
 * Detector sweep — runs the inference detectors, records findings in the graph
 * store (deduped), and publishes only NEW findings to the OpenProject inbox.
 *
 * Triggered (a) periodically (DETECTOR_SWEEP_MINUTES) and (b) opportunistically
 * after webhook events, throttled so bursts of updates don't hammer the graph.
 */
import { runDetectors } from './detectors.js';
import { recordFinding, setFindingStatus, setFindingNarrative } from '../store/findings.js';
import { writeFinding, type AlertSeverity } from '../inbox/inbox.js';
import {
  generateNarrative,
  fetchWorkItemContext,
  fetchProjectContext,
} from './narrativeGenerator.js';
import { config } from '../config.js';

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
          const alertWpId = await writeFinding({
            title: `${f.type}: ${f.title}`,
            body: `${narrative ?? f.body}\n\nAgent: ${f.agentId} · Finding: ${finding.id}`,
            severity: SEVERITY_TO_ALERT[f.severity],
            relatedWorkPackageId: f.workPackageId,
          });
          await setFindingStatus(finding.id, 'published', { alertWpId });
          published++;
        } catch (err: any) {
          console.warn(`[sweep] publish failed for ${finding.id}: ${err.message}`);
        }
      }
    }

    lastSweepAt = Date.now();
    if (findings.length > 0 || newCount > 0) {
      console.log(
        `[sweep:${reason}] ${findings.length} detected, ${newCount} new, ${published} published`,
      );
    }
    return { detected: findings.length, newFindings: newCount, published };
  } finally {
    sweeping = false;
  }
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
