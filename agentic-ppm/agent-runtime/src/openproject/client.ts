/**
 * OpenProject APIv3 client.
 *
 * LIFTED from DOSv2 `server/mcp/OpenProjectService.ts` (basic-auth `apikey:<key>`,
 * _embedded.elements unwrapping, optimistic-lock updates). Trimmed to what the
 * Quick slice needs and extended with `addWorkPackageComment` (used by the inbox)
 * which DOSv2 kept in a separate agent-tools client.
 */
import { config } from '../config.js';
import type {
  OpenProjectConnection,
  OpenProjectProject,
  OpenProjectRelation,
  OpenProjectTimeEntry,
  OpenProjectVersion,
  OpenProjectWorkPackage,
} from './types.js';

export class OpenProjectClient {
  private readonly baseUrl: string;
  private readonly apiKey: string;

  constructor(opts?: { baseUrl?: string; apiKey?: string }) {
    this.baseUrl = (opts?.baseUrl ?? config.openproject.baseUrl).replace(/\/$/, '');
    this.apiKey = opts?.apiKey ?? config.openproject.apiKey;
  }

  private async request<T = any>(method: string, endpoint: string, body?: unknown): Promise<T> {
    const url = `${this.baseUrl}/api/v3${endpoint}`;
    const auth = Buffer.from(`apikey:${this.apiKey}`).toString('base64');

    const response = await fetch(url, {
      method,
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: body ? JSON.stringify(body) : undefined,
    });

    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`OpenProject API error (${response.status}) on ${method} ${endpoint}: ${detail}`);
    }

    // DELETE returns 204 with no body.
    if (response.status === 204) return undefined as T;
    return (await response.json()) as T;
  }

  async testConnection(): Promise<OpenProjectConnection> {
    try {
      const data = await this.request('GET', '/');
      return { connected: true, version: data.coreVersion, instanceName: data.instanceName };
    } catch (error: any) {
      return { connected: false, error: error.message };
    }
  }

  async listProjects(options?: { pageSize?: number; offset?: number }): Promise<OpenProjectProject[]> {
    // OpenProject's default pageSize is 20, so a backfill MUST page explicitly.
    const params = new URLSearchParams();
    params.set('pageSize', String(options?.pageSize ?? 100));
    if (options?.offset) params.set('offset', String(options.offset));
    const data = await this.request('GET', `/projects?${params.toString()}`);
    return data._embedded?.elements ?? [];
  }

  async getProject(projectId: string | number): Promise<OpenProjectProject> {
    return this.request('GET', `/projects/${projectId}`);
  }

  /**
   * Set a project's status (on_track | at_risk | off_track) and the explanation
   * shown on the project Overview page. This surfaces the agent's portfolio-health
   * verdict natively, without a custom UI.
   */
  async updateProjectStatus(
    projectId: string | number,
    statusCode: 'on_track' | 'at_risk' | 'off_track',
    explanationRaw: string,
  ): Promise<void> {
    const project = (await this.getProject(projectId)) as OpenProjectProject & { lockVersion?: number };
    await this.request('PATCH', `/projects/${projectId}`, {
      lockVersion: project.lockVersion,
      statusExplanation: { raw: explanationRaw },
      _links: { status: { href: `/api/v3/project_statuses/${statusCode}` } },
    });
  }

  async listWorkPackages(options?: {
    projectId?: string | number;
    pageSize?: number;
    offset?: number;
  }): Promise<OpenProjectWorkPackage[]> {
    let endpoint = options?.projectId
      ? `/projects/${options.projectId}/work_packages`
      : '/work_packages';

    const params = new URLSearchParams();
    params.set('pageSize', String(options?.pageSize ?? 100));
    if (options?.offset) params.set('offset', String(options.offset));

    endpoint += `?${params.toString()}`;
    const data = await this.request('GET', endpoint);
    return data._embedded?.elements ?? [];
  }

  async getWorkPackage(workPackageId: number): Promise<OpenProjectWorkPackage> {
    return this.request('GET', `/work_packages/${workPackageId}`);
  }

  async createWorkPackage(
    projectId: string | number,
    wp: Partial<OpenProjectWorkPackage> & { subject: string },
  ): Promise<OpenProjectWorkPackage> {
    const links: Record<string, unknown> = {};
    if (wp._links?.type?.href) links.type = { href: wp._links.type.href };
    if (wp._links?.status?.href) links.status = { href: wp._links.status.href };
    if (wp._links?.priority?.href) links.priority = { href: wp._links.priority.href };

    const payload: Record<string, unknown> = {
      subject: wp.subject,
      description: wp.description,
      startDate: wp.startDate,
      dueDate: wp.dueDate,
    };
    // Pass through any customField_* markers (e.g. sync_source, alert_severity).
    for (const [key, value] of Object.entries(wp)) {
      if (key.startsWith('customField')) payload[key] = value;
    }
    if (Object.keys(links).length > 0) payload._links = links;

    return this.request('POST', `/projects/${projectId}/work_packages`, payload);
  }

  /** List available work-package types (used by the smoke test to pick a valid type). */
  async listTypes(): Promise<Array<{ id: number; name: string; self: string }>> {
    const data = await this.request('GET', '/types');
    return (data._embedded?.elements ?? []).map((t: any) => ({
      id: t.id,
      name: t.name,
      self: t._links?.self?.href ?? `/api/v3/types/${t.id}`,
    }));
  }

  /** Delete a work package (used by the smoke test for cleanup). */
  async deleteWorkPackage(workPackageId: number): Promise<void> {
    await this.request('DELETE', `/work_packages/${workPackageId}`);
  }

  private typeHrefCache: Map<string, string> | null = null;

  /** Resolve a work-package type name to its API href (cached). */
  async getTypeHref(typeName: string): Promise<string | undefined> {
    if (!this.typeHrefCache) {
      const types = await this.listTypes();
      this.typeHrefCache = new Map(types.map((t) => [t.name, t.self]));
    }
    return this.typeHrefCache.get(typeName);
  }

  /**
   * Bulk-list work-package relations (follows/blocks/relates/…) across the
   * whole instance. Paged like the other collections (`offset` = page number).
   */
  async getRelations(options?: { pageSize?: number; offset?: number }): Promise<OpenProjectRelation[]> {
    const params = new URLSearchParams();
    params.set('pageSize', String(options?.pageSize ?? 100));
    if (options?.offset) params.set('offset', String(options.offset));
    const data = await this.request('GET', `/relations?${params.toString()}`);
    return data._embedded?.elements ?? [];
  }

  /** List a project's versions (releases). */
  async getVersions(projectIdOrIdentifier: string | number): Promise<OpenProjectVersion[]> {
    const data = await this.request('GET', `/projects/${projectIdOrIdentifier}/versions`);
    return data._embedded?.elements ?? [];
  }

  /**
   * List time entries instance-wide (paged). Returns [] when the time/costs
   * module is disabled (403/404) so enrichment degrades gracefully.
   */
  async getTimeEntries(options?: { pageSize?: number; offset?: number }): Promise<OpenProjectTimeEntry[]> {
    const params = new URLSearchParams();
    params.set('pageSize', String(options?.pageSize ?? 100));
    if (options?.offset) params.set('offset', String(options.offset));
    try {
      const data = await this.request('GET', `/time_entries?${params.toString()}`);
      return data._embedded?.elements ?? [];
    } catch (error: any) {
      // request() embeds the HTTP status as "(403)"/"(404)" in the message.
      if (/\((403|404)\)/.test(error?.message ?? '')) return [];
      throw error;
    }
  }

  /** Post an activity comment on a work package. */
  async addWorkPackageComment(workPackageId: number, comment: string): Promise<void> {
    await this.request('POST', `/work_packages/${workPackageId}/activities`, {
      comment: { raw: comment },
    });
  }

  /**
   * Fetch the collection of work-package schemas (GET /api/v3/work_packages/schemas).
   * Each element carries the per-attribute descriptors used by schema discovery.
   * Returns [] (rather than throwing) when the endpoint is forbidden/absent so
   * discovery can fall back to the standard attribute set.
   */
  async getWorkPackageSchemas(): Promise<any[]> {
    try {
      const data = await this.request('GET', '/work_packages/schemas');
      return data._embedded?.elements ?? [];
    } catch (error: any) {
      if (/\((403|404)\)/.test(error?.message ?? '')) return [];
      throw error;
    }
  }

  /**
   * Fetch instance custom-field definitions (GET /api/v3/custom_fields). Not all
   * OpenProject versions expose this; tolerate 403/404 by returning [].
   */
  async getCustomFields(): Promise<any[]> {
    try {
      const data = await this.request('GET', '/custom_fields');
      return data._embedded?.elements ?? [];
    } catch (error: any) {
      if (/\((403|404)\)/.test(error?.message ?? '')) return [];
      throw error;
    }
  }
}

let singleton: OpenProjectClient | null = null;

export function getOpenProjectClient(): OpenProjectClient {
  if (!singleton) singleton = new OpenProjectClient();
  return singleton;
}
