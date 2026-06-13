/**
 * Agent findings proxy — exposes the agent-runtime's HITL surface to the
 * Kyndral UI without leaking the runtime CONSOLE_TOKEN to the browser.
 *
 * The agent-runtime sidecar (agentic-ppm/agent-runtime in the
 * agenticopenproject repo) owns the findings lifecycle:
 *   GET  /api/findings?status=published     → open insights/recommendations
 *   POST /api/findings/:id/approve|reject   → HITL decision (executes the
 *        gated action, mirrors to OpenProject, records the human label for
 *        the learning loop)
 *   GET  /api/learning                      → per-agent accuracy track record
 *   GET  /api/metrics                       → computed (not generated) metrics
 *
 * This router proxies those under /api/agent/* for the Kyndral client
 * (see client/src/openproject/ApprovalQueue.tsx).
 *
 * DROP-IN: copy to Kyndral `server/routes/agentFindings.routes.ts`, then in
 * server/routes.ts (behind the existing auth middleware):
 *   import { initAgentFindingsRoutes } from "./routes/agentFindings.routes";
 *   initAgentFindingsRoutes(app);
 * Env: AGENT_RUNTIME_URL (e.g. https://agent-runtime.up.railway.app),
 *      AGENT_RUNTIME_TOKEN (the runtime's CONSOLE_TOKEN, if set).
 */
import type { Request, Response, Router } from "express";

const RUNTIME_URL = (process.env.AGENT_RUNTIME_URL ?? "http://localhost:8745").replace(/\/+$/, "");
const RUNTIME_TOKEN = process.env.AGENT_RUNTIME_TOKEN ?? process.env.CONSOLE_TOKEN;

async function forward(
  res: Response,
  path: string,
  init?: { method?: string; body?: unknown },
): Promise<void> {
  try {
    const headers: Record<string, string> = { Accept: "application/json" };
    if (RUNTIME_TOKEN) headers.Authorization = `Bearer ${RUNTIME_TOKEN}`;
    if (init?.body !== undefined) headers["Content-Type"] = "application/json";
    const upstream = await fetch(`${RUNTIME_URL}${path}`, {
      method: init?.method ?? "GET",
      headers,
      body: init?.body !== undefined ? JSON.stringify(init.body) : undefined,
    });
    const body = await upstream.text();
    res
      .status(upstream.status)
      .type(upstream.headers.get("content-type") ?? "application/json")
      .send(body);
  } catch (err: any) {
    res.status(502).json({
      error: `agent-runtime unreachable at ${RUNTIME_URL}: ${err?.message ?? err}`,
    });
  }
}

/** Allow-list of decision verbs so the proxy can't be steered to other paths. */
const DECISIONS = new Set(["approve", "reject"]);

export function initAgentFindingsRoutes(router: Router): Router {
  router.get("/api/agent/findings", (req: Request, res: Response) => {
    const qs = new URLSearchParams();
    for (const key of ["status", "agentId", "type", "excludeType", "limit"] as const) {
      const value = req.query[key];
      if (typeof value === "string" && value) qs.set(key, value);
    }
    void forward(res, `/api/findings${qs.size ? `?${qs}` : ""}`);
  });

  router.post("/api/agent/findings/:id/:decision", (req: Request, res: Response) => {
    const id = String(req.params.id ?? "");
    const decision = String(req.params.decision ?? "");
    if (!DECISIONS.has(decision)) {
      res.status(400).json({ error: `decision must be one of: ${[...DECISIONS].join(", ")}` });
      return;
    }
    // Finding ids are sanitized by the runtime to [A-Za-z0-9_:-]; reject anything else.
    if (!/^[A-Za-z0-9_:-]+$/.test(id)) {
      res.status(400).json({ error: "invalid finding id" });
      return;
    }
    // The runtime reads decidedBy from the JSON body (defaults to 'console').
    const decidedBy = typeof req.body?.decidedBy === "string" ? req.body.decidedBy : undefined;
    void forward(res, `/api/findings/${id}/${decision}`, {
      method: "POST",
      body: decidedBy ? { decidedBy } : {},
    });
  });

  router.get("/api/agent/learning", (_req, res) => void forward(res, "/api/learning"));
  router.get("/api/agent/metrics", (_req, res) => void forward(res, "/api/metrics"));
  router.get("/api/agent/roster", (_req, res) => void forward(res, "/api/roster"));
  router.get("/api/agent/rules", (_req, res) => void forward(res, "/api/rules"));
  router.get("/api/agent/status", (_req, res) => void forward(res, "/api/status"));
  router.get("/api/agent/project-status", (_req, res) => void forward(res, "/api/project-status"));
  router.post("/api/agent/sweep", (_req, res) => void forward(res, "/api/sweep", { method: "POST" }));

  // Ontology-as-universal-mapper (schema discovery + mapping studio).
  router.get("/api/agent/openproject/schema", (_req, res) => void forward(res, "/api/openproject/schema"));
  router.get("/api/agent/ontology/properties", (_req, res) => void forward(res, "/api/ontology/properties"));
  router.get("/api/agent/widgets", (_req, res) => void forward(res, "/api/widgets"));

  // Multi-source adapters / MCP (the MappingStudio source dropdown + adapter
  // schema/tool discovery). See docs/SOURCE_ADAPTERS_AND_MCP.md.
  router.get("/api/agent/sources", (_req, res) => void forward(res, "/api/sources"));
  router.get("/api/agent/sources/:id/schema", (req, res) => {
    const id = String(req.params.id ?? "");
    if (!/^[A-Za-z0-9_:.-]+$/.test(id)) {
      res.status(400).json({ error: "invalid source id" });
      return;
    }
    void forward(res, `/api/sources/${encodeURIComponent(id)}/schema`);
  });
  router.get("/api/agent/sources/:id/tools", (req, res) => {
    const id = String(req.params.id ?? "");
    if (!/^[A-Za-z0-9_:.-]+$/.test(id)) {
      res.status(400).json({ error: "invalid source id" });
      return;
    }
    void forward(res, `/api/sources/${encodeURIComponent(id)}/tools`);
  });

  // Rule-authoring assist (ML-suggested thresholds from the learning loop).
  // The runtime serves this as GET with ?class=&metric= query params.
  router.get("/api/agent/rules/suggest", (req, res) => {
    const qs = new URLSearchParams();
    for (const k of ["class", "metric"] as const) {
      const v = req.query[k];
      if (typeof v === "string" && v) qs.set(k, v);
    }
    void forward(res, `/api/rules/suggest${qs.size ? `?${qs}` : ""}`);
  });
  router.get("/api/agent/mapping", (req, res) => {
    const source = typeof req.query.source === "string" ? req.query.source : "openproject";
    void forward(res, `/api/mapping?source=${encodeURIComponent(source)}`);
  });
  // Requires express.json() mounted so req.body is parsed for the POST.
  router.post("/api/agent/mapping", (req, res) => void forward(res, "/api/mapping", { method: "POST", body: req.body }));

  return router;
}
