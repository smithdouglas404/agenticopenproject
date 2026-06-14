# Cerbos policies — authorization for the Agentic PPM product

Policy-as-code authz. The **Kyndral server** asks Cerbos `checkResources` before
allowing an action; the **agent-runtime** uses a machine principal (role `agent`)
so the HITL gate is enforced even for the agents.

## Roles (principal roles)
| Role | Who |
|---|---|
| `admin` | Platform owner — everything, incl. integrations + mapping studio. |
| `pmo` | Portfolio/governance — manage rules, approve findings, view all projects. |
| `project_manager` | Manages their own projects' work + can author rules in scope. |
| `contributor` | Edits work packages on projects they're a member of. |
| `viewer` | Read-only. |
| `agent` | **Service principal** for the agent-runtime / Mastra agents — can `publish` findings + `agent_writeback`, **never** `approve`. |

Derived roles (`_derived_roles.yaml`): `project_owner` (principal.id ∈ resource.attr.ownerIds), `project_member` (∈ memberIds), `finding_assignee` (∈ assigneeIds).

## Resource × action matrix
| Resource | Action | admin | pmo | project_manager | contributor | viewer | agent |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|
| project | view | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| project | create | ✓ | ✓ | | | | |
| project | edit / manage_modules | ✓ | ✓ | owner | | | |
| project | archive / delete | ✓ | ✓ | | | | |
| work_package | view | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| work_package | create/edit/transition/assign | ✓ | ✓ | owner | member (no assign) | | |
| work_package | delete | ✓ | ✓ | | | | |
| work_package | agent_writeback | | | | | | ✓ |
| agent_rule | view | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| agent_rule | create/edit/delete/enable | ✓ | ✓ | owner (create/edit) | | | |
| agent_rule | evaluate (pull rules.json) | | | | | | ✓ |
| **agent_finding** | view | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **agent_finding** | **publish** | | | | | | **✓** |
| **agent_finding** | **approve/reject/resolve** | ✓ | ✓ | assignee/owner | | | **DENY** |
| mapping | view | ✓ | ✓ | | | | |
| mapping | edit/publish | ✓ | | | | | |
| integration | view | ✓ | ✓ | | | | |
| integration | connect/configure/delete | ✓ | | | | | |
| okr | view | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| okr | create/edit/delete | ✓ | ✓ | | | | |
| okr | link | | | owner | | | |

**The load-bearing rule:** `agent_finding.publish` is allowed for `agent`, but
`approve`/`reject` are **explicitly DENY** for `agent`. That is the HITL gate in
policy — the agents can surface a conclusion, only a human can execute it.

## Wiring into the Kyndral server
1. Cerbos runs as a sidecar/container reading `cerbos/policies/` (the volume you
   mounted). Point it at this dir (`storage.disk.directory`).
2. In the Express middleware, before a mutating action, call Cerbos:
   ```ts
   const decision = await cerbos.checkResource({
     principal: { id: user.id, roles: user.roles },            // e.g. ['project_manager']
     resource: {
       kind: 'agent_finding', id: finding.id,
       attr: { ownerIds: [...], assigneeIds: [...], projectId },
     },
     actions: ['approve'],
   });
   if (!decision.isAllowed('approve')) return res.status(403).end();
   ```
3. The **agent-runtime** authenticates as principal `{ id: 'agent-runtime', roles: ['agent'] }`
   when it publishes findings / writes back — so the same policies gate it.

## Resource attributes the app must supply
- `project` / `work_package`: `ownerIds[]`, `memberIds[]`, `projectId`.
- `agent_finding`: `assigneeIds[]`, `ownerIds[]` (the owning project's), `projectId`.
These come from OpenProject membership + the finding's `projectId`.

## Adding a resource/action later
Add the action to the matching `*.yaml` (or a new resource file), `cerbos compile`
to validate, and the change is live on reload — no app deploy.
