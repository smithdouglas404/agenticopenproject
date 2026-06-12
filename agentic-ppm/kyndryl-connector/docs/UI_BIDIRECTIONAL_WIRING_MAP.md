# UI bidirectional wiring map: OpenProject in every area of the Kyndral-365 UI

Scope: Kyndral-365 DOSv2 client (~59 pages). This is the page-by-page map for
making OpenProject visible — and writable — everywhere it should be, using the
four drop-in files in `client/src/openproject/`:

| Drop-in | What it gives you |
|---|---|
| `useOpenProject.ts` | `useOpenProjectLink`, `useOpenProjectStatus`, `pushToOpenProject`, `createWorkPackageInOpenProject`, `isOpenProjectEntity`, `formatRelativeTime` |
| `SourceBadge.tsx` | "⚡ OpenProject" chip + deep link; renders nothing for non-OP entities (safe to place unconditionally) |
| `OpenProjectEditGuard.tsx` | `useBidirectionalSave(entity, …)` → save locally **then** push to OpenProject; `PushStatus` inline indicator; render-prop wrapper |
| `OpenProjectPanel.tsx` | Collapsible project panel (status, deep link, last sync, create-WP form, optional agent-console iframe) + `OpenProjectStatusDot` for the app header |

Server contracts assumed (connector server work, in parallel):
`PATCH /api/openproject/entities/:entityType/:externalId`,
`POST /api/openproject/projects/:externalProjectId/work-packages`,
`GET /api/openproject/link/:entityType/:externalId`,
`GET /api/openproject/status`.
Synced entities carry `sourceSystem: 'openproject'`, `externalId`, `lastSyncedAt`.

The rule of three (from `UI_STRATEGY.md`):

- **OpenProject-mapped** pages: show provenance, edits write back (bidirectional).
- **Kyndral-setup (governance)** pages: full CRUD stays in Kyndral; they *read
  roll-ups over* OP-synced work; **no write-back**; optionally `SourceBadge` on
  linked work entities.
- **Computed/agent** pages: findings *reference* OP entities via deep links;
  decisions mirror to OpenProject comments/status via the agent write-back
  already in `server/openProjectClient.ts`.

## Global (every page)

| Where | What shows from OpenProject | What writes back | Exact drop-in |
|---|---|---|---|
| App shell header (the layout component every page renders inside) | Sync health: green/red/amber dot + instance name on hover | — | `<OpenProjectStatusDot className="ml-2" />` next to the existing header status area. Mount ONCE in the shell — it polls `/api/openproject/status` every 60s. Import from `@/openproject` |
| Any entity title, anywhere | Provenance chip + deep link | — | `<SourceBadge entity={entity} entityType="task" />` immediately after the title text. It self-gates: non-OP entities render nothing, so add it unconditionally |

## OpenProject-mapped pages (bidirectional)

| Page | What shows from OpenProject | What writes back | Exact drop-in |
|---|---|---|---|
| **ProjectDetailPage** (the nexus) | Whole work tree (WBS, epics→features→stories→tasks), status, priority, assignees, dates, % done, time actuals; "Open in OpenProject"; last-sync time | name, description, status, priority, startDate, dueDate, percentComplete on any OP-sourced item; new work packages | (1) `<OpenProjectPanel entity={project} consoleUrl={AGENT_CONSOLE_URL} defaultOpen />` in the right sidebar/overview tab. (2) `<SourceBadge entity={project} entityType="project" />` next to the project title and `<SourceBadge entity={item} entityType={item.kind} />` on every WBS row. (3) Wrap each edit form's save: `const { save, status, retry } = useBidirectionalSave(task, { entityType: 'task', onLocalSave: existingMutation.mutateAsync, onPushed: () => toast.success('Synced to OpenProject'), onPushFailed: (e) => toast.error(e) })` then submit via `save(changes)` and render `<PushStatus status={status} onRetry={retry} />` by the Save button |
| **ProjectIngestionPage** | OpenProject listed as an ingestion source; per-source last-sync from `lastSyncedAt`; connection state | Triggering a sync (existing ingestion action — server side) | Add an "OpenProject" source card: status from `useOpenProjectStatus()`, `lastSyncedAt` chip via `formatRelativeTime`, deep link via `useOpenProjectLink('project', externalId)`. Ingested rows get `<SourceBadge entity={row} />` |
| **Work / task / issue list & board views** | Each row/card that originated in OpenProject is badged; status/assignee/dates are OP truth | Inline edits (status drag on a board, due-date pickers, rename) | `<SourceBadge entity={item} entityType={item.kind} className="ml-1" />` in the row/card title cell. Wrap the inline-edit handler: board `onDrop` → `useBidirectionalSave(item, { entityType, onLocalSave: moveColumnMutation }).save({ status: newStatus })`. Show `<PushStatus>` in the card footer while pushing |
| **Dependency views** (dependencies / projectDependencies, relations) | Relations synced from OpenProject (`work_package_relations`, see schema-gaps file): blocks / relates_to / duplicates between badged entities | Creating a relation can create a follow-up WP comment/link (optional; otherwise read-only until relation write-back exists server-side) | Badge both endpoints of an edge: `<SourceBadge entity={dep.from} /> → <SourceBadge entity={dep.to} />`. Edge tooltip links out via `useOpenProjectLink(dep.from.entityType, dep.from.externalId)` |
| **Reporting / analytics dashboards over work data** (burndown, EVM, timesheets, portfolio rollups) | Every number traces to OP-synced actuals (timesheets → EVM; see MOCK_DATA_TO_REAL.md) | — (read-only aggregates) | Add a small "data origin" footer per widget: `⚡ n of m items synced from OpenProject · last sync {formatRelativeTime(maxLastSyncedAt)}` — compute from the rows you already have; deep-link drill-downs via `useOpenProjectLink` |

## Kyndral-setup / governance pages (reads roll up over OP work; **no write-back**)

| Page | What shows from OpenProject | What writes back | Exact drop-in |
|---|---|---|---|
| **OKRManagement** | KR progress rolled up from OP-synced entities (`okr_entity_contributions` × entity progress — `server/okrRollupService.ts`); contributor lists show which epics/tasks are OP-sourced | Nothing to OpenProject. Contribution % edits stay in Kyndral (`POST /api/okrs/:okrId/key-results/:krId/contributions`) | In the KR contributor breakdown, render `<SourceBadge entity={contributor.entity} entityType={contributor.entityType} />` per row so users see KR progress is grounded in the system of work. No `useBidirectionalSave` here |
| **CompanyProfile** (divisions/segments/org units) | Optionally: counts of OP-synced projects per division | Nothing — Kyndral-authoritative | No changes required. If divisions list linked projects, add `<SourceBadge entity={project} entityType="project" />` on those project chips |
| **CustomFieldManagement** | Which custom fields are mapped to OpenProject custom fields (`externalCustomFieldId`, `syncDirection` — schema-gaps file) | Field *definitions* stay Kyndral; mapped field *values* flow via the connector sync, not this page | Add a "Synced with OpenProject" column: render the ⚡ chip (or `<SourceBadge>` if you stamp the mapping rows with `sourceSystem`/`externalId`) when `externalCustomFieldId` is set; show `syncDirection` as text |
| **PolicyAsCode** | Optionally: policy evaluation results referencing OP entities (e.g. "12 OP tasks violate the stale-date policy") | Nothing — policies are Kyndral-authoritative | Where a policy result lists offending entities, badge them: `<SourceBadge entity={violation.entity} />` + the deep link gets reviewers straight to the record in OpenProject |
| **IntegrationManagement** | The OpenProject adapter card: live connection state, instance name, version, last error | Adapter config CRUD (Kyndral-side; baseUrl/apiKey) — config, not work data | On the `'openproject'` adapter card: `const { connected, instanceName, checking } = useOpenProjectStatus()` for the status pill; "Test connection" button calls `refresh()`. (Adapter registration itself: README step 3) |
| **Agent config suite** (AgentManagement / DynamicAgentAdmin / AgentRules / MCP) | Optionally: which agents have OpenProject write-back enabled | Nothing here (agents write back at runtime) | No required changes; a static "writes to OpenProject" tag on agents that call `updateProjectStatus`/`addWorkPackageComment` is enough |

## Computed / agent pages (findings reference OP entities; decisions mirror out)

| Page | What shows from OpenProject | What writes back | Exact drop-in |
|---|---|---|---|
| **AgentCommandCenterPage** | Findings/interventions cite OP entities with provenance + deep links | Nothing directly — approved actions flow via HITL | On each finding's referenced-entity chips: `<SourceBadge entity={ref.entity} entityType={ref.entityType} />`. Optionally embed the sidecar console: `<OpenProjectPanel entity={project} consoleUrl={AGENT_CONSOLE_URL} />` or a bare `<iframe src={consoleUrl + '?embed=1'} />` |
| **AgentLens** | Evidence trails point at OP records ("task #4711 slipped 2w") with deep links | — | Badge evidence rows with `<SourceBadge>`; wrap raw OP ids in `useOpenProjectLink(type, id)` anchors |
| **ClarityChat** | Answers that cite work data cite OP-synced entities; citations deep-link | — (chat never mutates OP) | In the citation renderer, when a cited entity `isOpenProjectEntity(e)`, render `<SourceBadge entity={e} />` after the citation text |
| **DeepAgentMonitoring** / **OrchestrationMonitoringPage** | Sync jobs + webhook events from OpenProject in the event stream (`syncAuditLog`); connector health | — | Event rows with `sourceSystem === 'openproject'` get the ⚡ chip; add `<OpenProjectStatusDot showLabel />` in the page's status strip |
| **GraphExplorer** | OP-synced nodes visually distinct in the ontology graph; node inspector shows last sync + deep link | — | Node style: tint nodes where `isOpenProjectEntity(node.data)`. Node detail drawer: `<SourceBadge entity={node.data} entityType={node.type} />` + "Open in OpenProject" via `useOpenProjectLink` |
| **HITLApprovalCenter** / ApprovalCenter | Each pending action shows the OP entity it touches, with deep link, so approvers can verify in the source of record | **Approve/reject decisions mirror to OpenProject** as comments / status banner — already implemented in the agent write-back (`addWorkPackageComment`, `updateProjectStatus` in `server/openProjectClient.ts`); the UI just surfaces it | `<SourceBadge entity={action.targetEntity} entityType={action.targetType} />` on each approval card. After decision, show the mirror result: reuse `<PushStatus status={mirrorStatus} onRetry={retryMirror} />` fed from the approval mutation's response |

## Apply order (6 steps)

1. **Copy the folder**: `client/src/openproject/` → `<kyndral>/client/src/openproject/` (5 files). Confirm `npx tsc --noEmit` still passes in the Kyndral repo.
2. **Global header**: add `<OpenProjectStatusDot />` to the app shell header (one line). Every page now shows sync health.
3. **ProjectDetailPage**: add `<OpenProjectPanel entity={project} />` (pass `consoleUrl` if the agent-runtime sidecar is deployed), `<SourceBadge>` on the project title + WBS rows, and wrap the work-item save handlers with `useBidirectionalSave` + `<PushStatus>`.
4. **Work/issue/board + dependency views**: `<SourceBadge>` on rows/cards/edges; `useBidirectionalSave` around inline edits (status drag, date pickers).
5. **Governance pages** (OKRManagement, CustomFieldManagement, PolicyAsCode, IntegrationManagement): badges + status pill only, per the table above — no write-back.
6. **Agent pages** (Command Center, AgentLens, ClarityChat, monitoring, GraphExplorer, HITLApprovalCenter): badges + deep links on referenced entities; surface the HITL→OpenProject mirror result with `<PushStatus>`.

## Paste-prompt for the Kyndral session

> I've copied `client/src/openproject/` (useOpenProject.ts, SourceBadge.tsx,
> OpenProjectEditGuard.tsx, OpenProjectPanel.tsx, index.ts) into the repo. Wire
> it in per `docs/UI_BIDIRECTIONAL_WIRING_MAP.md` from the kyndryl-connector
> folder, in this order: (1) add `<OpenProjectStatusDot />` to the app shell
> header; (2) on ProjectDetailPage add `<OpenProjectPanel entity={project} />`
> plus `<SourceBadge entity={...} entityType={...} />` next to the project
> title and every WBS/work-item row, and wrap the work-item save handlers with
> `useBidirectionalSave(entity, { entityType, onLocalSave: <existing mutation>,
> onPushed/onPushFailed: <existing toast> })`, rendering `<PushStatus>` next to
> each Save button; (3) badge rows in all work/issue/board/dependency views and
> wrap their inline edits the same way; (4) governance pages (OKRManagement
> contributor lists, CustomFieldManagement mapped-field column, PolicyAsCode
> violation lists, IntegrationManagement openproject adapter card) get badges /
> `useOpenProjectStatus` only — NO write-back; (5) agent pages
> (AgentCommandCenter, AgentLens, ClarityChat citations, DeepAgentMonitoring,
> GraphExplorer node drawer, HITLApprovalCenter cards) get `<SourceBadge>` +
> deep links on referenced entities. Entities synced from OpenProject carry
> `sourceSystem: 'openproject'`, `externalId`, `lastSyncedAt`; the components
> self-gate on that, so badges are safe to add unconditionally. Server
> endpoints used: PATCH /api/openproject/entities/:entityType/:externalId,
> POST /api/openproject/projects/:id/work-packages,
> GET /api/openproject/link/:entityType/:externalId,
> GET /api/openproject/status.
