# Ontology API rename: `/api/palantir/ontology/*` → `/api/ontology/*`

Zero-downtime cutover for Kyndral-365. The `palantir` stem is purely historical
(FalkorDB runs behind it — nothing Palantir). This is the exact, safe sequence
to drop that name without a flag day.

> This **supersedes** the optional "safe rollout" note in
> [`ONTOLOGY_LAYER.md`](./ONTOLOGY_LAYER.md). Follow the steps here.

## TL;DR

1. Mount the alias so BOTH URLs are live (`server/routes/ontologyAlias.ts`).
2. Cut the client over: grep `client/src` for the old stem, replace with the new.
3. After a release where the new URL is in production use, drop the legacy mount.

---

## Step 1 — Mount the alias (both URLs live)

In Kyndral's `server/routes.ts`, replace the single ontology mount with the
alias helper. The SAME handler instance is mounted twice — one source of truth.

```ts
import { mountOntologyAlias } from "./routes/ontologyAlias";

// before:
//   app.use("/api/palantir/ontology", requireAuth, ontologyRouter);
// after (behind the same auth — wrap the router or chain the middleware):
mountOntologyAlias(app, [requireAuth, ontologyRouter] as any);
// or, if the router already has auth applied:
//   mountOntologyAlias(app, ontologyRouter);
```

After deploying this, **both** `/api/ontology/...` and
`/api/palantir/ontology/...` respond identically. Nothing 404s. The client has
not changed yet, so it keeps hitting the legacy URL — which still works.

Smoke-check both stems:

```bash
curl -fsS "$KYNDRAL_BASE/api/ontology/health"          # new — should be 200
curl -fsS "$KYNDRAL_BASE/api/palantir/ontology/health" # legacy — should be 200
```

## Step 2 — Cut the client over

In the **Kyndral repo** `client/src` (this connector can't reach it), find every
caller of the old stem and rewrite it. First survey:

```bash
# from the Kyndral repo root — list every occurrence
rg -n "/api/palantir/ontology" client/src
```

Then rewrite in place (macOS/BSD sed shown with the `-i ''` form; GNU sed below):

```bash
# GNU sed (Linux / CI)
rg -l "/api/palantir/ontology" client/src \
  | xargs sed -i 's#/api/palantir/ontology#/api/ontology#g'

# BSD/macOS sed
rg -l "/api/palantir/ontology" client/src \
  | xargs sed -i '' 's#/api/palantir/ontology#/api/ontology#g'
```

Verify nothing remains, then build:

```bash
rg -n "/api/palantir/ontology" client/src   # expect: no matches
npm run build
```

Ship this release. Now production traffic uses `/api/ontology`; the legacy mount
only catches stragglers (cached bundles, bookmarks, external callers).

## Step 3 — Drop the legacy alias

After **at least one full release** in which the new URL is confirmed in use
(check access logs / metrics for `/api/palantir/ontology` hits dropping to ~0),
remove the alias so there's one canonical name:

```ts
// server/routes.ts — replace the alias mount with a single canonical mount:
import { ONTOLOGY_PATH } from "./routes/ontologyAlias";
app.use(ONTOLOGY_PATH, requireAuth, ontologyRouter);   // "/api/ontology"
```

Or delete `LEGACY_ONTOLOGY_PATH`'s mount line from `mountOntologyAlias` if you
keep the helper. Either way, `/api/palantir/ontology/*` now returns 404 by
design — the rename is complete.

## Rollback

If anything regresses at Step 2, you don't need to revert code: the alias from
Step 1 means the legacy URL still works. Roll the client back to the previous
bundle and investigate; the server keeps serving both stems until Step 3.
