/**
 * IntegrationSyncService patch — OpenProject support.
 *
 * PASTE THESE AS PRIVATE METHODS into Kyndral's
 * `server/services/IntegrationSyncService.ts` (mirroring
 * testPlanviewConnection/syncPlanview) and add the two switch cases below.
 * They are exported standalone here only so this file typechecks on its own;
 * when pasting, add `private` + `this.` as appropriate (the bodies need no
 * other change — they don't reference `this`).
 *
 * 1) In the `testConnection` switch (~line 78), next to the 'planview' case:
 *
 *      case 'openproject':
 *        return await this.testOpenProjectConnection(credentials);
 *
 * 2) In the `syncIntegration` switch (~line 129):
 *
 *      case 'openproject':
 *        return await this.syncOpenProject(integration, credentials);
 *
 * 3) Import at the top of IntegrationSyncService.ts:
 *
 *      import { OpenProjectClient } from "../openProjectClient";
 *
 * 4) Add 'openproject' wherever integration types are enumerated (shared
 *    schema enum + UI dropdown — search for 'planview'). Credentials shape:
 *    { baseUrl: string, apiKey: string, projectId?: string }.
 *
 * Types: Integration / IntegrationCredentials / SyncResult are Kyndral
 * internals not available in this folder, so they are typed loosely below;
 * once pasted, the service's real types apply unchanged.
 */
import { OpenProjectClient } from "./openProjectClient";

// Loose stand-ins for Kyndral's types (delete when pasting into the service).
type IntegrationCredentials = { baseUrl: string; apiKey: string; projectId?: string } & Record<string, any>;
type Integration = { id: string; name?: string } & Record<string, any>;
type SyncResult = {
  success: boolean;
  message: string;
  details: {
    recordsImported: number;
    recordsUpdated: number;
    recordsSkipped: number;
    errors: number;
    errorMessages: string[];
    duration: number;
    timestamp: string;
  };
} & Record<string, any>;

/** → paste as: private async testOpenProjectConnection(credentials) { ... } */
export async function testOpenProjectConnection(
  credentials: IntegrationCredentials,
): Promise<{ success: boolean; message: string }> {
  const client = new OpenProjectClient({
    baseUrl: credentials.baseUrl,
    apiKey: credentials.apiKey,
    projectId: credentials.projectId,
  });
  return client.testConnection();
}

/** → paste as: private async syncOpenProject(integration, credentials) { ... } */
export async function syncOpenProject(
  integration: Integration,
  credentials: IntegrationCredentials,
): Promise<SyncResult> {
  const started = Date.now();
  const client = new OpenProjectClient({
    baseUrl: credentials.baseUrl,
    apiKey: credentials.apiKey,
    projectId: credentials.projectId,
  });

  let imported = 0;
  let errors: string[] = [];
  try {
    const projects = await client.getProjects();
    for (const p of projects) {
      const r = await client.syncProject(String(p.id), integration.id);
      imported +=
        r.projectsCreated + r.featuresCreated + r.storiesCreated + r.tasksCreated + r.risksCreated;
      errors = errors.concat(r.errors);
    }
    return {
      success: true,
      message: `OpenProject sync: ${imported} items from ${projects.length} project(s)` +
        (errors.length ? ` (${errors.length} item errors)` : ""),
      details: {
        recordsImported: imported,
        recordsUpdated: 0,
        recordsSkipped: 0,
        errors: errors.length,
        errorMessages: errors.slice(0, 25),
        duration: Date.now() - started,
        timestamp: new Date().toISOString(),
      },
    };
  } catch (e: any) {
    return {
      success: false,
      message: `OpenProject sync failed: ${e.message}`,
      details: {
        recordsImported: imported,
        recordsUpdated: 0,
        recordsSkipped: 0,
        errors: errors.length + 1,
        errorMessages: [...errors.slice(0, 24), e.message],
        duration: Date.now() - started,
        timestamp: new Date().toISOString(),
      },
    };
  }
}
