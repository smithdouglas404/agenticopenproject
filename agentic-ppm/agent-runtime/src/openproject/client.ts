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

  /** Post an activity comment on a work package. */
  async addWorkPackageComment(workPackageId: number, comment: string): Promise<void> {
    await this.request('POST', `/work_packages/${workPackageId}/activities`, {
      comment: { raw: comment },
    });
  }
}

let singleton: OpenProjectClient | null = null;

export function getOpenProjectClient(): OpenProjectClient {
  if (!singleton) singleton = new OpenProjectClient();
  return singleton;
}
