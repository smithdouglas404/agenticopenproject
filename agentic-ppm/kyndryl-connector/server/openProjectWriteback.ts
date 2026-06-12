/**
 * OpenProject OUTBOUND write-back for the Kyndral-365 server.
 *
 * The other half of bidirectional sync: server/openProjectClient.ts pulls
 * OpenProject INTO Kyndral (syncProject + handleWebhook); this module pushes
 * Kyndral UI edits BACK to OpenProject so OpenProject stays the system of
 * record. It WRAPS the existing OpenProjectClient (imported, not modified) and
 * adds only what that client is missing:
 *   - raw `PATCH /api/v3/work_packages/{id}` with lockVersion handling
 *     (GET first → include lockVersion → retry ONCE on 409 with a refetched
 *     lockVersion — APIv3 optimistic locking, same convention as
 *     agent-runtime/src/openproject/client.ts updateProjectStatus),
 *   - `PATCH /api/v3/projects/{id}` for name/description,
 *   - work-package create with `_links.parent` (the client's create can't parent),
 *   - status/priority/type/assignee href resolution BY NAME (cached lookups of
 *     /statuses, /priorities, /types, /users).
 *
 * Field translation (Kyndral canonical → OpenProject APIv3 work package):
 *   name            → subject
 *   description     → description: { raw }
 *   status          → _links.status   (reverse of the connector's mapStatusToSafe:
 *                       backlog→New, in_progress→In progress, done→Closed,
 *                       cancelled→Rejected; see STATUS_REVERSE_MAP)
 *   priority        → _links.priority (low→Low, medium→Normal, high→High,
 *                       critical→Immediate; see PRIORITY_REVERSE_MAP)
 *   assigneeName    → _links.assignee (resolved via /users name filter; null unsets)
 *   startDate       → startDate (YYYY-MM-DD; null clears)
 *   dueDate         → dueDate   (YYYY-MM-DD; null clears)
 *   percentComplete → percentageDone (0–100 int; writable only in work-based
 *                       progress mode — status-based mode rejects it, reported
 *                       as a warning by the caller's error handling)
 *
 * ECHO PREVENTION (read this before wiring the webhook):
 * Outbound writes here would bounce straight back through OpenProject's
 * webhook (work_package:updated → handleWebhook → re-sync → potential loop).
 * Two guards, layered:
 *   1. recentlyPushed set — every work-package id we PATCH/POST is recorded in
 *      an in-memory Set with a 30s TTL. The webhook route MUST consult
 *      `wasRecentlyPushed(wpId)` and skip work_package events for those ids
 *      (see server/routes/webhooks/openproject.ts — already wired). Project
 *      pushes are recorded as `project:<id>` keys for the same check.
 *   2. SYNC_MARKER comments — audit comments posted by this module end with
 *      `[sync:kyndral-365]`, the connector's sync-source marker convention
 *      (cf. the customField sync_source passthrough in agent-runtime's
 *      createWorkPackage). Multi-instance deployments where the in-memory set
 *      can't see a sibling's writes should ALSO skip webhook events whose
 *      cause is the integration API user (compare the event's updatedAt-by
 *      user to the API-key user) or whose latest activity comment carries the
 *      marker.
 *
 * DROP-IN (Kyndral server/):
 *   cp openProjectWriteback.ts <kyndral>/server/openProjectWriteback.ts
 *   It imports ./openProjectClient (and, via the adapter factory, ./storage —
 *   both already in place per the README drop-in steps). Routes that expose
 *   this over HTTP are in server/routes/openproject.routes.ts.
 */
import {
  OpenProjectClient,
  type OpenProjectConfig,
  type OpenProjectWorkPackageDTO,
} from "./openProjectClient";
import { storage } from "./storage";

// ── Sync-source marker (echo prevention, layer 2) ────────────────────────────

/** Appended to outbound comments; webhook consumers skip activities carrying it. */
export const SYNC_MARKER = "[sync:kyndral-365]";

// ── recentlyPushed registry (echo prevention, layer 1) ───────────────────────

const RECENTLY_PUSHED_TTL_MS = 30_000;
/** key = work-package id (number/string) or `project:<id>` → pushed-at epoch ms. */
const recentlyPushed = new Map<string, number>();

function pruneRecentlyPushed(now: number): void {
  for (const [key, at] of recentlyPushed) {
    if (now - at > RECENTLY_PUSHED_TTL_MS) recentlyPushed.delete(key);
  }
}

/** Record an outbound write so the inbound webhook can ignore its echo. */
export function markRecentlyPushed(id: number | string): void {
  const now = Date.now();
  pruneRecentlyPushed(now);
  recentlyPushed.set(String(id), now);
}

/**
 * Was this work package (or `project:<id>`) written by US within the last 30s?
 * Called by server/routes/webhooks/openproject.ts to drop echo events.
 */
export function wasRecentlyPushed(id: number | string): boolean {
  const now = Date.now();
  pruneRecentlyPushed(now);
  return recentlyPushed.has(String(id));
}

// ── Kyndral → OpenProject value maps (reverse of the client's mappers) ───────

/** Kyndral canonical status → OpenProject status NAME (reverse of mapStatusToSafe). */
export const STATUS_REVERSE_MAP: Record<string, string> = {
  backlog: "New",
  in_progress: "In progress",
  done: "Closed",
  cancelled: "Rejected",
  // tolerated aliases (other canonical values mapStatusToSafe produces)
  todo: "New",
  new: "New",
  completed: "Closed",
  canceled: "Rejected",
};

/** Kyndral canonical priority → OpenProject priority NAME (reverse of mapPriorityToSafe). */
export const PRIORITY_REVERSE_MAP: Record<string, string> = {
  low: "Low",
  medium: "Normal",
  high: "High",
  critical: "Immediate",
  // tolerated aliases
  normal: "Normal",
  immediate: "Immediate",
  urgent: "Immediate",
};

/** lowercases + collapses spaces/hyphens to underscores: "In Progress" → "in_progress". */
function canonical(value: string): string {
  return value.trim().toLowerCase().replace(/[\s-]+/g, "_");
}

// ── Public change shapes (what the Kyndral UI PATCHes) ───────────────────────

/** Partial edit of a synced work-package-backed entity (feature/story/task/risk). */
export interface KyndralEntityChanges {
  name?: string;
  description?: string;
  /** Kyndral canonical: backlog | in_progress | done | cancelled (aliases tolerated). */
  status?: string;
  /** Kyndral canonical: low | medium | high | critical. */
  priority?: string;
  /** Display name of the assignee in OpenProject; null unsets the assignee. */
  assigneeName?: string | null;
  /** YYYY-MM-DD; null clears the date. */
  startDate?: string | null;
  /** YYYY-MM-DD; null clears the date. */
  dueDate?: string | null;
  /** 0–100. */
  percentComplete?: number;
}

export interface KyndralProjectChanges {
  name?: string;
  description?: string;
  statusExplanation?: string;
  /** OpenProject native project-status banner code. */
  status?: "on_track" | "at_risk" | "off_track";
}

export interface WritebackResult {
  /** OpenProject id of the entity written. */
  id: number | string;
  /** Deep link into the OpenProject UI. */
  url: string;
  /** OpenProject fields actually written. */
  applied: string[];
  /** Fields skipped (unknown status name, unresolvable assignee, …). */
  warnings: string[];
}

// ── Errors ───────────────────────────────────────────────────────────────────

export class OpenProjectApiError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = "OpenProjectApiError";
  }
}

// ── The write-back service ───────────────────────────────────────────────────

export class OpenProjectWriteback {
  /** The wrapped bidirectional client — exposed for testConnection()/comments. */
  readonly client: OpenProjectClient;
  private readonly baseUrl: string;
  private readonly authHeader: string;
  private statusHrefByName: Map<string, string> | null = null;
  private priorityHrefByName: Map<string, string> | null = null;
  private typeHrefByName: Map<string, string> | null = null;

  constructor(config: OpenProjectConfig, client?: OpenProjectClient) {
    this.baseUrl = config.baseUrl.replace(/\/$/, "");
    this.authHeader = Buffer.from(`apikey:${config.apiKey}`).toString("base64");
    this.client = client ?? new OpenProjectClient(config);
  }

  /**
   * Same request convention as OpenProjectClient (which keeps its request()
   * private — extension lives here, the existing file stays untouched), but
   * throws a typed error so the 409 lockVersion retry can be precise.
   */
  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${this.baseUrl}/api/v3${endpoint}`;
    const response = await fetch(url, {
      ...options,
      headers: {
        Authorization: `Basic ${this.authHeader}`,
        Accept: "application/json",
        "Content-Type": "application/json",
        ...options.headers,
      },
    });
    if (!response.ok) {
      const errorText = await response.text();
      throw new OpenProjectApiError(
        response.status,
        `OpenProject API ${response.status} on ${endpoint}: ${errorText}`,
      );
    }
    if (response.status === 204) return undefined as T;
    return (await response.json()) as T;
  }

  // ── Name → href resolution (cached) ────────────────────────────────────────

  private async hrefMap(collection: "statuses" | "priorities" | "types"): Promise<Map<string, string>> {
    const cached =
      collection === "statuses"
        ? this.statusHrefByName
        : collection === "priorities"
          ? this.priorityHrefByName
          : this.typeHrefByName;
    if (cached) return cached;
    const data = await this.request<any>(`/${collection}`);
    const map = new Map<string, string>();
    for (const el of data._embedded?.elements ?? []) {
      const href = el._links?.self?.href ?? (el.id != null ? `/api/v3/${collection}/${el.id}` : undefined);
      if (el.name && href) map.set(String(el.name).toLowerCase(), href);
    }
    if (collection === "statuses") this.statusHrefByName = map;
    else if (collection === "priorities") this.priorityHrefByName = map;
    else this.typeHrefByName = map;
    return map;
  }

  /** Resolve an OpenProject user by display name → /api/v3/users/{id} href. */
  private async userHref(name: string): Promise<string | undefined> {
    const filters = encodeURIComponent(JSON.stringify([{ name: { operator: "~", values: [name] } }]));
    const data = await this.request<any>(`/users?filters=${filters}&pageSize=10`);
    const users: any[] = data._embedded?.elements ?? [];
    const exact = users.find((u) => String(u.name).toLowerCase() === name.toLowerCase());
    const user = exact ?? users[0];
    return user ? (user._links?.self?.href ?? `/api/v3/users/${user.id}`) : undefined;
  }

  // ── Translation: KyndralEntityChanges → APIv3 PATCH payload ───────────────

  private async translateEntityChanges(changes: KyndralEntityChanges): Promise<{
    payload: Record<string, unknown>;
    applied: string[];
    warnings: string[];
  }> {
    const payload: Record<string, unknown> = {};
    const links: Record<string, { href: string | null }> = {};
    const applied: string[] = [];
    const warnings: string[] = [];

    if (changes.name !== undefined) {
      payload.subject = changes.name;
      applied.push("subject");
    }
    if (changes.description !== undefined) {
      payload.description = { raw: changes.description };
      applied.push("description");
    }
    if (changes.startDate !== undefined) {
      payload.startDate = changes.startDate; // null clears
      applied.push("startDate");
    }
    if (changes.dueDate !== undefined) {
      payload.dueDate = changes.dueDate; // null clears
      applied.push("dueDate");
    }
    if (changes.percentComplete !== undefined) {
      payload.percentageDone = Math.max(0, Math.min(100, Math.round(changes.percentComplete)));
      applied.push("percentageDone");
    }

    if (changes.status !== undefined) {
      const opName = STATUS_REVERSE_MAP[canonical(changes.status)];
      const href = opName ? (await this.hrefMap("statuses")).get(opName.toLowerCase()) : undefined;
      if (href) {
        links.status = { href };
        applied.push("status");
      } else {
        warnings.push(
          `status "${changes.status}" ${opName ? `maps to "${opName}" which does not exist in this OpenProject instance` : "has no OpenProject mapping"} — skipped`,
        );
      }
    }

    if (changes.priority !== undefined) {
      const opName = PRIORITY_REVERSE_MAP[canonical(changes.priority)];
      const href = opName ? (await this.hrefMap("priorities")).get(opName.toLowerCase()) : undefined;
      if (href) {
        links.priority = { href };
        applied.push("priority");
      } else {
        warnings.push(
          `priority "${changes.priority}" ${opName ? `maps to "${opName}" which does not exist in this OpenProject instance` : "has no OpenProject mapping"} — skipped`,
        );
      }
    }

    if (changes.assigneeName !== undefined) {
      if (changes.assigneeName === null) {
        links.assignee = { href: null }; // APIv3 convention: null href unsets
        applied.push("assignee");
      } else {
        const href = await this.userHref(changes.assigneeName);
        if (href) {
          links.assignee = { href };
          applied.push("assignee");
        } else {
          warnings.push(`assignee "${changes.assigneeName}" not found in OpenProject — skipped`);
        }
      }
    }

    if (Object.keys(links).length > 0) payload._links = links;
    return { payload, applied, warnings };
  }

  // ── lockVersion-safe work-package PATCH ────────────────────────────────────

  /**
   * APIv3 requires the current lockVersion on every PATCH (optimistic lock).
   * GET first, PATCH with that lockVersion, and on 409 (someone wrote in
   * between) refetch + retry exactly once.
   */
  private async patchWorkPackage(
    wpId: number,
    payload: Record<string, unknown>,
  ): Promise<OpenProjectWorkPackageDTO> {
    const attempt = async (): Promise<OpenProjectWorkPackageDTO> => {
      const current = await this.client.getWorkPackage(wpId);
      return this.request<OpenProjectWorkPackageDTO>(`/work_packages/${wpId}`, {
        method: "PATCH",
        body: JSON.stringify({ lockVersion: current.lockVersion, ...payload }),
      });
    };
    try {
      return await attempt();
    } catch (e) {
      if (e instanceof OpenProjectApiError && e.status === 409) {
        return await attempt(); // refetched lockVersion inside
      }
      throw e;
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /**
   * Push a Kyndral UI edit of a synced work-package-backed entity to OpenProject.
   * `entity.externalId` is the OpenProject work-package id Kyndral stored at
   * sync time; `entityType` (feature/story/task/risk/…) is informational here —
   * everything WP-backed translates the same way.
   */
  async pushEntityUpdate(
    entity: { externalId: string | number; entityType: string },
    changes: KyndralEntityChanges,
    opts?: { auditComment?: boolean },
  ): Promise<WritebackResult> {
    const wpId = Number(entity.externalId);
    if (!Number.isInteger(wpId) || wpId <= 0) {
      throw new Error(`externalId "${entity.externalId}" is not an OpenProject work-package id`);
    }
    const { payload, applied, warnings } = await this.translateEntityChanges(changes);
    if (applied.length === 0) {
      return { id: wpId, url: this.deepLink(entity.entityType, wpId), applied, warnings };
    }

    // Mark BEFORE the write: the webhook can fire before the PATCH returns.
    markRecentlyPushed(wpId);
    await this.patchWorkPackage(wpId, payload);

    if (opts?.auditComment) {
      await this.client
        .addWorkPackageComment(wpId, `Updated from Kyndral-365 (${applied.join(", ")}) ${SYNC_MARKER}`)
        .catch(() => {}); // audit trail is best-effort
    }
    return { id: wpId, url: this.deepLink(entity.entityType, wpId), applied, warnings };
  }

  /**
   * Push Kyndral project edits to OpenProject: name/description via project
   * PATCH (lockVersion-safe), health verdict via the native status banner
   * (delegated to the existing client.updateProjectStatus).
   */
  async pushProjectUpdate(
    externalProjectId: string | number,
    changes: KyndralProjectChanges,
  ): Promise<WritebackResult> {
    const applied: string[] = [];
    const payload: Record<string, unknown> = {};
    if (changes.name !== undefined) {
      payload.name = changes.name;
      applied.push("name");
    }
    if (changes.description !== undefined) {
      payload.description = { raw: changes.description };
      applied.push("description");
    }
    // Explanation without a status code still lands on the banner via PATCH.
    if (changes.status === undefined && changes.statusExplanation !== undefined) {
      payload.statusExplanation = { raw: changes.statusExplanation };
      applied.push("statusExplanation");
    }

    markRecentlyPushed(`project:${externalProjectId}`);

    if (Object.keys(payload).length > 0) {
      const attempt = async () => {
        const project = await this.request<any>(`/projects/${externalProjectId}`);
        await this.request(`/projects/${externalProjectId}`, {
          method: "PATCH",
          body: JSON.stringify({ lockVersion: project.lockVersion, ...payload }),
        });
      };
      try {
        await attempt();
      } catch (e) {
        if (e instanceof OpenProjectApiError && e.status === 409) await attempt();
        else throw e;
      }
    }

    if (changes.status !== undefined) {
      await this.client.updateProjectStatus(
        externalProjectId,
        changes.status,
        changes.statusExplanation ?? "Status updated from Kyndral-365",
      );
      applied.push("status", ...(changes.statusExplanation !== undefined ? ["statusExplanation"] : []));
    }

    return {
      id: externalProjectId,
      url: this.deepLink("project", externalProjectId),
      applied,
      warnings: [],
    };
  }

  /**
   * Create a work package in OpenProject for an item born in Kyndral, so it
   * becomes OpenProject-backed: store the returned `id` as the Kyndral
   * entity's externalId and `url` as its deep link.
   */
  async createLinkedWorkPackage(
    externalProjectId: string | number,
    opts: {
      subject: string;
      description?: string;
      /** OpenProject type name, e.g. "Task", "User Story", "Feature". */
      typeName?: string;
      /** OpenProject id of the parent work package (Kyndral parent's externalId). */
      parentExternalId?: string | number;
    },
  ): Promise<{ id: number; url: string }> {
    const payload: Record<string, unknown> = { subject: opts.subject };
    if (opts.description !== undefined) payload.description = { raw: opts.description };
    const links: Record<string, { href: string }> = {};
    if (opts.typeName) {
      const href = (await this.hrefMap("types")).get(opts.typeName.toLowerCase());
      if (!href) throw new Error(`OpenProject work-package type "${opts.typeName}" not found`);
      links.type = { href };
    }
    if (opts.parentExternalId !== undefined) {
      links.parent = { href: `/api/v3/work_packages/${opts.parentExternalId}` };
    }
    if (Object.keys(links).length > 0) payload._links = links;

    const wp = await this.request<OpenProjectWorkPackageDTO>(
      `/projects/${externalProjectId}/work_packages`,
      { method: "POST", body: JSON.stringify(payload) },
    );
    markRecentlyPushed(wp.id); // the work_package:created webhook echo
    return { id: wp.id, url: this.deepLink("work_package", wp.id) };
  }

  /**
   * Deep link into the OpenProject UI for a synced entity.
   * Projects → /projects/{identifier|id}; everything WP-backed → /work_packages/{id}.
   */
  deepLink(entityType: string, externalId: string | number): string {
    const t = canonical(entityType);
    if (t === "project" || t === "portfolio" || t === "program") {
      return `${this.baseUrl}/projects/${externalId}`;
    }
    return `${this.baseUrl}/work_packages/${externalId}`;
  }
}

/**
 * Mirror of createOpenProjectClientFromAdapter: build the write-back service
 * from a stored MCP adapter row (adapterType 'openproject', configuration
 * JSON { baseUrl, apiKey, projectId? }).
 */
export async function createOpenProjectWritebackFromAdapter(
  adapterId: string,
): Promise<OpenProjectWriteback | null> {
  const adapters = await storage.getMcpAdapters();
  const adapter = adapters.find((a: any) => a.id === adapterId);
  if (!adapter || adapter.adapterType !== "openproject") {
    console.error(`OpenProject adapter not found or wrong type: ${adapterId}`);
    return null;
  }
  try {
    const config = JSON.parse(adapter.configuration || "{}");
    if (!config.baseUrl || !config.apiKey) {
      console.error("OpenProject adapter missing baseUrl/apiKey");
      return null;
    }
    return new OpenProjectWriteback({
      baseUrl: config.baseUrl,
      apiKey: config.apiKey,
      projectId: config.projectId,
    });
  } catch (e: any) {
    console.error(`OpenProject adapter config parse failed: ${e.message}`);
    return null;
  }
}

export default OpenProjectWriteback;
