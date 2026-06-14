/**
 * FalkorDB-native temporal policy graph (append-only).
 *
 * This is the temporal layer for *governance policy* — "which policy version was
 * in force, and over what, at a given time". It lives in the SAME FalkorDB graph
 * the rest of the runtime uses (src/graph/falkor.ts); there is no separate
 * temporal-graph service. FalkorDB is the only graph and the only temporal graph.
 *
 * Model (append-only — versions are never mutated in place, only closed):
 *
 *   (:Policy { id, name })
 *     -[:HAS_VERSION]-> (:PolicyVersion { id, version, validFrom, validTo, summary })
 *   (:PolicyVersion) -[:SUPERSEDES]-> (:PolicyVersion)   // new -> the one it replaced
 *   (:Policy) -[:GOVERNS { validFrom, validTo }]-> (target node, matched by id)
 *
 * Bi-temporal convention: an OPEN interval has `validTo = null` (still active).
 * Closing a version/edge stamps `validTo = now`. "Active at time T" therefore
 * means `validFrom <= T AND (validTo IS NULL OR T < validTo)`.
 *
 * Every write is idempotent-friendly and degrades to a warning (never throws) so
 * a FalkorDB blip can't take down a caller — the policy graph is augmentation,
 * not the critical path.
 */
import type { Router } from 'express';
import { getGraph } from './falkor.js';

/** A policy version row as stored/returned. */
export interface PolicyVersion {
  /** Stable node id, e.g. "policy-<id>-v3". */
  id: string;
  /** Owning policy id. */
  policyId: string;
  /** 1-based monotonic version number. */
  version: number;
  /** ISO timestamp the version became active. */
  validFrom: string;
  /** ISO timestamp the version was superseded, or null while still active. */
  validTo: string | null;
  /** Human-readable summary of what this version says. */
  summary: string;
}

/** A policy → target governance edge as returned by queries. */
export interface PolicyGovernance {
  policyId: string;
  policyName: string;
  targetId: string;
  validFrom: string;
  validTo: string | null;
}

function versionNodeId(policyId: string, version: number): string {
  return `policy-${policyId}-v${version}`;
}

/**
 * Append a new version of a policy.
 *
 * Closes the currently-open version (sets `validTo = now`), creates the new
 * version (`validFrom = now`, `validTo = null`), links the Policy to it via
 * HAS_VERSION, and — when there was a prior open version — links the new version
 * to it via SUPERSEDES. Returns the created version.
 *
 * The Policy node is upserted, so calling this on a brand-new policyId creates
 * v1 with no SUPERSEDES edge.
 */
export async function upsertPolicyVersion(
  policyId: string,
  name: string,
  summary: string,
): Promise<PolicyVersion | null> {
  const graph = getGraph();
  const now = new Date().toISOString();
  try {
    // Ensure the Policy node exists / refresh its name.
    await graph.query(
      `MERGE (p:Policy { id: $policyId })
       SET p.name = $name`,
      { policyId, name },
    );

    // Find the currently-open version (if any) to determine the next version
    // number and the SUPERSEDES target.
    const open = await graph.query<{ id: string; version: number }>(
      `MATCH (p:Policy { id: $policyId })-[:HAS_VERSION]->(v:PolicyVersion)
       WHERE v.validTo IS NULL
       RETURN v.id AS id, v.version AS version
       ORDER BY v.version DESC LIMIT 1`,
      { policyId },
    );

    // Determine the next version number from the highest existing version (open
    // or closed), so numbering is monotonic even across re-opens.
    const maxRows = await graph.query<{ maxVersion: number | null }>(
      `MATCH (p:Policy { id: $policyId })-[:HAS_VERSION]->(v:PolicyVersion)
       RETURN max(v.version) AS maxVersion`,
      { policyId },
    );
    const nextVersion = (maxRows[0]?.maxVersion ?? 0) + 1;
    const previousOpenId = open[0]?.id;

    // Close the open version, if there is one.
    if (previousOpenId) {
      await graph.query(
        `MATCH (v:PolicyVersion { id: $id }) WHERE v.validTo IS NULL
         SET v.validTo = $now`,
        { id: previousOpenId, now },
      );
    }

    // Create the new (open) version and link it under the policy.
    const newId = versionNodeId(policyId, nextVersion);
    await graph.query(
      `MATCH (p:Policy { id: $policyId })
       MERGE (v:PolicyVersion { id: $id })
       SET v.policyId = $policyId,
           v.version = $version,
           v.validFrom = $now,
           v.validTo = NULL,
           v.summary = $summary
       MERGE (p)-[:HAS_VERSION]->(v)`,
      { policyId, id: newId, version: nextVersion, now, summary },
    );

    // Link the new version to the one it superseded.
    if (previousOpenId) {
      await graph.query(
        `MATCH (nv:PolicyVersion { id: $newId }), (ov:PolicyVersion { id: $oldId })
         MERGE (nv)-[:SUPERSEDES]->(ov)`,
        { newId, oldId: previousOpenId },
      );
    }

    return {
      id: newId,
      policyId,
      version: nextVersion,
      validFrom: now,
      validTo: null,
      summary,
    };
  } catch (err: any) {
    console.warn(`[policyTemporal] upsertPolicyVersion(${policyId}) failed: ${err.message}`);
    return null;
  }
}

/**
 * Record that a policy governs a target node (matched by its `id`), opening a new
 * GOVERNS interval (`validFrom = now`, `validTo = null`). If an open GOVERNS edge
 * for the same (policy, target) already exists this is a no-op, so it's safe to
 * call repeatedly. Append-only: superseding governance is expressed by closing
 * the prior interval via {@link closePolicyGoverns} before opening a new one.
 */
export async function setPolicyGoverns(policyId: string, targetId: string): Promise<boolean> {
  const graph = getGraph();
  const now = new Date().toISOString();
  try {
    // No-op if an open interval already exists.
    const existing = await graph.query<{ c: number }>(
      `MATCH (p:Policy { id: $policyId })-[g:GOVERNS]->(t { id: $targetId })
       WHERE g.validTo IS NULL
       RETURN count(g) AS c`,
      { policyId, targetId },
    );
    if ((existing[0]?.c ?? 0) > 0) return false;

    // Both endpoints must already exist; a blind MERGE on the target would seed
    // an empty placeholder node for an id we never synced.
    const rows = await graph.query<{ created: number }>(
      `MATCH (p:Policy { id: $policyId }), (t { id: $targetId })
       MERGE (p)-[g:GOVERNS { validFrom: $now }]->(t)
       SET g.validTo = NULL
       RETURN count(g) AS created`,
      { policyId, targetId, now },
    );
    return (rows[0]?.created ?? 0) > 0;
  } catch (err: any) {
    console.warn(`[policyTemporal] setPolicyGoverns(${policyId} -> ${targetId}) failed: ${err.message}`);
    return false;
  }
}

/**
 * Close the open GOVERNS interval(s) between a policy and a target (stamps
 * `validTo = now`). Returns how many edges were closed. Useful before opening a
 * fresh interval so the history stays append-only.
 */
export async function closePolicyGoverns(policyId: string, targetId: string): Promise<number> {
  const graph = getGraph();
  const now = new Date().toISOString();
  try {
    const rows = await graph.query<{ closed: number }>(
      `MATCH (p:Policy { id: $policyId })-[g:GOVERNS]->(t { id: $targetId })
       WHERE g.validTo IS NULL
       SET g.validTo = $now
       RETURN count(g) AS closed`,
      { policyId, targetId, now },
    );
    return rows[0]?.closed ?? 0;
  } catch (err: any) {
    console.warn(`[policyTemporal] closePolicyGoverns(${policyId} -> ${targetId}) failed: ${err.message}`);
    return 0;
  }
}

/**
 * Which policies governed `targetId` at instant `isoTime`?
 *
 * An interval is "active at T" when `validFrom <= T AND (validTo IS NULL OR T <
 * validTo)`. Returns the matching GOVERNS edges with their owning policy.
 */
export async function policiesGoverningAt(
  targetId: string,
  isoTime: string,
): Promise<PolicyGovernance[]> {
  const graph = getGraph();
  try {
    const rows = await graph.query<{
      policyId: string;
      policyName: string;
      validFrom: string;
      validTo: string | null;
    }>(
      `MATCH (p:Policy)-[g:GOVERNS]->(t { id: $targetId })
       WHERE g.validFrom <= $at AND (g.validTo IS NULL OR $at < g.validTo)
       RETURN p.id AS policyId, p.name AS policyName,
              g.validFrom AS validFrom, g.validTo AS validTo
       ORDER BY g.validFrom DESC`,
      { targetId, at: isoTime },
    );
    return rows.map((r) => ({
      policyId: r.policyId,
      policyName: r.policyName,
      targetId,
      validFrom: r.validFrom,
      validTo: r.validTo ?? null,
    }));
  } catch (err: any) {
    console.warn(`[policyTemporal] policiesGoverningAt(${targetId}) failed: ${err.message}`);
    return [];
  }
}

/**
 * Which version of a policy was in force at instant `isoTime`? Returns the
 * single active version, or null if none was active then.
 */
export async function policyVersionAt(
  policyId: string,
  isoTime: string,
): Promise<PolicyVersion | null> {
  const graph = getGraph();
  try {
    const rows = await graph.query<{
      id: string;
      version: number;
      validFrom: string;
      validTo: string | null;
      summary: string;
    }>(
      `MATCH (p:Policy { id: $policyId })-[:HAS_VERSION]->(v:PolicyVersion)
       WHERE v.validFrom <= $at AND (v.validTo IS NULL OR $at < v.validTo)
       RETURN v.id AS id, v.version AS version, v.validFrom AS validFrom,
              v.validTo AS validTo, v.summary AS summary
       ORDER BY v.version DESC LIMIT 1`,
      { policyId, at: isoTime },
    );
    const r = rows[0];
    if (!r) return null;
    return {
      id: r.id,
      policyId,
      version: r.version,
      validFrom: r.validFrom,
      validTo: r.validTo ?? null,
      summary: r.summary,
    };
  } catch (err: any) {
    console.warn(`[policyTemporal] policyVersionAt(${policyId}) failed: ${err.message}`);
    return null;
  }
}

/** All versions of a policy, newest first (full history). */
export async function policyHistory(policyId: string): Promise<PolicyVersion[]> {
  const graph = getGraph();
  try {
    const rows = await graph.query<{
      id: string;
      version: number;
      validFrom: string;
      validTo: string | null;
      summary: string;
    }>(
      `MATCH (p:Policy { id: $policyId })-[:HAS_VERSION]->(v:PolicyVersion)
       RETURN v.id AS id, v.version AS version, v.validFrom AS validFrom,
              v.validTo AS validTo, v.summary AS summary
       ORDER BY v.version DESC`,
      { policyId },
    );
    return rows.map((r) => ({
      id: r.id,
      policyId,
      version: r.version,
      validFrom: r.validFrom,
      validTo: r.validTo ?? null,
      summary: r.summary,
    }));
  } catch (err: any) {
    console.warn(`[policyTemporal] policyHistory(${policyId}) failed: ${err.message}`);
    return [];
  }
}

// ---------------------------------------------------------------------------
// HTTP surface (optional; mounted on the console router so it shares its auth)
// ---------------------------------------------------------------------------

/**
 * Mount the temporal-policy read endpoints onto an existing router.
 *
 *   GET /api/policies/governing?target=<id>&at=<iso>
 *        → { target, at, policies: PolicyGovernance[] }   (at defaults to now)
 *   GET /api/policies/:policyId/history
 *        → { policyId, versions: PolicyVersion[] }
 *   GET /api/policies/:policyId/version?at=<iso>
 *        → { policyId, at, version: PolicyVersion | null }
 *
 * Every handler degrades gracefully: on failure it returns an empty payload plus
 * an `error` field, never a 500 — consistent with the other runtime read routes.
 */
export function mountPolicyRoutes(router: Router): void {
  // Which policies governed a target at a point in time (default: now)?
  router.get('/api/policies/governing', async (req, res) => {
    const target = String(req.query.target ?? '');
    const at = req.query.at ? String(req.query.at) : new Date().toISOString();
    if (!target) {
      res.status(400).json({ error: 'query param "target" is required' });
      return;
    }
    try {
      res.json({ target, at, policies: await policiesGoverningAt(target, at) });
    } catch (err: any) {
      res.json({ target, at, policies: [], error: err?.message ?? String(err) });
    }
  });

  // Full version history of a policy.
  router.get('/api/policies/:policyId/history', async (req, res) => {
    const policyId = String(req.params.policyId);
    try {
      res.json({ policyId, versions: await policyHistory(policyId) });
    } catch (err: any) {
      res.json({ policyId, versions: [], error: err?.message ?? String(err) });
    }
  });

  // The single version in force at a point in time (default: now).
  router.get('/api/policies/:policyId/version', async (req, res) => {
    const policyId = String(req.params.policyId);
    const at = req.query.at ? String(req.query.at) : new Date().toISOString();
    try {
      res.json({ policyId, at, version: await policyVersionAt(policyId, at) });
    } catch (err: any) {
      res.json({ policyId, at, version: null, error: err?.message ?? String(err) });
    }
  });
}
