/**
 * OpenProject connector for the Kyndral-365 server.
 *
 * Mirrors the existing source-tool clients (jiraClient.ts / planviewClient.ts):
 * same shape — config, typed entities, request<T>(), testConnection(),
 * getters, syncProject(projectId, sourceSystemId) -> storage, status/priority
 * mappers, and createOpenProjectClientFromAdapter(adapterId).
 *
 * DIFFERENCE FROM THE OTHER CLIENTS — this one is BIDIRECTIONAL, because the
 * vision is "OpenProject as the datastore":
 *   inbound  : OpenProject -> Kyndral (syncProject + handleWebhook, real-time)
 *   outbound : Kyndral/agents -> OpenProject (createWorkPackage, updateWorkPackageStatus,
 *              updateProjectStatus, addComment)  ← write the agentic layer back
 *
 * OpenProject API: APIv3, basic-auth `apikey:<key>`, _embedded.elements unwrap.
 * (Ported from agentic-ppm/agent-runtime/src/openproject/client.ts — proven.)
 *
 * DROP-IN: place this file in `server/` next to planviewClient.ts. It imports
 * `./storage` exactly like the others. Add adapterType 'openproject' wherever the
 * MCP adapter types are enumerated, and register the routes in server/routes (see
 * README in this folder).
 */
import { storage } from "./storage";

export interface OpenProjectConfig {
  /** e.g. https://openproject.example.com (no trailing slash needed). */
  baseUrl: string;
  /** OpenProject API key (My Account → Access tokens). */
  apiKey: string;
  /** Optional: restrict sync to one project id/identifier. */
  projectId?: string;
}

export interface OpenProjectProjectDTO {
  id: number;
  identifier: string;
  name: string;
  active?: boolean;
  description?: { raw?: string };
  _links?: { parent?: { href?: string }; status?: { href?: string } };
}

export interface OpenProjectWorkPackageDTO {
  id: number;
  subject: string;
  description?: { raw?: string };
  startDate?: string;
  dueDate?: string;
  percentageDone?: number;
  estimatedTime?: string;
  storyPoints?: number;
  lockVersion?: number;
  _links?: {
    type?: { title?: string };
    status?: { title?: string };
    priority?: { title?: string };
    assignee?: { title?: string };
    project?: { href?: string };
    parent?: { href?: string };
  };
  [key: string]: any;
}

export interface OpenProjectSyncResult {
  projectsCreated: number;
  featuresCreated: number;
  storiesCreated: number;
  tasksCreated: number;
  risksCreated: number;
  errors: string[];
}

/** OpenProject WP type name -> SAFe storage entity bucket (canonical ontology mapping). */
type Bucket = "feature" | "story" | "task" | "risk";
const TYPE_BUCKET: Record<string, Bucket> = {
  Epic: "feature",
  Capability: "feature",
  Feature: "feature",
  "User Story": "story",
  Story: "story",
  Task: "task",
  Bug: "task",
  Risk: "risk",
  Phase: "feature",
  Milestone: "task",
};

export class OpenProjectClient {
  private baseUrl: string;
  private authHeader: string;
  private projectFilter?: string;

  constructor(config: OpenProjectConfig) {
    this.baseUrl = config.baseUrl.replace(/\/$/, "");
    this.authHeader = Buffer.from(`apikey:${config.apiKey}`).toString("base64");
    this.projectFilter = config.projectId;
  }

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
      throw new Error(`OpenProject API ${response.status} on ${endpoint}: ${errorText}`);
    }
    if (response.status === 204) return undefined as T;
    return (await response.json()) as T;
  }

  // ── Reads ────────────────────────────────────────────────────────────────
  async testConnection(): Promise<{ success: boolean; message: string }> {
    try {
      const root = await this.request<any>("/");
      return { success: true, message: `Connected to ${root.instanceName ?? "OpenProject"} (core ${root.coreVersion ?? "?"})` };
    } catch (e: any) {
      return { success: false, message: e.message };
    }
  }

  async getProjects(): Promise<OpenProjectProjectDTO[]> {
    const out: OpenProjectProjectDTO[] = [];
    for (let page = 1; ; page++) {
      const data = await this.request<any>(`/projects?pageSize=100&offset=${page}`);
      const els: OpenProjectProjectDTO[] = data._embedded?.elements ?? [];
      out.push(...els);
      if (els.length < 100) break;
    }
    return this.projectFilter ? out.filter((p) => String(p.id) === this.projectFilter || p.identifier === this.projectFilter) : out;
  }

  async getWorkPackages(projectId: string | number): Promise<OpenProjectWorkPackageDTO[]> {
    const out: OpenProjectWorkPackageDTO[] = [];
    for (let page = 1; ; page++) {
      const data = await this.request<any>(`/projects/${projectId}/work_packages?pageSize=200&offset=${page}`);
      const els: OpenProjectWorkPackageDTO[] = data._embedded?.elements ?? [];
      out.push(...els);
      if (els.length < 200) break;
    }
    return out;
  }

  async getWorkPackage(id: number): Promise<OpenProjectWorkPackageDTO> {
    return this.request<OpenProjectWorkPackageDTO>(`/work_packages/${id}`);
  }

  // ── Mappers (canonical ontology) ──────────────────────────────────────────
  private mapStatusToHealth(active?: boolean): string {
    return active === false ? "off-track" : "on-track";
  }
  private mapStatusToSafe(status?: string): string {
    const s = (status ?? "New").toLowerCase();
    if (["closed", "done", "completed", "resolved"].includes(s)) return "done";
    if (["in progress", "in development", "developing"].includes(s)) return "in-progress";
    if (["on hold", "blocked"].includes(s)) return "blocked";
    if (["rejected", "cancelled", "canceled"].includes(s)) return "cancelled";
    return "todo";
  }
  private mapPriorityToSafe(priority?: string): string {
    const p = (priority ?? "Normal").toLowerCase();
    if (["immediate", "urgent", "critical"].includes(p)) return "critical";
    if (p === "high") return "high";
    if (p === "low") return "low";
    return "medium";
  }
  private hoursFromISODuration(iso?: string): string | undefined {
    if (!iso) return undefined;
    const m = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?/);
    if (!m) return undefined;
    return String((parseInt(m[1] || "0", 10)) + parseInt(m[2] || "0", 10) / 60);
  }

  // ── Inbound sync: OpenProject -> Kyndral storage ──────────────────────────
  async syncProject(projectId: string, sourceSystemId: string): Promise<OpenProjectSyncResult> {
    const result: OpenProjectSyncResult = {
      projectsCreated: 0, featuresCreated: 0, storiesCreated: 0, tasksCreated: 0, risksCreated: 0, errors: [],
    };
    try {
      const opProjects = await this.getProjects();
      const opProject = opProjects.find((p) => String(p.id) === String(projectId) || p.identifier === projectId);
      if (!opProject) throw new Error(`OpenProject project ${projectId} not found`);

      const existing = await storage.getProjects();
      let project = existing.find((p: any) => p.name === opProject.name);
      if (!project) {
        project = await storage.createProject({
          name: opProject.name,
          description: opProject.description?.raw || `Imported from OpenProject`,
          status: this.mapStatusToHealth(opProject.active),
        } as any);
        result.projectsCreated++;
      }

      const wps = await this.getWorkPackages(opProject.id);
      // Pass 1: features (so stories/tasks have a parent). Track OP id -> feature id.
      const featureByOpId: Record<string, string> = {};
      for (const wp of wps) {
        const bucket = TYPE_BUCKET[wp._links?.type?.title ?? "Task"] ?? "task";
        if (bucket !== "feature") continue;
        try {
          const feature = await storage.createFeature({
            projectId: project.id,
            name: wp.subject,
            description: wp.description?.raw ?? "",
            status: this.mapStatusToSafe(wp._links?.status?.title),
            priority: this.mapPriorityToSafe(wp._links?.priority?.title),
            storyPoints: wp.storyPoints?.toString(),
          } as any);
          featureByOpId[String(wp.id)] = feature.id;
          result.featuresCreated++;
        } catch (e: any) {
          result.errors.push(`feature ${wp.subject}: ${e.message}`);
        }
      }
      const anyFeatureId = Object.values(featureByOpId)[0];

      // Pass 2: stories, parented to their OP parent feature when resolvable.
      const storyByOpId: Record<string, string> = {};
      for (const wp of wps) {
        const bucket = TYPE_BUCKET[wp._links?.type?.title ?? "Task"] ?? "task";
        if (bucket !== "story") continue;
        const parentOpId = wp._links?.parent?.href?.split("/").pop();
        const featureId = (parentOpId && featureByOpId[parentOpId]) || anyFeatureId;
        if (!featureId) { result.errors.push(`story ${wp.subject}: no parent feature`); continue; }
        try {
          const story = await storage.createStory({
            projectId: project.id,
            featureId,
            name: wp.subject,
            description: wp.description?.raw ?? "",
            status: this.mapStatusToSafe(wp._links?.status?.title),
            storyPoints: wp.storyPoints?.toString(),
            assignedTeam: wp._links?.assignee?.title,
          } as any);
          storyByOpId[String(wp.id)] = story.id;
          result.storiesCreated++;
        } catch (e: any) {
          result.errors.push(`story ${wp.subject}: ${e.message}`);
        }
      }
      const anyStoryId = Object.values(storyByOpId)[0];

      // Pass 3: tasks + risks.
      for (const wp of wps) {
        const bucket = TYPE_BUCKET[wp._links?.type?.title ?? "Task"] ?? "task";
        if (bucket === "feature" || bucket === "story") continue;
        try {
          if (bucket === "risk") {
            await storage.createRisk({
              projectId: project.id,
              name: wp.subject,
              description: wp.description?.raw ?? "",
              probability: this.mapPriorityToSafe(wp._links?.priority?.title),
              impact: this.mapPriorityToSafe(wp._links?.priority?.title),
            } as any);
            result.risksCreated++;
          } else {
            const parentOpId = wp._links?.parent?.href?.split("/").pop();
            const storyId = (parentOpId && storyByOpId[parentOpId]) || anyStoryId;
            const featureId = anyFeatureId;
            if (!storyId || !featureId) { result.errors.push(`task ${wp.subject}: no parent`); continue; }
            await storage.createTask({
              projectId: project.id,
              featureId,
              storyId,
              name: wp.subject,
              description: wp.description?.raw ?? "",
              status: this.mapStatusToSafe(wp._links?.status?.title),
              priority: this.mapPriorityToSafe(wp._links?.priority?.title),
              assignee: wp._links?.assignee?.title,
            } as any);
            result.tasksCreated++;
          }
        } catch (e: any) {
          result.errors.push(`task/risk ${wp.subject}: ${e.message}`);
        }
      }

      await storage.createNotification({
        type: "success",
        title: "OpenProject Sync Complete",
        message: `Synced ${result.projectsCreated} projects, ${result.featuresCreated} features, ${result.storiesCreated} stories, ${result.tasksCreated} tasks, ${result.risksCreated} risks`,
        severity: result.errors.length > 0 ? "warning" : "info",
        source: "openproject_sync",
        sourceId: String(opProject.id),
      } as any);
    } catch (error: any) {
      result.errors.push(`Sync failed: ${error.message}`);
      await storage.createNotification({
        type: "sync_failure",
        title: "OpenProject Sync Failed",
        message: error.message,
        severity: "error",
        source: "openproject_sync",
        sourceId: String(projectId),
      } as any).catch(() => {});
    }
    return result;
  }

  // ── Outbound (bidirectional): Kyndral / agents -> OpenProject ──────────────
  private async typeHref(typeName: string): Promise<string | undefined> {
    const data = await this.request<any>("/types");
    const t = (data._embedded?.elements ?? []).find((x: any) => x.name === typeName);
    return t?._links?.self?.href ?? t?.id ? `/api/v3/types/${t?.id}` : undefined;
  }

  /** Create a work package in OpenProject (e.g. an agent follow-up / recommendation). */
  async createWorkPackage(projectId: string | number, opts: { subject: string; description?: string; typeName?: string }): Promise<OpenProjectWorkPackageDTO> {
    const payload: Record<string, unknown> = { subject: opts.subject };
    if (opts.description) payload.description = { raw: opts.description };
    const href = opts.typeName ? await this.typeHref(opts.typeName) : undefined;
    if (href) payload._links = { type: { href } };
    return this.request<OpenProjectWorkPackageDTO>(`/projects/${projectId}/work_packages`, {
      method: "POST",
      body: JSON.stringify(payload),
    });
  }

  /** Write the agent verdict to OpenProject's native project status banner. */
  async updateProjectStatus(projectId: string | number, statusCode: "on_track" | "at_risk" | "off_track", explanation: string): Promise<void> {
    const project = await this.request<any>(`/projects/${projectId}`);
    await this.request(`/projects/${projectId}`, {
      method: "PATCH",
      body: JSON.stringify({
        lockVersion: project.lockVersion,
        statusExplanation: { raw: explanation },
        _links: { status: { href: `/api/v3/project_statuses/${statusCode}` } },
      }),
    });
  }

  async addWorkPackageComment(workPackageId: number, comment: string): Promise<void> {
    await this.request(`/work_packages/${workPackageId}/activities`, {
      method: "POST",
      body: JSON.stringify({ comment: { raw: comment } }),
    });
  }

  /** Inbound webhook: re-fetch the changed WP and re-sync its project. */
  async handleWebhook(payload: any, sourceSystemId: string): Promise<void> {
    const projectHref = payload?.work_package?._links?.project?.href ?? payload?.project?._links?.self?.href;
    const projectId = projectHref?.split("/").pop();
    if (projectId) await this.syncProject(projectId, sourceSystemId);
  }
}

export async function createOpenProjectClientFromAdapter(adapterId: string): Promise<OpenProjectClient | null> {
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
    return new OpenProjectClient({ baseUrl: config.baseUrl, apiKey: config.apiKey, projectId: config.projectId });
  } catch (e: any) {
    console.error(`OpenProject adapter config parse failed: ${e.message}`);
    return null;
  }
}
