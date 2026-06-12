# OpenProject connector for Kyndral-365

Makes **OpenProject the datastore / system-of-record** for the Kyndral-365 platform,
**bidirectionally**, mirroring the existing source-tool clients (Jira, Planview, …).
Built by reading the Kyndral repo's exact patterns so it drops straight in.

> Why this folder lives in `agenticopenproject`: this session has write access here,
> not to the Kyndral repo. Copy `server/openProjectClient.ts` into Kyndral's `server/`
> (or, once the Kyndral repo is attached to a session, it gets PR'd there directly).
> The agent-runtime in this repo proved the OpenProject↔graph↔agents loop; this is
> that work, refactored into a Kyndral-native client.

## What's in here now

| File | What it is |
|---|---|
| `server/openProjectClient.ts` | Bidirectional OpenProject client (sync in, agent write-back out) — the core connector |
| `server/FalkorOntologyDataProvider.ts` | Drop-in FalkorDB replacement for the Palantir `OntologyDataProvider` (same method surface, `/api/palantir/ontology/*` unchanged) |
| `server/routes/webhooks/openproject.ts` | `POST /webhooks/openproject` Express router: HMAC verify → `handleWebhook()` sync + orchestrator `registerChange()` |
| `server/integrationSyncService.openproject.patch.ts` | Copy-paste `testOpenProjectConnection`/`syncOpenProject` methods + switch cases for `IntegrationSyncService` |
| `server/patches/eventDrivenBootstrap.ts` | `activateEventDrivenOrchestration()` + `registerCrudChangeHooks()` — the missing wiring for `EventDrivenOrchestrator` |
| `server/patches/ACTIVATE_EVENT_DRIVEN.md` | Exact steps to kill the 15s polling loop and go event-driven (~93% cost cut) |
| `docs/PALANTIR_TO_FALKORDB.md` | Migration plan: Palantir ontology backend → FalkorDB (mapping table, env vars, backfill, rollback) |
| `docs/SCHEMA_AND_OPENPROJECT_MAPPING.md` | OpenProject ↔ Kyndral v2 field/type mapping + schema gap list |
| `docs/ORCHESTRATION_AND_RULES.md` | Cost analysis: polling vs event-driven orchestrators, rules-engine verdict |
| `docs/GROUNDING_AND_HALLUCINATION.md` | Grounding / outcome-tracking strategy for the agents |
| `docs/UI_STRATEGY.md` | UI strategy notes |

## What it provides

`server/openProjectClient.ts` — `OpenProjectClient`, same shape as `planviewClient.ts`:
- `testConnection()`, `getProjects()`, `getWorkPackages()`, `getWorkPackage()`
- `syncProject(projectId, sourceSystemId)` → writes into `storage` (projects → features
  → stories → tasks → risks) using canonical status/priority mappers (the ontology).
- **Bidirectional write-back** (the new part): `createWorkPackage()`,
  `updateProjectStatus()` (writes the agent verdict to OpenProject's native banner),
  `addWorkPackageComment()`, and `handleWebhook()` for real-time inbound.
- `createOpenProjectClientFromAdapter(adapterId)`.

## Drop-in steps (exact)

### 1. Copy the client
```
cp openProjectClient.ts <kyndral>/server/openProjectClient.ts
```

### 2. Register in the integration dispatch
In `server/services/IntegrationSyncService.ts`, add a case to **both** switches
(`testConnection` ~line 78 and `syncIntegration` ~line 129):
```ts
case 'openproject':
  return await this.testOpenProjectConnection(credentials);   // in testConnection switch
case 'openproject':
  return await this.syncOpenProject(integration, credentials); // in syncIntegration switch
```
And add the two methods (mirroring `testPlanviewConnection`/`syncPlanview`):
```ts
private async testOpenProjectConnection(c: IntegrationCredentials) {
  const client = new OpenProjectClient({ baseUrl: c.baseUrl, apiKey: c.apiKey });
  return client.testConnection();
}
private async syncOpenProject(integration: Integration, c: IntegrationCredentials): Promise<SyncResult> {
  const client = new OpenProjectClient({ baseUrl: c.baseUrl, apiKey: c.apiKey });
  const projects = await client.getProjects();
  let imported = 0;
  for (const p of projects) {
    const r = await client.syncProject(String(p.id), integration.id);
    imported += r.featuresCreated + r.storiesCreated + r.tasksCreated + r.risksCreated;
  }
  return { success: true, message: `OpenProject sync: ${imported} items`, details: { recordsImported: imported, recordsUpdated: 0, recordsSkipped: 0, errors: 0, errorMessages: [], duration: 0, timestamp: new Date().toISOString() } };
}
```
Import at top: `import { OpenProjectClient } from "../openProjectClient";`

### 3. Add 'openproject' to the integration type enum
Wherever the integration/adapter types are enumerated (the Drizzle/shared schema enum
and the UI integration dropdown — search `'planview'`), add `'openproject'`. Credentials
shape: `{ baseUrl: string, apiKey: string, projectId?: string }`.

### 4. Real-time inbound webhook (bidirectional in)
Create `server/routes/webhooks/openproject.ts` registering
`POST /webhooks/openproject` that verifies the `X-OP-Signature` HMAC and calls
`client.handleWebhook(req.body, sourceSystemId)`. Configure that URL in OpenProject
(Administration → Webhooks). (HMAC verify logic is in
`agentic-ppm/agent-runtime/src/webhook/server.ts` — copy `verifySignature`.)

### 5. Bidirectional out (agents → OpenProject)
Where Kyndral agents produce status/recommendations (e.g. `server/executiveInsights.ts`,
`server/reactiveMetricWatcher.ts`), call:
```ts
const op = await createOpenProjectClientFromAdapter(adapterId);
await op?.updateProjectStatus(opProjectId, 'at_risk', explanation); // native banner
await op?.createWorkPackage(opProjectId, { subject, description, typeName: 'Task' }); // follow-up
```

### 6. OpenProject as the datastore
- **Reads** (source of truth): the sync scheduler runs `syncOpenProject` so OpenProject
  projects/work flow into Kyndral's model + ontology on a cadence (+ webhook real-time).
- **Writes**: agent outputs go back to OpenProject (step 5), so OpenProject stays the
  canonical record while Kyndral's Postgres holds the intelligence layer
  (findings, interventions, OKRs, ontology graph).

## Notes / TODO on the Kyndral side (verify against its schema)
- `storage.createProject/Feature/Story/Task/Risk/Notification` field names are taken
  from `planviewClient.syncProject` usage; confirm the Insert* types match (esp.
  `createRisk` fields probability/impact).
- The MCP tool feeds (Jira/ADO/Planview/…) already map to the ontology via these same
  storage entities; OpenProject now joins them as both a source AND the write target.
- The canonical type→entity mapping (`TYPE_BUCKET`) and status/priority mappers in the
  client are the ontology mapping for OpenProject — extend as your ontology evolves.
