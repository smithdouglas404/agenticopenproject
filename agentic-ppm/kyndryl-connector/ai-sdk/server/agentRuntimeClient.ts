/**
 * agentRuntimeClient — thin typed fetch client for the agent-runtime sidecar.
 *
 * The agent-runtime (agentic-ppm/agent-runtime) exposes a small HTTP console
 * API. This client mirrors it 1:1 so the Vercel AI SDK tools (./tools.ts) can
 * call it without re-deriving any shapes:
 *
 *   GET  /api/roster                   agents + open/total finding counts
 *   GET  /api/findings?status=&agent=  findings ("open" = new|published)
 *   GET  /api/metrics                  COMPUTED portfolio metrics (no LLM)
 *   GET  /api/learning                 per-agent accuracy + resolved predictions
 *   GET  /api/status                   dependency health checks
 *   GET  /api/project-status           latest portfolio-insight per project
 *   POST /api/findings/:id/approve     HITL approve (body { decidedBy })
 *   POST /api/findings/:id/reject      HITL reject  (body { decidedBy })
 *   POST /api/sweep                    run the detector sweep on demand
 *
 * Env:
 *   AGENT_RUNTIME_URL  base URL of the sidecar (default http://localhost:8745)
 *   CONSOLE_TOKEN      optional bearer token — must match the runtime's
 *                      CONSOLE_TOKEN; sent as `Authorization: Bearer <token>`.
 *
 * The interfaces below mirror agent-runtime/src/{store/findings.ts,
 * grounding/metrics.ts, learning/outcomes.ts, agents/roster.ts} — keep in sync.
 */

// ── Shapes mirrored from the agent-runtime ──────────────────────────────────

export type FindingStatus = "new" | "published" | "approved" | "rejected" | "resolved";

/** agent-runtime/src/store/findings.ts → StoredFinding */
export interface Finding {
  id: string;
  type: string;
  agentId: string;
  severity: string;
  title: string;
  body: string;
  status: FindingStatus;
  nodeId?: string;
  workPackageId?: number;
  /** Agent Alert WP created in OpenProject for this finding, if published. */
  alertWpId?: number;
  /** LLM-generated polished narrative; falls back to body if absent. */
  narrative?: string;
  projectId?: number;
  projectName?: string;
  followupWpId?: number;
  /** Evidence citations ([{entityId, metric, value}]) as a JSON string; '' if absent. */
  evidence?: string;
  /** Agent-reported, grounding-adjusted confidence 0–1; 0 means "not reported". */
  confidence?: number;
  /** Computed-metrics snapshot (two-channel output) as a JSON string; '' if absent. */
  metrics?: string;
  createdAt: string;
  updatedAt: string;
  decidedBy?: string;
}

export interface EvidenceItem {
  entityId: string;
  metric: string;
  value: string;
}

/** agent-runtime/src/grounding/metrics.ts → Metric (the COMPUTED channel). */
export interface Metric {
  id: string;
  label: string;
  value: number | string | unknown;
  computedAt: string;
  /** Human-readable one-liner of the Cypher logic (auditability). */
  formula: string;
}

export interface PortfolioMetrics {
  computedAt: string;
  metrics: Metric[];
  /** Present when the graph was unreachable — metrics degrade to []. */
  error?: string;
}

/** agent-runtime/src/learning/outcomes.ts → AgentAccuracy */
export interface AgentAccuracy {
  total: number;
  correct: number;
  incorrect: number;
  humanConfirmed: number;
  humanRejected: number;
  /** (correct + humanConfirmed) / (those + incorrect + humanRejected); null if <3 resolved. */
  accuracy: number | null;
}

/** agent-runtime/src/learning/outcomes.ts → Prediction */
export interface Prediction {
  id: string;
  findingId: string;
  agentId: string;
  type: string;
  nodeId: string;
  predictedAt: string;
  claim: string;
  status: "open" | "resolved";
  outcome?: string;
  correctness?: string;
  resolvedAt?: string;
}

export interface LearningSnapshot {
  accuracy: Record<string, AgentAccuracy>;
  recent: Prediction[];
}

/** agent-runtime/src/agents/roster.ts → AgentDomain, plus the counts the API adds. */
export interface RosterAgent {
  id: string;
  name: string;
  domain: string;
  purpose: string;
  owns: string[];
  status: "active" | "planned";
  counts: { open: number; total: number };
}

/** agent-runtime/src/preflight.ts → Check */
export interface RuntimeCheck {
  name: string;
  ok: boolean;
  detail: string;
  required: boolean;
}

/** agent-runtime/src/agents/sweep.ts → SweepResult */
export interface SweepResult {
  detected: number;
  newFindings: number;
  published: number;
}

/**
 * POST /api/findings/:id/{approve|reject} responds with the updated finding
 * spread at the top level plus `action` (the gated action executed on approve).
 * On error it responds { error } with a non-2xx code.
 */
export type DecisionResponse = Finding & {
  action?: { followupWpId?: number; detail?: string } | null;
};

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Parse a finding's evidence JSON string into typed citations (never throws). */
export function parseEvidence(evidence: string | undefined): EvidenceItem[] {
  if (!evidence) return [];
  try {
    const parsed: unknown = JSON.parse(evidence);
    return Array.isArray(parsed) ? (parsed as EvidenceItem[]) : [];
  } catch {
    return [];
  }
}

/** Parse a finding's computed-metrics snapshot JSON string (never throws). */
export function parseFindingMetrics(metrics: string | undefined): Metric[] {
  if (!metrics) return [];
  try {
    const parsed: unknown = JSON.parse(metrics);
    if (Array.isArray(parsed)) return parsed as Metric[];
    if (parsed && typeof parsed === "object" && Array.isArray((parsed as { metrics?: unknown }).metrics)) {
      return (parsed as { metrics: Metric[] }).metrics;
    }
    return [];
  } catch {
    return [];
  }
}

// ── Client ───────────────────────────────────────────────────────────────────

export interface AgentRuntimeClientOptions {
  /** Defaults to process.env.AGENT_RUNTIME_URL ?? http://localhost:8745 */
  baseUrl?: string;
  /** Defaults to process.env.CONSOLE_TOKEN (optional). */
  token?: string;
  /** Request timeout in ms (default 30s; sweeps can be slow). */
  timeoutMs?: number;
}

export class AgentRuntimeError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
  ) {
    super(message);
    this.name = "AgentRuntimeError";
  }
}

export class AgentRuntimeClient {
  private readonly baseUrl: string;
  private readonly token: string | undefined;
  private readonly timeoutMs: number;

  constructor(opts: AgentRuntimeClientOptions = {}) {
    this.baseUrl = (opts.baseUrl ?? process.env.AGENT_RUNTIME_URL ?? "http://localhost:8745").replace(/\/$/, "");
    this.token = opts.token ?? process.env.CONSOLE_TOKEN ?? undefined;
    this.timeoutMs = opts.timeoutMs ?? 30_000;
  }

  private async request<T>(path: string, init?: { method?: string; body?: unknown }): Promise<T> {
    const headers: Record<string, string> = { Accept: "application/json" };
    if (this.token) headers.Authorization = `Bearer ${this.token}`;
    if (init?.body !== undefined) headers["Content-Type"] = "application/json";

    let res: Response;
    try {
      res = await fetch(`${this.baseUrl}${path}`, {
        method: init?.method ?? "GET",
        headers,
        body: init?.body !== undefined ? JSON.stringify(init.body) : undefined,
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (err) {
      throw new AgentRuntimeError(
        `agent-runtime unreachable at ${this.baseUrl}${path}: ${err instanceof Error ? err.message : String(err)}`,
      );
    }

    const text = await res.text();
    let json: unknown = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      // non-JSON error body — fall through to the status check below
    }
    if (!res.ok) {
      const detail =
        json && typeof json === "object" && typeof (json as { error?: unknown }).error === "string"
          ? (json as { error: string }).error
          : text.slice(0, 200);
      throw new AgentRuntimeError(`agent-runtime ${path} → ${res.status}: ${detail}`, res.status);
    }
    return json as T;
  }

  /** GET /api/roster — the agent domains with open/total finding counts. */
  getRoster(): Promise<RosterAgent[]> {
    return this.request<RosterAgent[]>("/api/roster");
  }

  /**
   * GET /api/findings — task-level findings feed (excludes portfolio-insight).
   * status "open" (or omitted with status="open") merges new+published.
   */
  getFindings(filter?: { status?: FindingStatus | "open"; agentId?: string; type?: string }): Promise<Finding[]> {
    const params = new URLSearchParams();
    if (filter?.status) params.set("status", filter.status);
    if (filter?.agentId) params.set("agent", filter.agentId);
    const qs = params.toString();
    // NOTE: the runtime API has no `type` query param on this route; callers
    // filter client-side (see tools.ts) to keep this client a faithful mirror.
    return this.request<Finding[]>(`/api/findings${qs ? `?${qs}` : ""}`);
  }

  /** GET /api/status — dependency health checks (cached ~2min server-side). */
  getStatus(): Promise<RuntimeCheck[]> {
    return this.request<RuntimeCheck[]>("/api/status");
  }

  /** GET /api/project-status — latest portfolio-insight finding per project. */
  getProjectStatus(): Promise<Finding[]> {
    return this.request<Finding[]>("/api/project-status");
  }

  /** GET /api/metrics — the COMPUTED channel (deterministic Cypher, no LLM). */
  getMetrics(): Promise<PortfolioMetrics> {
    return this.request<PortfolioMetrics>("/api/metrics");
  }

  /** GET /api/learning — per-agent accuracy + recently resolved predictions. */
  getLearning(): Promise<LearningSnapshot> {
    return this.request<LearningSnapshot>("/api/learning");
  }

  /**
   * POST /api/findings/:id/approve|reject — the HITL decision path. Mirrors the
   * console exactly: body { decidedBy }; the runtime executes the gated action
   * (approve), records the learning label, and comments back into OpenProject.
   */
  decideFinding(id: string, decision: "approve" | "reject", decidedBy: string): Promise<DecisionResponse> {
    return this.request<DecisionResponse>(`/api/findings/${encodeURIComponent(id)}/${decision}`, {
      method: "POST",
      body: { decidedBy },
    });
  }

  /** POST /api/sweep — run the detector sweep on demand. */
  triggerSweep(): Promise<SweepResult> {
    return this.request<SweepResult>("/api/sweep", { method: "POST", body: {} });
  }
}

let singleton: AgentRuntimeClient | null = null;

/** Shared client instance (env-configured). */
export function getAgentRuntimeClient(): AgentRuntimeClient {
  return (singleton ??= new AgentRuntimeClient());
}
