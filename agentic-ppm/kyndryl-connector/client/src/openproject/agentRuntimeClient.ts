/**
 * agentRuntimeClient — a thin, typed client that lets Kyndral's Mastra deep
 * agents (DeepAgentBase) pull GROUNDED facts from the agent-runtime BEFORE they
 * reason, so the LLM stops inventing numbers.
 *
 * The contract (see docs/AGENT_CONSOLIDATION.md + docs/MASTRA_GROUNDING_INTEGRATION.md):
 *   the Mastra agents are the brain (Mem0 + Letta memory, planning, a2a); the
 *   agent-runtime is the GROUNDING / DATA layer (FalkorDB world-model + computed
 *   metrics + the OpenProject-authored rules engine). It does NO LLM reasoning.
 *
 * HOW TO USE inside a deep agent:
 *   1. Before reasoning, call `getMetrics()`, `getRules()`, `getProjectStatus()`
 *      (and optionally `getGraphSlice(nodeId)`) and put the returned values into
 *      the prompt as authoritative facts. CITE metric ids; never let the LLM
 *      compute or guess a number — every figure must trace to a metric here.
 *   2. When the agent concludes something actionable, `publishFinding(finding)`
 *      so it surfaces in the HITL surfaces (AgentConsole / ApprovalQueue) and,
 *      on approval, mirrors back to OpenProject.
 *
 * Transport: plain fetch. In the browser/server it talks to the Kyndral proxy
 * (`/api/agent/*`, server/routes/agentFindings.routes.ts) so the runtime token
 * stays server-side. Set `baseUrl` (or AGENT_RUNTIME_BASE) to hit the runtime
 * directly from a server-side agent.
 *
 * DROP-IN: copy to Kyndral `client/src/openproject/agentRuntimeClient.ts` and
 * construct one in DeepAgentBase. Zero deps beyond fetch.
 */

/** A computed (never generated) metric. Cite `id` in agent narratives. */
export interface RuntimeMetric {
  id: string;
  label: string;
  value: string | number;
  formula?: string;
}

export interface MetricsResult {
  computedAt?: string;
  metrics: RuntimeMetric[];
}

/** Per-project computed status (deterministic). */
export interface ProjectStatusItem {
  id: string;
  title: string;
  severity: string;
  narrative?: string;
  body?: string;
  projectName?: string;
  nodeId?: string;
  updatedAt?: string;
}

/** A rule as authored in OpenProject and served by the runtime. */
export interface RuntimeRule {
  id: string;
  name: string;
  ontology_class: string;
  metric: string;
  operator: string;
  threshold?: number | null;
  severity: string;
  enabled: boolean;
  [k: string]: unknown;
}

/** A finding (deterministic breach or an agent-published conclusion). */
export interface RuntimeFinding {
  id: string;
  type: string;
  agentId: string;
  severity: "low" | "medium" | "high" | string;
  title: string;
  body: string;
  narrative?: string;
  status: string;
  nodeId?: string;
  workPackageId?: number;
  projectId?: number;
  projectName?: string;
  /** JSON string: [{entityId, metric, value}] — the evidence trail. */
  evidence?: string;
  /** 0–1. */
  confidence?: number;
  createdAt: string;
  updatedAt: string;
}

/** What an agent publishes. The runtime assigns id/timestamps/status. */
export interface PublishFindingInput {
  type: string;
  agentId: string;
  severity: "low" | "medium" | "high" | string;
  title: string;
  body: string;
  narrative?: string;
  nodeId?: string;
  workPackageId?: number;
  projectId?: number;
  projectName?: string;
  /** Cite the metric ids / entities the conclusion rests on. */
  evidence?: string;
  confidence?: number;
}

export interface FindingsFilter {
  status?: string;
  agentId?: string;
  type?: string;
  excludeType?: string;
  limit?: number;
}

/** A slice of the FalkorDB world-model around a node (if the runtime serves it). */
export interface GraphSlice {
  nodeId: string;
  nodes: Array<{ id: string; labels?: string[]; props?: Record<string, unknown> }>;
  edges: Array<{ from: string; to: string; type: string; props?: Record<string, unknown> }>;
}

/** Minimal ambient shape so we can read env without depending on @types/node. */
declare const process: { env?: Record<string, string | undefined> } | undefined;

/** Resolve a default base: explicit arg → env → the Kyndral proxy. */
function resolveBase(explicit?: string): string {
  const env =
    typeof process !== "undefined" && process?.env ? process.env.AGENT_RUNTIME_BASE : undefined;
  return (explicit ?? env ?? "/api/agent").replace(/\/+$/, "");
}

export interface AgentRuntimeClientOptions {
  /** Base URL. Defaults to AGENT_RUNTIME_BASE or the Kyndral proxy `/api/agent`. */
  baseUrl?: string;
  /** Optional bearer token (only when calling the runtime directly, server-side). */
  token?: string;
  /** Inject a custom fetch (e.g. node-fetch / a test stub). */
  fetchImpl?: typeof fetch;
}

/**
 * Thin grounding client for DeepAgentBase. Construct once per agent (or share),
 * call the getters before reasoning, `publishFinding` after.
 */
export class AgentRuntimeClient {
  private readonly base: string;
  private readonly token?: string;
  private readonly fetchImpl: typeof fetch;

  constructor(opts: AgentRuntimeClientOptions = {}) {
    this.base = resolveBase(opts.baseUrl);
    this.token = opts.token;
    this.fetchImpl = opts.fetchImpl ?? fetch;
  }

  private async request<T>(path: string, init?: RequestInit): Promise<T> {
    const headers: Record<string, string> = {
      Accept: "application/json",
      ...(init?.headers as Record<string, string> | undefined),
    };
    if (this.token) headers.Authorization = `Bearer ${this.token}`;
    if (init?.body !== undefined) headers["Content-Type"] = "application/json";
    const res = await this.fetchImpl(`${this.base}${path}`, { ...init, headers });
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new Error(`agent-runtime ${path} → HTTP ${res.status}${detail ? `: ${detail}` : ""}`);
    }
    return (await res.json()) as T;
  }

  /** Computed portfolio metrics. Feed these into the prompt; cite the ids. */
  async getMetrics(): Promise<MetricsResult> {
    const data = await this.request<MetricsResult | RuntimeMetric[]>("/metrics");
    return Array.isArray(data) ? { metrics: data } : { metrics: data.metrics ?? [], computedAt: data.computedAt };
  }

  /** Per-project computed status (deterministic). */
  async getProjectStatus(): Promise<ProjectStatusItem[]> {
    const data = await this.request<ProjectStatusItem[] | { items?: ProjectStatusItem[] }>("/project-status");
    return Array.isArray(data) ? data : (data.items ?? []);
  }

  /** The OpenProject-authored rules currently in force. */
  async getRules(): Promise<RuntimeRule[]> {
    const data = await this.request<RuntimeRule[] | { rules?: RuntimeRule[] }>("/rules");
    return Array.isArray(data) ? data : (data.rules ?? []);
  }

  /** Findings (deterministic breaches and previously published conclusions). */
  async getFindings(filter?: FindingsFilter): Promise<RuntimeFinding[]> {
    const qs = new URLSearchParams();
    if (filter) {
      for (const [k, v] of Object.entries(filter)) {
        if (v !== undefined && v !== null && v !== "") qs.set(k, String(v));
      }
    }
    const path = `/findings${qs.toString() ? `?${qs}` : ""}`;
    const data = await this.request<RuntimeFinding[] | { findings?: RuntimeFinding[] }>(path);
    return Array.isArray(data) ? data : (data.findings ?? []);
  }

  /** Publish an agent conclusion so it surfaces in the HITL queue. */
  async publishFinding(finding: PublishFindingInput): Promise<RuntimeFinding> {
    return this.request<RuntimeFinding>("/findings", {
      method: "POST",
      body: JSON.stringify(finding),
    });
  }

  /**
   * Optional: a slice of the FalkorDB world-model around a node, for the agent
   * to reason over local structure. Resolves `null` if the runtime doesn't
   * expose the endpoint (treat graph grounding as best-effort).
   */
  async getGraphSlice(nodeId: string): Promise<GraphSlice | null> {
    try {
      return await this.request<GraphSlice>(`/graph/${encodeURIComponent(nodeId)}`);
    } catch {
      return null;
    }
  }
}

/** Convenience factory matching the env-default convention. */
export function createAgentRuntimeClient(opts?: AgentRuntimeClientOptions): AgentRuntimeClient {
  return new AgentRuntimeClient(opts);
}

export default AgentRuntimeClient;
