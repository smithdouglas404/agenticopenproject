/**
 * Event-driven orchestration bootstrap for Kyndral-365 DOSv2.
 *
 * Kyndral already ships a fully-implemented EventDrivenOrchestrator
 * (server/lib/EventDrivenOrchestrator.ts, 467 lines: registerChange(),
 * registerMemoryChange(), determineAgentsForEvents(), startListening(),
 * hash-based change detection) — it is just never instantiated. Meanwhile the
 * 15-second ContinuousOrchestrator polling loop burns $10–15k/yr re-analyzing
 * unchanged projects. This file is the missing ~30 lines of wiring.
 * Full steps + cost table: see ACTIVATE_EVENT_DRIVEN.md next to this file.
 *
 * NOTE ON PATHS: import paths below are relative to Kyndral's `server/`
 * directory — i.e. copy this file to `server/patches/eventDrivenBootstrap.ts`
 * (or inline it into server/index.ts) inside the Kyndral repo. It will not
 * resolve from inside this connector folder.
 */
// If EventDrivenOrchestrator is a default export in your tree, switch to:
//   import EventDrivenOrchestrator from "../lib/EventDrivenOrchestrator";
import { EventDrivenOrchestrator } from "../lib/EventDrivenOrchestrator";

/** Loose change-event shape accepted by EventDrivenOrchestrator.registerChange. */
export interface ChangeEvent {
  type: "budget" | "schedule" | "scope" | "status" | "risk" | string;
  projectId?: string;
  entityType?: string;
  entityId?: string;
  severity?: "low" | "medium" | "high" | "critical";
  source?: string;
  summary?: string;
  prev?: unknown;
  next?: unknown;
  timestamp?: string;
  [key: string]: unknown;
}

/**
 * Instantiate + start the event-driven engine. Call ONCE from server/index.ts
 * after the agents are bootstrapped (and after `orchestrator.start(...)` in
 * DeepAgentBootstrap.ts ~line 131 has been commented out — see the .md).
 *
 * @param storage  Kyndral's storage layer (same object DeepAgentBootstrap uses).
 * @param agents   name → agent instance map (finops, risk, tmo, pmo, governance, …),
 *                 i.e. the same agents ContinuousOrchestrator was polling.
 */
export function activateEventDrivenOrchestration(
  storage: any,
  agents: Record<string, any>,
): EventDrivenOrchestrator {
  const orchestrator = new EventDrivenOrchestrator(storage);

  // Register agents. EventDrivenOrchestrator's registration API name varies by
  // revision — handle the common shapes so this patch survives drift.
  const o = orchestrator as any;
  for (const [name, agent] of Object.entries(agents)) {
    if (typeof o.registerAgent === "function") o.registerAgent(name, agent);
    else if (typeof o.addAgent === "function") o.addAgent(name, agent);
    else if (o.agents instanceof Map) o.agents.set(name, agent);
    else if (o.agents && typeof o.agents === "object") o.agents[name] = agent;
    else console.warn(`[event-driven] could not register agent "${name}" — check the registration API`);
  }

  // 5s tick: drains queued change events and dispatches via
  // determineAgentsForEvents() (budget→finops+risk, schedule→tmo/pmo,
  // risk→risk/governance). Idle when nothing changed — that's the ~93% saving.
  orchestrator.startListening(5000);
  console.log(
    `[event-driven] orchestrator listening (5s tick, ${Object.keys(agents).length} agents); ` +
      "polling ContinuousOrchestrator must be disabled in DeepAgentBootstrap.ts",
  );
  return orchestrator;
}

// ─────────────────────────────────────────────────────────────────────────────
// CRUD change hooks: how routes should feed the orchestrator.
// Only MATERIAL field changes emit events — a description edit must not wake
// the FinOps agent. Diff prev vs next and classify the changed field.
// ─────────────────────────────────────────────────────────────────────────────

/** Material fields → change-event type. Extend as the schema grows. */
const MATERIAL_FIELDS: Record<string, ChangeEvent["type"]> = {
  // status / health
  status: "status",
  health: "status",
  // budget / EVM
  budget: "budget",
  plannedBudget: "budget",
  budgetSpent: "budget",
  actualCost: "budget",
  earnedValue: "budget",
  bac: "budget",
  eac: "budget",
  // schedule
  startDate: "schedule",
  endDate: "schedule",
  dueDate: "schedule",
  completedDate: "schedule",
  // risk
  riskScore: "risk",
  probability: "risk",
  impact: "risk",
};

const HIGH_SEVERITY_TYPES = new Set<string>(["budget", "risk"]);

function normalize(v: unknown): string {
  if (v === null || v === undefined) return "";
  if (v instanceof Date) return v.toISOString();
  return String(v);
}

export interface CrudChangeHooks {
  /**
   * Call from update routes AFTER persisting. Diffs prev vs next over the
   * material fields; emits one registerChange per changed event type.
   * Returns the events emitted (handy for tests / audit logs).
   */
  onEntityUpdated(
    entityType: string,
    entityId: string,
    prev: Record<string, unknown> | null | undefined,
    next: Record<string, unknown>,
    projectId?: string,
  ): ChangeEvent[];
  /** Call from create routes — creation is a scope change. */
  onEntityCreated(entityType: string, entityId: string, projectId?: string): ChangeEvent;
}

/**
 * Build the hooks the CRUD routes call. Usage in a route (e.g. PATCH /api/projects/:id):
 *
 *   const prev = await storage.getProject(id);
 *   const next = await storage.updateProject(id, body);
 *   crudHooks.onEntityUpdated("project", id, prev, next, id);
 */
export function registerCrudChangeHooks(orchestrator: EventDrivenOrchestrator): CrudChangeHooks {
  const emit = (event: ChangeEvent): void => {
    (orchestrator as any).registerChange(event);
  };

  return {
    onEntityUpdated(entityType, entityId, prev, next, projectId) {
      const changedByType = new Map<string, string[]>();
      for (const [field, eventType] of Object.entries(MATERIAL_FIELDS)) {
        if (!(field in next) && !(prev && field in prev)) continue;
        if (normalize(prev?.[field]) === normalize(next[field])) continue; // unchanged
        const list = changedByType.get(eventType) ?? [];
        list.push(field);
        changedByType.set(eventType, list);
      }

      const events: ChangeEvent[] = [];
      for (const [type, fields] of changedByType) {
        const event: ChangeEvent = {
          type,
          entityType,
          entityId,
          projectId: projectId ?? (next.projectId as string | undefined),
          severity: HIGH_SEVERITY_TYPES.has(type) ? "high" : "medium",
          source: "crud",
          summary: `${entityType} ${entityId}: ${fields.join(", ")} changed`,
          prev: prev ? Object.fromEntries(fields.map((f) => [f, prev[f]])) : undefined,
          next: Object.fromEntries(fields.map((f) => [f, next[f]])),
          timestamp: new Date().toISOString(),
        };
        emit(event);
        events.push(event);
      }
      return events;
    },

    onEntityCreated(entityType, entityId, projectId) {
      const event: ChangeEvent = {
        type: "scope",
        entityType,
        entityId,
        projectId,
        severity: "medium",
        source: "crud",
        summary: `${entityType} ${entityId} created`,
        timestamp: new Date().toISOString(),
      };
      emit(event);
      return event;
    },
  };
}
